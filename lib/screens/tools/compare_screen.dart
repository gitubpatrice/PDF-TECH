import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../widgets/pdf_picker_screen.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String? _pathA;
  String? _nameA;
  int _pagesA = 0;

  String? _pathB;
  String? _nameB;
  int _pagesB = 0;

  bool _isLoading = false;
  int _currentPage = 0; // 0-based
  final Map<int, Uint8List> _thumbsA = {};
  final Map<int, Uint8List> _thumbsB = {};

  bool get _ready => _pathA != null && _pathB != null;
  int get _maxPages => _pagesA > _pagesB ? _pagesA : _pagesB;

  Future<void> _pickFile(bool isA) async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: isA ? 'Premier PDF' : 'Second PDF',
    );
    if (!mounted) return;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();

    final name = path.split(RegExp(r'[/\\]')).last;
    setState(() {
      if (isA) {
        _pathA = path;
        _nameA = name;
        _pagesA = count;
        _thumbsA.clear();
      } else {
        _pathB = path;
        _nameB = name;
        _pagesB = count;
        _thumbsB.clear();
      }
      _currentPage = 0;
    });

    if (_ready) _loadPage(_currentPage);
  }

  Future<void> _loadPage(int pageIndex) async {
    if (!_ready) return;
    setState(() => _isLoading = true);
    await Future.wait([
      _loadThumb(_pathA!, pageIndex, _thumbsA, _pagesA),
      _loadThumb(_pathB!, pageIndex, _thumbsB, _pagesB),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadThumb(String path, int index, Map<int, Uint8List> cache, int total) async {
    if (cache.containsKey(index) || index >= total) return;
    final pdfDoc = await pdfx.PdfDocument.openFile(path);
    final page = await pdfDoc.getPage(index + 1);
    final img = await page.render(
      width: page.width * 1.5,
      height: page.height * 1.5,
      format: pdfx.PdfPageImageFormat.png,
      backgroundColor: '#ffffff',
    );
    await page.close();
    await pdfDoc.close();
    if (img?.bytes != null) {
      final png = await _rawToPng(
        img!.bytes,
        img.width ?? (page.width * 1.5).toInt(),
        img.height ?? (page.height * 1.5).toInt(),
      );
      cache[index] = png;
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

  void _goTo(int page) {
    if (page < 0 || page >= _maxPages) return;
    setState(() => _currentPage = page);
    _loadPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparer deux PDFs'),
        bottom: _ready
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: _buildPageBar(),
              )
            : null,
      ),
      body: _ready ? _buildComparison() : _buildPicker(),
    );
  }

  Widget _buildPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(Icons.compare_outlined,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text('Comparer deux PDFs',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Affichez côte à côte deux versions d\'un document',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          _pdfSlot(true),
          const SizedBox(height: 16),
          const Row(children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider()),
          ]),
          const SizedBox(height: 16),
          _pdfSlot(false),
        ],
      ),
    );
  }

  Widget _pdfSlot(bool isA) {
    final path = isA ? _pathA : _pathB;
    final name = isA ? _nameA : _nameB;
    final pages = isA ? _pagesA : _pagesB;
    final label = isA ? 'PDF A — Original' : 'PDF B — Comparaison';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickFile(isA),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: path == null
              ? Row(children: [
                  Icon(Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  const Text('Choisir',
                      style: TextStyle(color: Colors.blue)),
                ])
              : Row(children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        Text(name!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('$pages pages',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  TextButton(
                      onPressed: () => _pickFile(isA),
                      child: const Text('Changer')),
                ]),
        ),
      ),
    );
  }

  Widget _buildPageBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            iconSize: 20,
            onPressed: _currentPage > 0 ? () => _goTo(_currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${_currentPage + 1} / $_maxPages',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          IconButton(
            iconSize: 20,
            onPressed: _currentPage < _maxPages - 1
                ? () => _goTo(_currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(_nameA!,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_nameB!,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Expanded(child: _pageView(_thumbsA, _pagesA, Colors.blue)),
                    const VerticalDivider(width: 1),
                    Expanded(child: _pageView(_thumbsB, _pagesB, Colors.orange)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _pageView(Map<int, Uint8List> cache, int total, Color accent) {
    if (_currentPage >= total) {
      return Center(
        child: Text('Pas de page ${_currentPage + 1}',
            style: TextStyle(color: accent, fontSize: 12)),
      );
    }
    final thumb = cache[_currentPage];
    if (thumb == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InteractiveViewer(
      child: Image.memory(thumb, fit: BoxFit.contain),
    );
  }
}
