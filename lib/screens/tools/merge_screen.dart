import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_picker_screen.dart';
import '../../widgets/result_sheet.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<String> _files = [];
  bool _processing = false;

  Future<void> _addFiles() async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const PdfPickerScreen(
        title: 'Ajouter des PDFs',
        multi: true,
      )),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final p in picked) {
        if (!_files.contains(p)) _files.add(p);
      }
    });
  }

  Future<void> _merge() async {
    if (_files.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins 2 PDFs')),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final output = await PdfToolsService().mergePdfs(_files);
      if (!mounted) return;
      await showResultSheet(context,
          outputPath: output, operationLabel: 'PDFs fusionnés avec succès');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;
  String _fileSize(String path) {
    final bytes = File(path).lengthSync();
    return bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(1)} Ko'
        : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fusionner des PDFs')),
      body: Column(
        children: [
          if (_files.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.merge_type,
                        size: 80,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    const Text('Aucun PDF sélectionné'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter des PDFs'),
                      onPressed: _addFiles,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text('${_files.length} fichier(s) — glissez pour réordonner',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter'),
                    onPressed: _addFiles,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _files.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _files.removeAt(oldIndex);
                    _files.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final path = _files[index];
                  return Card(
                    key: ValueKey(path),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(_fileName(path),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_fileSize(path)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () =>
                                setState(() => _files.removeAt(index)),
                          ),
                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.merge_type),
                label: Text(_processing ? 'Fusion en cours…' : 'Fusionner'),
                onPressed: _processing ? null : _merge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
