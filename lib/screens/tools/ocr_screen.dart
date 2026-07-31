import 'dart:async';
import 'package:files_tech_core/files_tech_core.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/pdf_tools_service.dart';
import '../../utils/atomic_write.dart';
import '../../utils/snack_utils.dart';
import '../../widgets/pdf_file_header.dart';
import '../../widgets/pdf_picker_screen.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  String? _path;
  String? _name;
  bool _isProcessing = false;
  int _processedPages = 0;
  int _totalPages = 0;
  String _extractedText = '';
  bool _isDone = false;
  String _mode = ''; // 'text' ou 'ocr'
  final List<String> _savedTxtPaths = [];

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir un PDF',
    );
    if (!mounted) return;
    if (path == null) return;
    setState(() {
      _path = path;
      _name = PathUtils.fileName(path);
      _extractedText = '';
      _isDone = false;
      _mode = '';
      _processedPages = 0;
      _totalPages = 0;
    });
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() {
      _isProcessing = true;
      _processedPages = 0;
      _extractedText = '';
      _isDone = false;
    });

    try {
      // ── Étape 1 : extraction de texte native (rapide) ───────────────────────
      final bytes = await PdfToolsService.safeReadPdf(_path!);
      if (!mounted) return;
      final sfDoc = PdfDocument(inputBytes: bytes);
      final String nativeText;
      final int total;
      try {
        total = sfDoc.pages.count;
        setState(() {
          _totalPages = total;
          _mode = 'text';
        });

        final extractor = PdfTextExtractor(sfDoc);
        final textBuffer = StringBuffer();
        for (int i = 0; i < total; i++) {
          final t = extractor.extractText(startPageIndex: i, endPageIndex: i);
          textBuffer.writeln(t);
          if (!mounted) return;
          setState(() => _processedPages = i + 1);
          // Yield au loop d'event pour ne pas bloquer l'UI sur de gros PDFs.
          await Future<void>.delayed(Duration.zero);
        }
        nativeText = textBuffer.toString().trim();
      } finally {
        // G1 v1.12.3 — symétrie avec étape 2 (F6) : dispose() garanti même si
        // extractText throw sur une page corrompue (avant : leak FD natif +
        // RAM modèle Syncfusion, ~5 échecs successifs = process kill).
        sfDoc.dispose();
      }

      if (!mounted) return;
      final avgChars = nativeText.length / (total == 0 ? 1 : total);

      if (avgChars >= 50) {
        // PDF natif avec texte suffisant
        setState(() {
          _extractedText = nativeText;
          _mode = 'text';
          _isDone = true;
          _isProcessing = false;
        });
        return;
      }

      // ── Étape 2 : OCR sur PDF scanné ────────────────────────────────────────
      setState(() {
        _mode = 'ocr';
        _processedPages = 0;
      });

      final pdfDoc = await pdfrx.PdfDocument.openFile(_path!);
      final ocrBuffer = StringBuffer();
      final tmpRoot = await getTemporaryDirectory();
      // Sous-dossier dédié à cette session OCR. Purgé en finally même si
      // exception ou kill — évite que des PNG en clair (= contenu PDF
      // reconstituable) restent dans le cache app après échec.
      final ocrTmp = Directory(
        '${tmpRoot.path}/ocr_session_${DateTime.now().millisecondsSinceEpoch}',
      );
      await ocrTmp.create();

      try {
        for (int i = 1; i <= pdfDoc.pages.length; i++) {
          final page = pdfDoc.pages[i - 1];
          final pageImage = await page.render(
            width: (page.width * 2).toInt(),
            height: (page.height * 2).toInt(),
          );

          if (pageImage != null) {
            // P0 v1.13.4 — pdfrx_engine retourne un bitmap brut ; on encode
            // directement en PNG via package:image (pas de format intégré).
            final image = pageImage.createImageNF();
            final pngBytes = img.encodePng(image);
            pageImage.dispose();

            final tmpFile = File('${ocrTmp.path}/ocr_p$i.png');
            await atomicWriteBytes(tmpFile.path, pngBytes);

            // OCR via Tesseract (open source) : français + anglais.
            final text = await FlutterTesseractOcr.extractText(
              tmpFile.path,
              language: 'fra+eng',
              args: {
                'psm': '6', // bloc de texte uniforme
                'preserve_interword_spaces': '1',
              },
            );
            if (text.trim().isNotEmpty) {
              ocrBuffer.writeln('── Page $i ──');
              ocrBuffer.writeln(text);
            }
            try {
              await tmpFile.delete();
            } catch (e) {
              if (kDebugMode) debugPrint('[OcrScreen.deleteTmpFile] $e');
            }
          }

          if (!mounted) return;
          setState(() => _processedPages = i);
          // Yield pour rendre la main au framework entre deux pages OCR.
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        // F6 v1.12.2 — close pdfDoc dans finally (avant : exception au milieu
        // de la boucle laissait FD natif en RAM).
        await pdfDoc.dispose();
        // Purge garantie même en cas d'exception au milieu de la boucle.
        try {
          if (ocrTmp.existsSync()) ocrTmp.deleteSync(recursive: true);
        } catch (e) {
          if (kDebugMode) debugPrint('[OcrScreen.purgeOcrTmp] $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _extractedText = ocrBuffer.toString().trim();
        _isDone = true;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      showErrorSnack(context, e);
    }
  }

  Future<void> _copyText() async {
    // v1.12.5 (U4) — HapticFeedback sur copy texte OCR (selectionClick =
    // confirmation tactile de l'action utilisateur). Aligné Pass Tech U9 /
    // Notes Tech F4 / pattern HapticFeedback save annotations v1.12.4 (U8).
    await HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: _extractedText));
    if (!mounted) return;
    showInfoSnack(
      context,
      'Texte copié dans le presse-papiers',
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _saveAsTxt() async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final base = (_name ?? 'document').replaceAll('.pdf', '');
    final outPath = '${dir.path}/${base}_ocr_$ts.txt';
    await atomicWriteString(outPath, _extractedText);
    _savedTxtPaths.add(outPath);
    if (!mounted) return;
    showInfoSnack(context, 'Sauvegardé : ${PathUtils.fileName(outPath)}');
  }

  Future<void> _clearExtracted() async {
    setState(() {
      _extractedText = '';
      _isDone = false;
      _mode = '';
    });
    for (final path in _savedTxtPaths) {
      try {
        await File(path).delete();
      } catch (_) {
        // best-effort : le fichier peut déjà avoir été supprimé manuellement.
      }
    }
    _savedTxtPaths.clear();
    if (!mounted) return;
    showInfoSnack(context, 'Texte effacé de l\'app');
  }

  Future<void> _share() async {
    final dir = await getTemporaryDirectory();
    // F7 v1.12.2 — nom unique horodaté (avant : `texte_extrait.txt` constant
    // → race d'écrasement si 2 partages successifs ; persistance silencieuse
    // si app killée pendant share sheet ne tirait jamais le delete).
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = '${dir.path}/texte_extrait_$ts.txt';
    final tempFile = File(outPath);
    await atomicWriteString(outPath, _extractedText);
    try {
      await Share.shareXFiles([
        XFile(outPath, mimeType: 'text/plain'),
      ], subject: 'Texte extrait de ${_name ?? "PDF"}');
    } finally {
      // Audit failles P1 : purge le .txt temporaire qui contient le
      // contenu OCR (potentiellement sensible) en clair dans le cache
      // de l'app, sinon il y reste indéfiniment après partage.
      try {
        await tempFile.delete();
      } catch (e) {
        if (kDebugMode) debugPrint('[OcrScreen._share deleteTemp] $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR – Extraction de texte'),
        actions: [
          if (_isDone && _extractedText.isNotEmpty) ...[
            IconButton(
              tooltip: 'Copier',
              icon: const Icon(Icons.copy),
              onPressed: _copyText,
            ),
            IconButton(
              tooltip: 'Partager',
              icon: const Icon(Icons.share),
              onPressed: _share,
            ),
          ],
        ],
      ),
      body: _path == null ? _buildPicker() : _buildContent(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 88,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 24),
            Text(
              'Extraction de texte (OCR)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Extrayez le texte d\'un PDF natif ou scanné',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choisir un PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: PdfFileHeader(
            name: _name!,
            onChange: _isProcessing ? null : _pickFile,
          ),
        ),
        const Divider(height: 1),
        if (_isProcessing)
          _buildProgress()
        else if (_isDone)
          _buildResult()
        else
          _buildStart(),
      ],
    );
  }

  Widget _buildStart() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_fix_high,
                size: 56,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 16),
              const Text(
                'Prêt à extraire le texte',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'PDF natif → extraction instantanée\n'
                'PDF scanné → analyse OCR page par page',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Le texte extrait est stocké temporairement sur cet appareil. '
                'Pensez à l\'effacer après usage si le document est sensible.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _process,
                icon: const Icon(Icons.search),
                label: const Text('Extraire le texte'),
                style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final label = _mode == 'ocr' ? 'OCR en cours…' : 'Extraction en cours…';
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (_totalPages > 0) ...[
                const SizedBox(height: 12),
                // U7 v1.12.4 — `Semantics(liveRegion: true)` annonce
                // l'avancement à TalkBack (la progression peut durer
                // 30s+ sur PDF long ; sans liveRegion, le user aveugle
                // n'a aucun feedback).
                Semantics(
                  liveRegion: true,
                  value:
                      'Page $_processedPages sur $_totalPages '
                      '(${(_totalPages > 0 ? _processedPages / _totalPages * 100 : 0).round()}%)',
                  child: Text(
                    'Page $_processedPages / $_totalPages',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _totalPages > 0 ? _processedPages / _totalPages : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final isEmpty = _extractedText.isEmpty;
    // v1.12.5 (U2) — tokens M3 au lieu de Colors.orange/green hardcodés.
    // `Colors.green[600]` sur fond surface dark donnait ratio ~3.1:1 (WCAG
    // AA exige 4.5:1). Maintenant cs.error (vide/échec) / cs.primary (succès)
    // respectent le thème actif et garantissent le contraste.
    final cs = Theme.of(context).colorScheme;
    final statusColor = isEmpty ? cs.error : cs.primary;
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(
                  isEmpty ? Icons.warning_amber : Icons.check_circle,
                  color: statusColor,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isEmpty
                        ? 'Aucun texte détecté'
                        : '${_extractedText.length} caractères  ·  ${_mode == 'ocr' ? 'OCR' : 'Natif'}',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!isEmpty) ...[
                  TextButton.icon(
                    onPressed: _saveAsTxt,
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text('Sauvegarder .txt'),
                  ),
                  TextButton.icon(
                    onPressed: _clearExtracted,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Effacer'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 56,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun texte reconnaissable trouvé',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _process,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _extractedText,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
