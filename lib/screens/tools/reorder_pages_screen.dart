import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../widgets/result_sheet.dart';

class ReorderPagesScreen extends StatefulWidget {
  const ReorderPagesScreen({super.key});

  @override
  State<ReorderPagesScreen> createState() => _ReorderPagesScreenState();
}

class _ReorderPagesScreenState extends State<ReorderPagesScreen> {
  String? _path;
  String? _name;
  bool _isLoadingThumbs = false;
  bool _isProcessing = false;

  // order[i] = index original de la page en position i (0-based)
  List<int> _order = [];
  final Map<int, _Thumb> _thumbs = {};

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final bytes = await File(path).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();

    setState(() {
      _path = path;
      _name = result.files.single.name;
      _order = List.generate(count, (i) => i);
      _thumbs.clear();
      _isLoadingThumbs = true;
    });
    _loadThumbnails(path, count);
  }

  Future<void> _loadThumbnails(String path, int count) async {
    final pdfDoc = await pdfx.PdfDocument.openFile(path);
    for (int i = 1; i <= count; i++) {
      if (!mounted) break;
      final page = await pdfDoc.getPage(i);
      final img = await page.render(
        width: page.width,
        height: page.height,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#ffffff',
      );
      await page.close();
      if (img?.bytes != null) {
        final png = await _rawToPng(
          img!.bytes,
          img.width ?? page.width.toInt(),
          img.height ?? page.height.toInt(),
        );
        if (mounted) {
          setState(() => _thumbs[i - 1] = _Thumb(png));
        }
      }
    }
    await pdfDoc.close();
    if (mounted) setState(() => _isLoadingThumbs = false);
  }

  Future<Uint8List> _rawToPng(Uint8List rawBytes, int width, int height) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rawBytes, width, height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final uiImage = await completer.future;
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await File(_path!).readAsBytes();
      final source = PdfDocument(inputBytes: bytes);
      final output = PdfDocument();
      output.pageSettings.margins.all = 0;

      for (final origIndex in _order) {
        final page = source.pages[origIndex];
        output.pageSettings.size = page.size;
        final newPage = output.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero);
      }
      source.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/pages_reordonnees_$ts.pdf';
      await File(outPath).writeAsBytes(await output.save());
      output.dispose();

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showResultSheet(context,
          outputPath: outPath, operationLabel: 'Pages réordonnées');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  bool get _isModified {
    for (int i = 0; i < _order.length; i++) {
      if (_order[i] != i) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réorganiser les pages'),
        actions: [
          if (_path != null && _isModified)
            _isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(
                    onPressed: _process,
                    child: const Text('Enregistrer'),
                  ),
        ],
      ),
      body: _path == null ? _buildPicker() : _buildReorder(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_vert_circle_outlined,
                size: 88,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 24),
            Text('Réorganiser les pages',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Glissez-déposez les pages pour les réordonner',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center),
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

  Widget _buildReorder() {
    return Column(
      children: [
        _FileHeader(name: _name!, onChange: _isProcessing ? null : _pickFile),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Text('${_order.length} pages',
                  style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
              const SizedBox(width: 8),
              if (_isLoadingThumbs)
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5)),
              const Spacer(),
              if (_isModified)
                TextButton(
                  onPressed: () => setState(() {
                    _order = List.generate(_order.length, (i) => i);
                  }),
                  child: const Text('Réinitialiser'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _order.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _order.removeAt(oldIndex);
                _order.insert(newIndex, item);
              });
            },
            itemBuilder: (_, i) {
              final origIndex = _order[i];
              final thumb = _thumbs[origIndex];
              return ListTile(
                key: ValueKey(origIndex),
                leading: SizedBox(
                  width: 44,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: thumb != null
                        ? Image.memory(thumb.bytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true)
                        : Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(Icons.article_outlined, size: 20),
                          ),
                  ),
                ),
                title: Text('Page ${i + 1}'),
                subtitle: origIndex != i
                    ? Text('originale : ${origIndex + 1}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey))
                    : null,
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Thumb {
  final Uint8List bytes;
  _Thumb(this.bytes);
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
          const Icon(Icons.picture_as_pdf, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          if (onChange != null)
            TextButton(onPressed: onChange, child: const Text('Changer')),
        ],
      ),
    );
  }
}
