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

class MetadataScreen extends StatefulWidget {
  const MetadataScreen({super.key});

  @override
  State<MetadataScreen> createState() => _MetadataScreenState();
}

class _MetadataScreenState extends State<MetadataScreen> {
  String? _path;
  String? _name;
  bool _isProcessing = false;

  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
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
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir un PDF',
    );
    if (!mounted) return;
    if (path == null) return;
    final _Meta meta;
    try {
      final bytes = await PdfToolsService.safeReadPdf(path);
      meta = await Isolate.run(() {
        final doc = PdfDocument(inputBytes: bytes);
        final info = doc.documentInformation;
        final m = _Meta(
          title: info.title,
          author: info.author,
          subject: info.subject,
          keywords: info.keywords,
        );
        doc.dispose();
        return m;
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
      _titleCtrl.text = meta.title;
      _authorCtrl.text = meta.author;
      _subjectCtrl.text = meta.subject;
      _keywordsCtrl.text = meta.keywords;
    });
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await PdfToolsService.safeReadPdf(_path!);
      final title = _titleCtrl.text.trim();
      final author = _authorCtrl.text.trim();
      final subject = _subjectCtrl.text.trim();
      final keywords = _keywordsCtrl.text.trim();
      final out = await Isolate.run(
        () => _metadataIsolate(bytes, title, author, subject, keywords),
      );

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/metadata_$ts.pdf';
      await File(outPath).writeAsBytes(out);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showResultSheet(
        context,
        outputPath: outPath,
        operationLabel: 'Métadonnées mises à jour',
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
        title: const Text('Métadonnées PDF'),
        actions: [
          if (_path != null)
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
            Icon(
              Icons.info_outline,
              size: 88,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 24),
            Text(
              'Métadonnées PDF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Modifiez le titre, l\'auteur et les informations du document',
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

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          PdfFileHeader(name: _name!, onChange: _pickFile),
          const SizedBox(height: 16),
          _field(_titleCtrl, 'Titre', Icons.title),
          const SizedBox(height: 12),
          _field(_authorCtrl, 'Auteur', Icons.person_outline),
          const SizedBox(height: 12),
          _field(_subjectCtrl, 'Sujet', Icons.subject),
          const SizedBox(height: 12),
          _field(
            _keywordsCtrl,
            'Mots-clés',
            Icons.label_outline,
            hint: 'Séparés par des virgules',
          ),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
  }) {
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

class _Meta {
  final String title;
  final String author;
  final String subject;
  final String keywords;
  const _Meta({
    required this.title,
    required this.author,
    required this.subject,
    required this.keywords,
  });
}

Uint8List _metadataIsolate(
  Uint8List bytes,
  String title,
  String author,
  String subject,
  String keywords,
) {
  final doc = PdfDocument(inputBytes: bytes);
  doc.documentInformation.title = title;
  doc.documentInformation.author = author;
  doc.documentInformation.subject = subject;
  doc.documentInformation.keywords = keywords;
  final saved = doc.saveSync();
  doc.dispose();
  return saved is Uint8List ? saved : Uint8List.fromList(saved);
}
