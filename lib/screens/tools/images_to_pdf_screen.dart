import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> {
  final List<String> _images = [];
  bool _isProcessing = false;

  Future<void> _pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (f.path != null && !_images.contains(f.path)) {
          _images.add(f.path!);
        }
      }
    });
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    try {
      final doc = PdfDocument();
      for (final imgPath in _images) {
        final bytes = await File(imgPath).readAsBytes();
        final image = PdfBitmap(bytes);
        final page = doc.pages.add();
        final size = page.getClientSize();
        page.graphics.drawImage(
          image,
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      }
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/images_$ts.pdf';
      await File(outPath).writeAsBytes(await doc.save());
      doc.dispose();

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
      setState(() => _images.clear());
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
              final name = path.split(RegExp(r'[/\\]')).last;
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
                      onPressed: () => setState(() => _images.removeAt(i)),
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
