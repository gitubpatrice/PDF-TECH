import 'package:flutter/material.dart';
import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_picker_screen.dart';
import '../../widgets/result_sheet.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _filePath;
  String? _fileName;
  int _totalPages = 0;
  int _fromPage = 1;
  int _toPage = 1;
  bool _processing = false;

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir le PDF à diviser',
    );
    if (path == null) return;
    try {
      final total = await PdfToolsService().getPageCount(path);
      if (!mounted) return;
      setState(() {
        _filePath = path;
        _fileName = path.split(RegExp(r'[/\\]')).last;
        _totalPages = total;
        _fromPage = 1;
        _toPage = total;
      });
    } on PdfValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _split() async {
    if (_filePath == null) return;
    if (_fromPage > _toPage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La page de début doit être ≤ à la page de fin'),
        ),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final output = await PdfToolsService().splitPdf(
        _filePath!,
        _fromPage,
        _toPage,
      );
      if (!mounted) return;
      await showResultSheet(
        context,
        outputPath: output,
        operationLabel: 'Pages $_fromPage–$_toPage extraites',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diviser / Extraire')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilePickerCard(
              fileName: _fileName,
              subtitle: _totalPages > 0 ? '$_totalPages pages' : null,
              onPick: _pickFile,
            ),
            if (_filePath != null) ...[
              const SizedBox(height: 24),
              Text(
                'Extraire les pages',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PageField(
                      label: 'De la page',
                      value: _fromPage,
                      min: 1,
                      max: _totalPages,
                      onChanged: (v) => setState(() => _fromPage = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _PageField(
                      label: 'À la page',
                      value: _toPage,
                      min: 1,
                      max: _totalPages,
                      onChanged: (v) => setState(() => _toPage = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Résultat : ${(_toPage - _fromPage + 1).clamp(0, _totalPages)} page(s) extraite(s)',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.call_split),
                label: Text(_processing ? 'Extraction en cours…' : 'Extraire'),
                onPressed: (_processing || _filePath == null) ? null : _split,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _PageField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _PageField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton.outlined(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton.outlined(
              icon: const Icon(Icons.add, size: 18),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  final String? fileName;
  final String? subtitle;
  final VoidCallback onPick;

  const _FilePickerCard({
    required this.fileName,
    required this.onPick,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.picture_as_pdf,
          color: Color(0xFFC62828),
          size: 32,
        ),
        title: Text(fileName ?? 'Aucun fichier sélectionné'),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: TextButton(onPressed: onPick, child: const Text('Choisir')),
        onTap: onPick,
      ),
    );
  }
}
