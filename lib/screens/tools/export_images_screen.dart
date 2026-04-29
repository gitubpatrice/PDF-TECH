import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/pdf_picker_screen.dart';

class ExportImagesScreen extends StatefulWidget {
  const ExportImagesScreen({super.key});

  @override
  State<ExportImagesScreen> createState() => _ExportImagesScreenState();
}

class _ExportImagesScreenState extends State<ExportImagesScreen> {
  String? _path;
  String? _name;
  int _totalPages = 0;
  String _format = 'png'; // 'png' ou 'jpeg'
  double _scale = 2.0;   // facteur de résolution (1x, 2x, 3x)
  bool _isProcessing = false;
  int _processedPages = 0;
  List<String> _outputPaths = [];
  bool _isDone = false;

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(context, title: 'Choisir un PDF');
    if (!mounted) return;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    setState(() {
      _path = path;
      _name = path.split(RegExp(r'[/\\]')).last;
      _totalPages = count;
      _outputPaths = [];
      _isDone = false;
      _processedPages = 0;
    });
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() {
      _isProcessing = true;
      _processedPages = 0;
      _outputPaths = [];
      _isDone = false;
    });
    try {
      final pdfDoc = await pdfx.PdfDocument.openFile(_path!);
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final base = (_name ?? 'document').replaceAll('.pdf', '');
      final outDir = Directory('${dir.path}/${base}_images_$ts');
      await outDir.create(recursive: true);

      final paths = <String>[];

      for (int i = 1; i <= pdfDoc.pagesCount; i++) {
        final page = await pdfDoc.getPage(i);
        final pageImage = await page.render(
          width: page.width * _scale,
          height: page.height * _scale,
          format: _format == 'png'
              ? pdfx.PdfPageImageFormat.png
              : pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#ffffff',
        );
        await page.close();

        if (pageImage?.bytes != null) {
          Uint8List finalBytes;
          if (_format == 'png') {
            finalBytes = await _rawToPng(
              pageImage!.bytes,
              pageImage.width ?? (page.width * _scale).toInt(),
              pageImage.height ?? (page.height * _scale).toInt(),
            );
          } else {
            finalBytes = pageImage!.bytes;
          }
          final pageNum = i.toString().padLeft(3, '0');
          final outPath = '${outDir.path}/page_$pageNum.$_format';
          await File(outPath).writeAsBytes(finalBytes);
          paths.add(outPath);
        }

        if (mounted) setState(() => _processedPages = i);
      }

      await pdfDoc.close();

      if (!mounted) return;
      setState(() {
        _outputPaths = paths;
        _isDone = true;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
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

  Future<void> _shareAll() async {
    if (_outputPaths.isEmpty) return;
    await Share.shareXFiles(
      _outputPaths.map((p) => XFile(p)).toList(),
      subject: 'Pages de ${_name ?? "PDF"}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exporter en images'),
        actions: [
          if (_isDone && _outputPaths.isNotEmpty)
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
            Icon(Icons.image_outlined,
                size: 88,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 24),
            Text('Exporter en images',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Convertissez chaque page du PDF en image PNG ou JPEG',
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

  Widget _buildContent() {
    return Column(
      children: [
        _FileHeader(
            name: _name!, onChange: _isProcessing ? null : _pickFile),
        const Divider(height: 1),
        if (_isProcessing)
          _buildProgress()
        else if (_isDone)
          _buildResult()
        else
          _buildOptions(),
      ],
    );
  }

  Widget _buildOptions() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_totalPages page${_totalPages > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            Text('Format',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'png', label: Text('PNG'), icon: Icon(Icons.image)),
                ButtonSegment(value: 'jpeg', label: Text('JPEG'), icon: Icon(Icons.photo)),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _format == 'png'
                  ? 'PNG : sans perte, idéal pour texte et graphiques'
                  : 'JPEG : compression plus forte, idéal pour photos',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text('Résolution',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _scale,
                    min: 1.0,
                    max: 4.0,
                    divisions: 3,
                    label: '${_scale.toInt()}x',
                    onChanged: (v) => setState(() => _scale = v),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${_scale.toInt()}x',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text(
              _scale == 1.0
                  ? 'Basse (72 dpi)'
                  : _scale == 2.0
                      ? 'Standard (144 dpi) — recommandé'
                      : _scale == 3.0
                          ? 'Haute (216 dpi)'
                          : 'Très haute (288 dpi)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _process,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Exporter les images'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('Export en cours…',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              const SizedBox(height: 12),
              Text('Page $_processedPages / $_totalPages',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _totalPages > 0 ? _processedPages / _totalPages : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_outputPaths.length} image${_outputPaths.length > 1 ? 's' : ''} exportée${_outputPaths.length > 1 ? 's' : ''} · ${_format.toUpperCase()}',
                    style: TextStyle(
                        color: Colors.green[700], fontWeight: FontWeight.w500),
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
                childAspectRatio: 0.75,
              ),
              itemCount: _outputPaths.length,
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () => Share.shareXFiles(
                    [XFile(_outputPaths[i])],
                    subject: 'Page ${i + 1}',
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(_outputPaths[i]),
                            fit: BoxFit.cover),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 6),
                            color: Colors.black54,
                            child: Text(
                              'Page ${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
