import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _path = result.files.single.path!;
      _name = result.files.single.name;
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
      final bytes = await File(_path!).readAsBytes();
      final sfDoc = PdfDocument(inputBytes: bytes);
      final total = sfDoc.pages.count;
      setState(() { _totalPages = total; _mode = 'text'; });

      final extractor = PdfTextExtractor(sfDoc);
      final textBuffer = StringBuffer();
      for (int i = 0; i < total; i++) {
        final t = extractor.extractText(startPageIndex: i, endPageIndex: i);
        textBuffer.writeln(t);
        setState(() => _processedPages = i + 1);
      }
      sfDoc.dispose();

      final nativeText = textBuffer.toString().trim();
      final avgChars = nativeText.length / total.clamp(1, total);

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
      setState(() { _mode = 'ocr'; _processedPages = 0; });

      final pdfDoc = await pdfx.PdfDocument.openFile(_path!);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final ocrBuffer = StringBuffer();
      final tmpDir = await getTemporaryDirectory();

      for (int i = 1; i <= pdfDoc.pagesCount; i++) {
        final page = await pdfDoc.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#ffffff',
        );
        await page.close();

        if (pageImage?.bytes != null) {
          final pngBytes = await _rawToPng(
            pageImage!.bytes!,
            pageImage.width ?? (page.width * 2).toInt(),
            pageImage.height ?? (page.height * 2).toInt(),
          );
          final tmpFile = File('${tmpDir.path}/ocr_p$i.png');
          await tmpFile.writeAsBytes(pngBytes);

          final inputImage = InputImage.fromFile(tmpFile);
          final result = await recognizer.processImage(inputImage);
          if (result.text.isNotEmpty) {
            ocrBuffer.writeln('── Page $i ──');
            ocrBuffer.writeln(result.text);
          }
          await tmpFile.delete();
        }

        setState(() => _processedPages = i);
      }

      await pdfDoc.close();
      recognizer.close();

      setState(() {
        _extractedText = ocrBuffer.toString().trim();
        _isDone = true;
        _isProcessing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  // Convertit les pixels bruts (BGRA/RGBA) en PNG via dart:ui
  Future<Uint8List> _rawToPng(Uint8List rawBytes, int width, int height) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rawBytes, width, height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final uiImage = await completer.future;
    final byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _extractedText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Texte copié dans le presse-papiers'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAsTxt() async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final base = (_name ?? 'document').replaceAll('.pdf', '');
    final outPath = '${dir.path}/${base}_ocr_$ts.txt';
    await File(outPath).writeAsString(_extractedText);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sauvegardé : ${outPath.split('/').last}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _share() async {
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/texte_extrait.txt';
    await File(outPath).writeAsString(_extractedText);
    await Share.shareXFiles(
      [XFile(outPath, mimeType: 'text/plain')],
      subject: 'Texte extrait de ${_name ?? "PDF"}',
    );
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
            Icon(Icons.document_scanner_outlined,
                size: 88,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 24),
            Text('Extraction de texte (OCR)',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Extrayez le texte d\'un PDF natif ou scanné',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
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
        _FileHeader(
          name: _name!,
          onChange: _isProcessing ? null : _pickFile,
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
              const Icon(Icons.auto_fix_high,
                  size: 56, color: Colors.deepOrange),
              const SizedBox(height: 16),
              const Text('Prêt à extraire le texte',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'PDF natif → extraction instantanée\n'
                'PDF scanné → analyse OCR page par page',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _process,
                icon: const Icon(Icons.search),
                label: const Text('Extraire le texte'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final label = _mode == 'ocr'
        ? 'OCR en cours…'
        : 'Extraction en cours…';
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 16)),
              if (_totalPages > 0) ...[
                const SizedBox(height: 12),
                Text('Page $_processedPages / $_totalPages',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _totalPages > 0
                      ? _processedPages / _totalPages
                      : null,
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
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(
                  isEmpty ? Icons.warning_amber : Icons.check_circle,
                  color:
                      isEmpty ? Colors.orange : Colors.green[600],
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isEmpty
                        ? 'Aucun texte détecté'
                        : '${_extractedText.length} caractères  ·  ${_mode == 'ocr' ? 'OCR' : 'Natif'}',
                    style: TextStyle(
                      color: isEmpty
                          ? Colors.orange
                          : Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!isEmpty)
                  TextButton.icon(
                    onPressed: _saveAsTxt,
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text('Sauvegarder .txt'),
                  ),
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
                    Icon(Icons.image_not_supported_outlined,
                        size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Aucun texte reconnaissable trouvé',
                        style: TextStyle(color: Colors.grey)),
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

class _FileHeader extends StatelessWidget {
  final String name;
  final VoidCallback? onChange;
  const _FileHeader({required this.name, this.onChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          if (onChange != null)
            TextButton(onPressed: onChange, child: const Text('Changer')),
        ],
      ),
    );
  }
}
