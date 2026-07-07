import 'dart:io';
import '../../services/isolate_runner.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/pdf_tools_service.dart';
import '../../utils/atomic_write.dart';
import '../../utils/snack_utils.dart';
import '../../widgets/pdf_file_header.dart';
import '../../widgets/pdf_picker_screen.dart';

/// Cap soft sur le nombre d'images extraites pour éviter qu'un PDF
/// pathologique ne sature la RAM/le stockage.
const int _maxExtractedImages = 1000;

/// Taille minimale plausible d'un flux image embarqué (octets). Pré-filtre
/// bon marché contre les faux positifs de marqueurs très courts.
const int _minImageBytes = 128;

/// G9 v1.12.3 — cap cumulatif sur les octets extraits. Aligné sur
/// `_maxMergeCumulativeBytes` (F4 v1.12.2). Sans ce garde, un PDF
/// malveillant annonçant 1000 × 50 Mo de "JPEG" saturerait l'isolate
/// avant l'écriture disque.
const int _maxExtractedCumulativeBytes = 500 * 1024 * 1024;

class ExtractImagesScreen extends StatefulWidget {
  const ExtractImagesScreen({super.key});

  @override
  State<ExtractImagesScreen> createState() => _ExtractImagesScreenState();
}

class _ExtractImagesScreenState extends State<ExtractImagesScreen> {
  String? _path;
  String? _name;
  bool _isProcessing = false;
  List<String> _imagePaths = [];
  bool _isDone = false;

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir un PDF',
    );
    if (!mounted) return;
    if (path == null) return;
    setState(() {
      _path = path;
      _name = fileNameOf(path);
      _imagePaths = [];
      _isDone = false;
    });
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() {
      _isProcessing = true;
      _imagePaths = [];
    });
    try {
      final pdfBytes = await PdfToolsService.safeReadPdf(_path!);
      final images = await runPdfIsolate(() => _extractImages(pdfBytes));

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outDir = Directory('${dir.path}/images_extraites_$ts');
      await outDir.create(recursive: true);

      final paths = <String>[];
      for (int i = 0; i < images.length; i++) {
        final (bytes, ext) = images[i];
        final outPath = '${outDir.path}/image_${i + 1}.$ext';
        await atomicWriteBytes(outPath, bytes);
        paths.add(outPath);
      }

      if (!mounted) return;
      setState(() {
        _imagePaths = paths;
        _isDone = true;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      showErrorSnack(context, e);
    }
  }

  // Scanne les octets du PDF à la recherche de flux image embarqués :
  //  - JPEG (SOI FF D8 FF … EOI FF D9), VALIDÉS structurellement (présence
  //    d'un vrai Start-Of-Frame) pour ne PAS écrire de .jpg corrompus issus
  //    de faux positifs de marqueurs dans des flux compressés (Flate).
  //  - PNG (signature 89 50 4E 47 … jusqu'au chunk IEND).
  // Static : exécutable dans un Isolate. Caps [_maxExtractedImages] +
  // [_maxExtractedCumulativeBytes] pour borner RAM/stockage.
  static List<(Uint8List, String)> _extractImages(Uint8List data) {
    final results = <(Uint8List, String)>[];
    int cumulative = 0;
    int i = 0;
    final len = data.length;
    while (i < len - 3) {
      // ── JPEG : FF D8 FF ─────────────────────────────────────────────────
      if (data[i] == 0xFF && data[i + 1] == 0xD8 && data[i + 2] == 0xFF) {
        final start = i;
        final endAt = _findJpegEnd(data, start);
        if (endAt != null && _isValidJpeg(data, start, endAt)) {
          final segLen = endAt - start;
          if (segLen >= _minImageBytes) {
            // G9 v1.12.3 — cap cumulatif bytes (cohérence F4 merge). Évite
            // qu'un PDF malveillant n'alloue >> RAM device dans l'isolate.
            if (cumulative + segLen > _maxExtractedCumulativeBytes) break;
            results.add((data.sublist(start, endAt), 'jpg'));
            cumulative += segLen;
            if (results.length >= _maxExtractedImages) break;
          }
          i = endAt;
          continue;
        }
        // Faux positif (pas d'EOI ou structure invalide) : avance d'1 octet.
        i++;
        continue;
      }
      // ── PNG : 89 50 4E 47 0D 0A 1A 0A ───────────────────────────────────
      if (i < len - 8 &&
          data[i] == 0x89 &&
          data[i + 1] == 0x50 &&
          data[i + 2] == 0x4E &&
          data[i + 3] == 0x47 &&
          data[i + 4] == 0x0D &&
          data[i + 5] == 0x0A &&
          data[i + 6] == 0x1A &&
          data[i + 7] == 0x0A) {
        final start = i;
        final endAt = _findPngEnd(data, start);
        if (endAt != null) {
          final segLen = endAt - start;
          if (segLen >= _minImageBytes) {
            if (cumulative + segLen > _maxExtractedCumulativeBytes) break;
            results.add((data.sublist(start, endAt), 'png'));
            cumulative += segLen;
            if (results.length >= _maxExtractedImages) break;
          }
          i = endAt;
          continue;
        }
        i++;
        continue;
      }
      i++;
    }
    return results;
  }

  /// Cherche l'EOI (FF D9) d'un JPEG démarrant à [start]. Dans un flux
  /// entropique JPEG, tout 0xFF est suivi de 0x00 (byte-stuffing) ou d'un
  /// marqueur RSTn ; un « FF D9 » nu est donc l'EOI réel. Retourne l'index
  /// juste après l'EOI, ou null si absent.
  static int? _findJpegEnd(Uint8List data, int start) {
    final len = data.length;
    int j = start + 2;
    while (j < len - 1) {
      if (data[j] == 0xFF && data[j + 1] == 0xD9) return j + 2;
      j++;
    }
    return null;
  }

  /// Valide la structure des marqueurs JPEG de [start] à [end] : exige au
  /// moins un Start-Of-Frame (SOF, FF C0–CF hors DHT/JPG/DAC) avant le SOS
  /// ou l'EOI. Rejette les faux positifs FF D8 FF … FF D9 des flux compressés.
  static bool _isValidJpeg(Uint8List data, int start, int end) {
    int pos = start + 2; // après SOI
    bool sawSof = false;
    while (pos < end - 1) {
      if (data[pos] != 0xFF) return false;
      // Absorbe d'éventuels octets de remplissage FF successifs.
      while (pos < end && data[pos] == 0xFF) {
        pos++;
      }
      if (pos >= end) break;
      final marker = data[pos];
      pos++;
      if (marker == 0xD9 || marker == 0xDA) break; // EOI / SOS
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        continue; // TEM / RSTn : pas de segment de longueur
      }
      if (pos + 1 >= end) return false;
      final segLen = (data[pos] << 8) | data[pos + 1];
      if (segLen < 2) return false;
      if (marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC) {
        sawSof = true;
      }
      pos += segLen;
    }
    return sawSof;
  }

  /// Cherche la fin d'un PNG (fin du chunk IEND) depuis [start]. IEND =
  /// « 49 45 4E 44 » suivi de 4 octets de CRC ⇒ fin = index + 8. Retourne
  /// null si IEND absent.
  static int? _findPngEnd(Uint8List data, int start) {
    final len = data.length;
    for (int j = start + 8; j < len - 7; j++) {
      if (data[j] == 0x49 &&
          data[j + 1] == 0x45 &&
          data[j + 2] == 0x4E &&
          data[j + 3] == 0x44) {
        return j + 8;
      }
    }
    return null;
  }

  Future<void> _shareAll() async {
    if (_imagePaths.isEmpty) return;
    await Share.shareXFiles(
      _imagePaths.map((p) => XFile(p)).toList(),
      subject: 'Images extraites de ${_name ?? "PDF"}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extraire les images'),
        actions: [
          if (_isDone && _imagePaths.isNotEmpty)
            IconButton(
              tooltip: 'Partager tout',
              icon: const Icon(Icons.share),
              onPressed: _shareAll,
            ),
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
              Icons.image_search,
              size: 88,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 24),
            Text(
              'Extraire les images',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Récupérez toutes les images intégrées dans un PDF',
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
    if (_isProcessing) return _buildProgress();
    if (_isDone) return _buildResult();
    return _buildStart();
  }

  Widget _buildStart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PdfFileHeader(name: _name!, onChange: _pickFile),
            const SizedBox(height: 32),
            const Icon(Icons.image_search, size: 56, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Prêt à extraire les images',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toutes les images intégrées dans le PDF\nseront extraites et sauvegardées.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _process,
              icon: const Icon(Icons.image_search),
              label: const Text('Extraire les images'),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Extraction en cours…',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_imagePaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune image trouvée dans ce PDF',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ce PDF ne contient pas d\'images intégrées.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _pickFile,
              child: const Text('Choisir un autre PDF'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_imagePaths.length} image${_imagePaths.length > 1 ? 's' : ''} extraite${_imagePaths.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Nouveau'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _imagePaths.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Share.shareXFiles([
                XFile(_imagePaths[i]),
              ], subject: 'Image ${i + 1}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(_imagePaths[i]),
                  fit: BoxFit.cover,
                  cacheWidth: 240,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
