import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../widgets/result_sheet.dart';

class HeaderFooterScreen extends StatefulWidget {
  const HeaderFooterScreen({super.key});

  @override
  State<HeaderFooterScreen> createState() => _HeaderFooterScreenState();
}

class _HeaderFooterScreenState extends State<HeaderFooterScreen> {
  String? _path;
  String? _name;
  int _totalPages = 0;
  bool _isProcessing = false;

  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  String _alignment = 'center'; // left / center / right
  double _fontSize  = 10;
  bool   _skipFirst = false;

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _process() async {
    if (_path == null) return;
    final header = _headerCtrl.text.trim();
    final footer = _footerCtrl.text.trim();
    if (header.isEmpty && footer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrez un en-tête ou un pied de page')));
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final bytes  = await File(_path!).readAsBytes();
      final doc    = PdfDocument(inputBytes: bytes);
      final font   = PdfStandardFont(PdfFontFamily.helvetica, _fontSize);
      final brush  = PdfSolidBrush(PdfColor(80, 80, 80));
      final align  = _alignment == 'left'
          ? PdfTextAlignment.left
          : _alignment == 'right'
              ? PdfTextAlignment.right
              : PdfTextAlignment.center;

      for (int i = 0; i < doc.pages.count; i++) {
        if (_skipFirst && i == 0) continue;
        final page = doc.pages[i];
        final w = page.getClientSize().width;
        final h = page.getClientSize().height;
        final fmt = PdfStringFormat(alignment: align);

        if (header.isNotEmpty) {
          page.graphics.drawString(
            header, font,
            brush: brush,
            bounds: Rect.fromLTWH(16, 6, w - 32, 18),
            format: fmt,
          );
        }
        if (footer.isNotEmpty) {
          page.graphics.drawString(
            footer, font,
            brush: brush,
            bounds: Rect.fromLTWH(16, h - 20, w - 32, 18),
            format: fmt,
          );
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final ts  = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/entete_pied_$ts.pdf';
      await File(outPath).writeAsBytes(await doc.save());
      doc.dispose();

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showResultSheet(context,
          outputPath: outPath, operationLabel: 'En-tête/Pied de page ajouté');
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
        title: const Text('En-tête / Pied de page'),
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
            Icon(Icons.vertical_split_outlined,
                size: 88,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 24),
            Text('En-tête / Pied de page',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Ajoutez un texte fixe en haut et/ou en bas de chaque page',
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
          const SizedBox(height: 4),
          Text('$_totalPages pages',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),

          TextField(
            controller: _headerCtrl,
            decoration: const InputDecoration(
              labelText: 'En-tête (optionnel)',
              prefixIcon: Icon(Icons.vertical_align_top),
              border: OutlineInputBorder(),
              hintText: 'Ex: Nom de l\'entreprise',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footerCtrl,
            decoration: const InputDecoration(
              labelText: 'Pied de page (optionnel)',
              prefixIcon: Icon(Icons.vertical_align_bottom),
              border: OutlineInputBorder(),
              hintText: 'Ex: Document confidentiel · 2025',
            ),
          ),

          const SizedBox(height: 20),
          Text('Alignement', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'left',   icon: Icon(Icons.format_align_left),   label: Text('Gauche')),
              ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center), label: Text('Centre')),
              ButtonSegment(value: 'right',  icon: Icon(Icons.format_align_right),  label: Text('Droite')),
            ],
            selected: {_alignment},
            onSelectionChanged: (s) => setState(() => _alignment = s.first),
          ),

          const SizedBox(height: 20),
          Text('Taille du texte', style: Theme.of(context).textTheme.titleSmall),
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
                  width: 44,
                  child: Text('${_fontSize.toInt()} pt',
                      style: const TextStyle(fontSize: 12))),
            ],
          ),

          SwitchListTile(
            value: _skipFirst,
            onChanged: (v) => setState(() => _skipFirst = v),
            title: const Text('Ignorer la première page'),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _process,
              icon: const Icon(Icons.vertical_split_outlined),
              label: const Text('Appliquer'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
        ],
      ),
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
