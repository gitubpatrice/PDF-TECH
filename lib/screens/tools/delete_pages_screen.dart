import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../widgets/result_sheet.dart';

class DeletePagesScreen extends StatefulWidget {
  const DeletePagesScreen({super.key});

  @override
  State<DeletePagesScreen> createState() => _DeletePagesScreenState();
}

class _DeletePagesScreenState extends State<DeletePagesScreen> {
  String? _path;
  String? _name;
  int _totalPages = 0;
  final Set<int> _selected = {}; // indices 0-based
  bool _isProcessing = false;

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
    final total = doc.pages.count;
    doc.dispose();
    setState(() {
      _path = path;
      _name = result.files.single.name;
      _totalPages = total;
      _selected.clear();
    });
  }

  Future<void> _process() async {
    if (_path == null || _selected.isEmpty) return;
    if (_selected.length >= _totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible de supprimer toutes les pages')),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final bytes = await File(_path!).readAsBytes();
      final source = PdfDocument(inputBytes: bytes);
      final output = PdfDocument();
      output.pageSettings.margins.all = 0;

      for (int i = 0; i < source.pages.count; i++) {
        if (_selected.contains(i)) continue;
        final page = source.pages[i];
        output.pageSettings.size = page.size;
        final newPage = output.pages.add();
        newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero);
      }
      source.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/pages_supprimees_$ts.pdf';
      await File(outPath).writeAsBytes(await output.save());
      output.dispose();

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showResultSheet(context,
          outputPath: outPath, operationLabel: 'Pages supprimées');
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
        title: const Text('Supprimer des pages'),
        actions: [
          if (_path != null && _selected.isNotEmpty)
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
                    child: Text(
                        'Supprimer (${_selected.length})'),
                  ),
        ],
      ),
      body: _path == null ? _buildPicker() : _buildList(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_sweep_outlined,
                size: 88,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 24),
            Text('Supprimer des pages',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Sélectionnez les pages à retirer du PDF',
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

  Widget _buildList() {
    return Column(
      children: [
        _FileHeader(name: _name!, onChange: _pickFile),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Row(
            children: [
              Text('$_totalPages pages  ·  ${_selected.length} sélectionnée${_selected.length > 1 ? 's' : ''}',
                  style: TextStyle(
                      color: _selected.isEmpty ? Colors.grey : Colors.red[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  if (_selected.length == _totalPages) {
                    _selected.clear();
                  } else {
                    _selected.addAll(
                        List.generate(_totalPages, (i) => i));
                  }
                }),
                child: Text(_selected.length == _totalPages
                    ? 'Tout désélectionner'
                    : 'Tout sélectionner'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _totalPages,
            itemBuilder: (_, i) {
              final selected = _selected.contains(i);
              return CheckboxListTile(
                value: selected,
                onChanged: (_) => setState(() {
                  selected ? _selected.remove(i) : _selected.add(i);
                }),
                title: Text('Page ${i + 1}'),
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.red.withValues(alpha: 0.12)
                        : Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.article_outlined,
                    size: 20,
                    color: selected
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FileHeader extends StatelessWidget {
  final String name;
  final VoidCallback onChange;
  const _FileHeader({required this.name, required this.onChange});

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
          TextButton(onPressed: onChange, child: const Text('Changer')),
        ],
      ),
    );
  }
}
