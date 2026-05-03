import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_file_header.dart';
import '../../widgets/result_sheet.dart';
import '../../widgets/pdf_picker_screen.dart';

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
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir un PDF',
    );
    if (!mounted) return;
    if (path == null) return;
    final int total;
    try {
      final bytes = await PdfToolsService.safeReadPdf(path);
      total = await Isolate.run(() {
        final doc = PdfDocument(inputBytes: bytes);
        final c = doc.pages.count;
        doc.dispose();
        return c;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _path = path;
      _name = fileNameOf(path);
      _totalPages = total;
      _selected.clear();
    });
  }

  Future<void> _process() async {
    if (_path == null || _selected.isEmpty) return;
    if (_selected.length >= _totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer toutes les pages'),
        ),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final bytes = await PdfToolsService.safeReadPdf(_path!);
      final toRemove = Set<int>.from(_selected);
      final out = await Isolate.run(() => _deletePagesIsolate(bytes, toRemove));

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/pages_supprimees_$ts.pdf';
      await File(outPath).writeAsBytes(out);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showResultSheet(
        context,
        outputPath: outPath,
        operationLabel: 'Pages supprimées',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _process,
                    child: Text('Supprimer (${_selected.length})'),
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
            Icon(
              Icons.delete_sweep_outlined,
              size: 88,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 24),
            Text(
              'Supprimer des pages',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Sélectionnez les pages à retirer du PDF',
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

  Widget _buildList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: PdfFileHeader(name: _name!, onChange: _pickFile),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Row(
            children: [
              Text(
                '$_totalPages pages  ·  ${_selected.length} sélectionnée${_selected.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: _selected.isEmpty ? Colors.grey : Colors.red[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  if (_selected.length == _totalPages) {
                    _selected.clear();
                  } else {
                    _selected.addAll(List.generate(_totalPages, (i) => i));
                  }
                }),
                child: Text(
                  _selected.length == _totalPages
                      ? 'Tout désélectionner'
                      : 'Tout sélectionner',
                ),
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
                        : Theme.of(context).colorScheme.primaryContainer,
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

Uint8List _deletePagesIsolate(Uint8List bytes, Set<int> toRemove) {
  final source = PdfDocument(inputBytes: bytes);
  final output = PdfDocument();
  output.pageSettings.margins.all = 0;
  for (int i = 0; i < source.pages.count; i++) {
    if (toRemove.contains(i)) continue;
    final page = source.pages[i];
    output.pageSettings.size = page.size;
    final newPage = output.pages.add();
    newPage.graphics.drawPdfTemplate(page.createTemplate(), Offset.zero);
  }
  source.dispose();
  final saved = output.saveSync();
  output.dispose();
  return saved is Uint8List ? saved : Uint8List.fromList(saved);
}
