import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../widgets/result_sheet.dart';

class MetadataScreen extends StatefulWidget {
  const MetadataScreen({super.key});

  @override
  State<MetadataScreen> createState() => _MetadataScreenState();
}

class _MetadataScreenState extends State<MetadataScreen> {
  String? _path;
  String? _name;
  bool _isProcessing = false;

  final _titleCtrl    = TextEditingController();
  final _authorCtrl   = TextEditingController();
  final _subjectCtrl  = TextEditingController();
  final _keywordsCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _subjectCtrl.dispose();
    _keywordsCtrl.dispose();
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
    final info = doc.documentInformation;
    setState(() {
      _path = path;
      _name = result.files.single.name;
      _titleCtrl.text    = info.title;
      _authorCtrl.text   = info.author;
      _subjectCtrl.text  = info.subject;
      _keywordsCtrl.text = info.keywords;
    });
    doc.dispose();
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await File(_path!).readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      doc.documentInformation.title    = _titleCtrl.text.trim();
      doc.documentInformation.author   = _authorCtrl.text.trim();
      doc.documentInformation.subject  = _subjectCtrl.text.trim();
      doc.documentInformation.keywords = _keywordsCtrl.text.trim();

      final dir = await getApplicationDocumentsDirectory();
      final ts  = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/metadata_$ts.pdf';
      await File(outPath).writeAsBytes(await doc.save());
      doc.dispose();

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showResultSheet(context,
          outputPath: outPath, operationLabel: 'Métadonnées mises à jour');
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
        title: const Text('Métadonnées PDF'),
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
                    child: const Text('Enregistrer'),
                  ),
        ],
      ),
      body: _path == null ? _buildPicker() : _buildForm(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline,
                size: 88,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 24),
            Text('Métadonnées PDF',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Modifiez le titre, l\'auteur et les informations du document',
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

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _FileHeader(name: _name!, onChange: _pickFile),
          const SizedBox(height: 16),
          _field(_titleCtrl,   'Titre',     Icons.title),
          const SizedBox(height: 12),
          _field(_authorCtrl,  'Auteur',    Icons.person_outline),
          const SizedBox(height: 12),
          _field(_subjectCtrl, 'Sujet',     Icons.subject),
          const SizedBox(height: 12),
          _field(_keywordsCtrl,'Mots-clés', Icons.label_outline,
              hint: 'Séparés par des virgules'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _process,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer les métadonnées'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {String? hint}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
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
