import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_picker_screen.dart';
import '../../widgets/result_sheet.dart';

class RotateScreen extends StatefulWidget {
  const RotateScreen({super.key});

  @override
  State<RotateScreen> createState() => _RotateScreenState();
}

class _RotateScreenState extends State<RotateScreen> {
  String? _filePath;
  String? _fileName;
  int _totalPages = 0;
  PdfPageRotateAngle _angle = PdfPageRotateAngle.rotateAngle90;
  bool _processing = false;

  final _angles = const [
    (label: '90° →', angle: PdfPageRotateAngle.rotateAngle90),
    (label: '180°', angle: PdfPageRotateAngle.rotateAngle180),
    (label: '270° ←', angle: PdfPageRotateAngle.rotateAngle270),
  ];

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(context,
        title: 'Choisir le PDF à pivoter');
    if (path == null) return;
    try {
      final total = await PdfToolsService().getPageCount(path);
      if (!mounted) return;
      setState(() {
        _filePath = path;
        _fileName = path.split(RegExp(r'[/\\]')).last;
        _totalPages = total;
      });
    } on PdfValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _rotate() async {
    if (_filePath == null) return;
    setState(() => _processing = true);
    try {
      final output = await PdfToolsService().rotatePdf(_filePath!, _angle);
      if (!mounted) return;
      final label = _angles.firstWhere((a) => a.angle == _angle).label;
      await showResultSheet(context,
          outputPath: output,
          operationLabel: 'Pages tournées de $label');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rotation des pages')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf,
                    color: Color(0xFFC62828), size: 32),
                title: Text(_fileName ?? 'Aucun fichier sélectionné'),
                subtitle: _totalPages > 0
                    ? Text('$_totalPages pages')
                    : null,
                trailing: TextButton(onPressed: _pickFile, child: const Text('Choisir')),
                onTap: _pickFile,
              ),
            ),
            if (_filePath != null) ...[
              const SizedBox(height: 28),
              Text('Angle de rotation',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Center(
                child: SegmentedButton<PdfPageRotateAngle>(
                  segments: _angles
                      .map((a) => ButtonSegment(
                          value: a.angle, label: Text(a.label)))
                      .toList(),
                  selected: {_angle},
                  onSelectionChanged: (s) =>
                      setState(() => _angle = s.first),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La rotation sera appliquée à toutes les $_totalPages pages du document.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
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
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rotate_right),
                label: Text(_processing ? 'Rotation en cours…' : 'Appliquer la rotation'),
                onPressed: (_processing || _filePath == null) ? null : _rotate,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
