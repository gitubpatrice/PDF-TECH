import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

import 'package:pdf_tech/widgets/pdf_picker_screen.dart';

import 'services/form_field_analyzer.dart';
import 'widgets/file_header.dart';
import 'widgets/form_field_list.dart';
import 'widgets/form_viewer_screen.dart';

class FormFillScreen extends StatefulWidget {
  const FormFillScreen({super.key});

  @override
  State<FormFillScreen> createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  String? _path;
  String? _name;
  List<FormFieldInfo> _fields = [];
  bool _hasForm = false;
  bool _isAnalyzing = false;

  final FormFieldAnalyzer _analyzer = const FormFieldAnalyzer();

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir un PDF',
    );
    if (!mounted) return;
    if (path == null) return;

    final name = PathUtils.fileName(path);
    setState(() {
      _isAnalyzing = true;
      _path = path;
      _name = name;
      _fields = [];
      _hasForm = false;
    });

    try {
      final fields = await _analyzer.analyze(path);
      setState(() {
        _fields = fields;
        _hasForm = fields.isNotEmpty;
        _isAnalyzing = false;
      });
    } catch (_) {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _openViewer() async {
    if (_path == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormViewerScreen(path: _path!, name: _name!),
      ),
    );
    // Recharge les valeurs si l'utilisateur a rempli le formulaire.
    if (_path != null && _hasForm && mounted) {
      setState(() => _isAnalyzing = true);
      try {
        final updated = await _analyzer.analyze(_path!);
        if (mounted) {
          setState(() {
            _fields = updated;
            _isAnalyzing = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remplir un formulaire')),
      body: _path == null ? _buildPicker() : _buildPreview(),
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
              Icons.assignment_outlined,
              size: 88,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 24),
            Text(
              'Formulaire PDF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Sélectionnez un PDF avec des champs interactifs pour le remplir',
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

  Widget _buildPreview() {
    if (_isAnalyzing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        FileHeader(name: _name!, onChange: _pickFile),
        const Divider(height: 1),
        if (!_hasForm)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 56,
                      color: Colors.orange[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun champ de formulaire détecté',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ce PDF ne contient pas de formulaire interactif.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _openViewer,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ouvrir quand même'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 17),
                const SizedBox(width: 6),
                Text(
                  '${_fields.length} champ${_fields.length > 1 ? 's' : ''} détecté${_fields.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: FormFieldList(fields: _fields)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _openViewer,
              icon: const Icon(Icons.edit_document),
              label: const Text('Remplir le formulaire'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
