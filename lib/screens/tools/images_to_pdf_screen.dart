import 'dart:io';
import 'package:files_tech_core/files_tech_core.dart';
import '../../services/isolate_runner.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Construit un PDF à partir d'une liste d'images dans un Isolate.
/// Sans isolate, le UI thread freeze sur 50+ photos haute-rés
/// (decode + drawImage + save = plusieurs secondes).
Future<Uint8List> _buildPdfFromImagesInIsolate(List<String> imagePaths) async {
  return runPdfIsolate(() async {
    final doc = PdfDocument();
    try {
      for (final imgPath in imagePaths) {
        final bytes = await File(imgPath).readAsBytes();
        final image = PdfBitmap(bytes);
        final page = doc.pages.add();
        final size = page.getClientSize();
        page.graphics.drawImage(
          image,
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      }
      return Uint8List.fromList(await doc.save());
    } finally {
      doc.dispose();
    }
  });
}

class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> {
  /// Cap cumulatif sur la somme des tailles des images sélectionnées.
  /// Au-delà, on rejette l'ajout : sinon construire le PDF en isolate
  /// peut OOM (decode bitmap + drawImage + save tient tout en RAM).
  static const int _maxCumulativeBytes = 500 * 1024 * 1024;

  final List<String> _images = [];
  int _totalBytes = 0;
  bool _isProcessing = false;

  Future<void> _pickImages() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    final accepted = <(String, int)>[];
    var skipped = 0;
    var capReached = false;
    var runningTotal = _totalBytes;
    for (final f in result.files) {
      final p = f.path;
      if (p == null || _images.contains(p)) continue;
      try {
        final len = await File(p).length();
        if (len > 20 * 1024 * 1024) {
          skipped++;
          continue;
        }
        if (runningTotal + len > _maxCumulativeBytes) {
          capReached = true;
          break;
        }
        runningTotal += len;
        accepted.add((p, len));
      } catch (_) {
        skipped++;
        continue;
      }
    }
    if (!mounted) return;
    setState(() {
      for (final entry in accepted) {
        _images.add(entry.$1);
        _totalBytes += entry.$2;
      }
    });
    if (capReached) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Limite atteinte : 500 Mo cumulés. Conversion à effectuer avant d\'en ajouter d\'autres.',
          ),
        ),
      );
    } else if (skipped > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$skipped image${skipped > 1 ? 's' : ''} ignorée${skipped > 1 ? 's' : ''} (>20 Mo)',
          ),
        ),
      );
    }
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      // Build PDF dans un isolate : decode bitmap + drawImage + save sont
      // CPU-lourds, restaient sur thread UI → gel sur 50+ photos haute-rés.
      final pdfBytes = await _buildPdfFromImagesInIsolate(List.of(_images));
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/images_$ts.pdf';
      await File(outPath).writeAsBytes(pdfBytes);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'PDF créé : ${_images.length} page${_images.length > 1 ? 's' : ''}',
          ),
          action: SnackBarAction(
            label: 'Partager',
            onPressed: () => Share.shareXFiles([XFile(outPath)]),
          ),
        ),
      );
      setState(() {
        _images.clear();
        _totalBytes = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Images → PDF')),
      body: _images.isEmpty ? _buildEmpty() : _buildList(),
      bottomNavigationBar: _images.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _convert,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(
                    _isProcessing
                        ? 'Conversion…'
                        : 'Créer le PDF (${_images.length} image${_images.length > 1 ? 's' : ''})',
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 88,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 24),
            Text('Images → PDF', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Convertissez vos photos JPG/PNG en un seul PDF',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Choisir des images'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${_images.length} image${_images.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = _images.removeAt(oldIdx);
                _images.insert(newIdx, item);
              });
            },
            itemCount: _images.length,
            itemBuilder: (_, i) {
              final path = _images[i];
              final name = PathUtils.fileName(path);
              return ListTile(
                key: ValueKey(path),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(path),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  'Page ${i + 1}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_handle, color: Colors.grey),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        // Re-stat à la suppression : évite de tracker un Map
                        // path→size en parallèle. Acceptable (1 IO par tap).
                        var size = 0;
                        try {
                          size = await File(path).length();
                        } catch (_) {}
                        if (!mounted) return;
                        setState(() {
                          _images.removeAt(i);
                          _totalBytes = (_totalBytes - size).clamp(0, 1 << 62);
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
