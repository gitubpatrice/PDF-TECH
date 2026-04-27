import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../widgets/result_sheet.dart';

class PageNumbersScreen extends StatefulWidget {
  const PageNumbersScreen({super.key});

  @override
  State<PageNumbersScreen> createState() => _PageNumbersScreenState();
}

class _PageNumbersScreenState extends State<PageNumbersScreen> {
  String? _path;
  String? _name;
  int _totalPages = 0;
  bool _isProcessing = false;

  String _position  = 'bottom-center'; // bottom-left / bottom-center / bottom-right / top-center
  String _format    = 'page-n';        // page-n / n-total / n
  int    _startNum  = 1;
  double _fontSize  = 10;
  bool   _skipFirst = false;

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
      _totalPages = count;
    });
  }

  String _buildText(int pageIndex, int total) {
    final n = _startNum + pageIndex;
    switch (_format) {
      case 'n-total': return '$n / $total';
      case 'n':       return '$n';
      default:        return 'Page $n';
    }
  }

  PdfTextAlignment _textAlign() {
    if (_position.endsWith('left'))   return PdfTextAlignment.left;
    if (_position.endsWith('right'))  return PdfTextAlignment.right;
    return PdfTextAlignment.center;
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await File(_path!).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final total = doc.pages.count;
      final font  = PdfStandardFont(PdfFontFamily.helvetica, _fontSize);
      final brush = PdfSolidBrush(PdfColor(80, 80, 80));
      final isTop = _position.startsWith('top');

      for (int i = 0; i < total; i++) {
        if (_skipFirst && i == 0) continue;
        final page = doc.pages[i];
        final w = page.getClientSize().width;
        final h = page.getClientSize().height;
        final text = _buildText(i, total);
        final y = isTop ? 6.0 : h - 18.0;
        page.graphics.drawString(
          text, font,
          brush: brush,
          bounds: Rect.fromLTWH(12, y, w - 24, 16),
          format: PdfStringFormat(alignment: _textAlign()),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final ts  = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/numerotes_$ts.pdf';
      await File(outPath).writeAsBytes(await doc.save());
      doc.dispose();

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showResultSheet(context,
          outputPath: outPath, operationLabel: 'Numéros de page ajoutés');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Numéroter les pages'),
        actions: [
          if (_path != null)
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
                    child: const Text('Appliquer'),
                  ),
        ],
      ),
      body: _path == null ? _buildPicker() : _buildOptions(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.format_list_numbered,
                size: 88,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 24),
            Text('Numéroter les pages',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Ajoutez des numéros de page à votre PDF',
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

  Widget _buildOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FileHeader(name: _name!, onChange: _pickFile),
          const SizedBox(height: 8),
          Text('$_totalPages pages',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),

          _sectionTitle('Format'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'page-n', label: Text('Page N')),
              ButtonSegment(value: 'n-total', label: Text('N / Total')),
              ButtonSegment(value: 'n', label: Text('N')),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),

          const SizedBox(height: 20),
          _sectionTitle('Position'),
          const SizedBox(height: 8),
          _positionGrid(),

          const SizedBox(height: 20),
          _sectionTitle('Commencer à'),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _startNum > 1 ? () => setState(() => _startNum--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 48,
                child: Text('$_startNum',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                onPressed: () => setState(() => _startNum++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _sectionTitle('Taille du texte'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 7,
                  max: 16,
                  divisions: 9,
                  label: '${_fontSize.toInt()} pt',
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
              SizedBox(
                  width: 40,
                  child: Text('${_fontSize.toInt()} pt',
                      style: const TextStyle(fontSize: 12))),
            ],
          ),

          const SizedBox(height: 8),
          SwitchListTile(
            value: _skipFirst,
            onChanged: (v) => setState(() => _skipFirst = v),
            title: const Text('Ignorer la première page'),
            subtitle: const Text('Utile pour les pages de couverture'),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _process,
              icon: const Icon(Icons.format_list_numbered),
              label: const Text('Numéroter le PDF'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: Theme.of(context).textTheme.titleSmall);

  Widget _positionGrid() {
    final positions = [
      ('top-left',     'Haut gauche',   Icons.align_horizontal_left),
      ('top-center',   'Haut centre',   Icons.align_horizontal_center),
      ('top-right',    'Haut droite',   Icons.align_horizontal_right),
      ('bottom-left',  'Bas gauche',    Icons.align_horizontal_left),
      ('bottom-center','Bas centre',    Icons.align_horizontal_center),
      ('bottom-right', 'Bas droite',    Icons.align_horizontal_right),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.0,
      children: positions.map((p) {
        final selected = _position == p.$1;
        return InkWell(
          onTap: () => setState(() => _position = p.$1),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ),
            child: Center(
              child: Text(p.$2,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FileHeader extends StatelessWidget {
  final String name;
  final VoidCallback onChange;
  const _FileHeader({required this.name, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.picture_as_pdf, color: Colors.blue),
        const SizedBox(width: 10),
        Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500))),
        TextButton(onPressed: onChange, child: const Text('Changer')),
      ],
    );
  }
}
