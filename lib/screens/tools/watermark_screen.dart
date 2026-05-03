import 'package:flutter/material.dart';
import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_picker_screen.dart';
import '../../widgets/result_sheet.dart';

class WatermarkScreen extends StatefulWidget {
  const WatermarkScreen({super.key});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  String? _filePath;
  String? _fileName;
  final _textCtrl = TextEditingController(text: 'CONFIDENTIEL');
  double _opacity = 0.25;
  Color _color = Colors.grey;
  bool _processing = false;

  final _presetColors = const [
    Colors.grey,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir le PDF à filigraner',
    );
    if (path == null) return;
    setState(() {
      _filePath = path;
      _fileName = path.split(RegExp(r'[/\\]')).last;
    });
  }

  Future<void> _addWatermark() async {
    if (_filePath == null) return;
    if (_textCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un texte de filigrane')),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final output = await PdfToolsService().addWatermark(
        _filePath!,
        _textCtrl.text.trim(),
        opacity: _opacity,
        color: _color,
      );
      if (!mounted) return;
      await showResultSheet(
        context,
        outputPath: output,
        operationLabel: 'Filigrane ajouté',
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
      appBar: AppBar(title: const Text('Ajouter un filigrane')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFFC62828),
                  size: 32,
                ),
                title: Text(_fileName ?? 'Aucun fichier sélectionné'),
                trailing: TextButton(
                  onPressed: _pickFile,
                  child: const Text('Choisir'),
                ),
                onTap: _pickFile,
              ),
            ),
            if (_filePath != null) ...[
              const SizedBox(height: 24),
              Text(
                'Texte du filigrane',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Ex: CONFIDENTIEL, BROUILLON…',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Opacité : ${(_opacity * 100).round()}%',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _opacity,
                min: 0.05,
                max: 0.6,
                divisions: 11,
                label: '${(_opacity * 100).round()}%',
                onChanged: (v) => setState(() => _opacity = v),
              ),
              const SizedBox(height: 12),
              Text(
                'Couleur',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: _presetColors.map((c) {
                  final selected = _color.toARGB32() == c.toARGB32();
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Preview
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -0.785,
                    child: Text(
                      _textCtrl.text.isEmpty ? '…' : _textCtrl.text,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _color.withValues(alpha: _opacity * 2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Aperçu du filigrane',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 32),
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
                    : const Icon(Icons.water_drop),
                label: Text(
                  _processing ? 'Ajout en cours…' : 'Ajouter le filigrane',
                ),
                onPressed: (_processing || _filePath == null)
                    ? null
                    : _addWatermark,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
