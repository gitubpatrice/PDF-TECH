import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../services/pdf_tools_service.dart';
import '../../services/share_service.dart';
import '../../widgets/result_sheet.dart';
import '../../widgets/pdf_picker_screen.dart';

class FormFillScreen extends StatefulWidget {
  const FormFillScreen({super.key});

  @override
  State<FormFillScreen> createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  String? _path;
  String? _name;
  List<_FieldInfo> _fields = [];
  bool _hasForm = false;
  bool _isAnalyzing = false;

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir un PDF',
    );
    if (!mounted) return;
    if (path == null) return;

    final name = path.split(RegExp(r'[/\\]')).last;
    setState(() {
      _isAnalyzing = true;
      _path = path;
      _name = name;
      _fields = [];
      _hasForm = false;
    });

    try {
      final fields = await _analyzeFields(path);
      setState(() {
        _fields = fields;
        _hasForm = fields.isNotEmpty;
        _isAnalyzing = false;
      });
    } catch (_) {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<List<_FieldInfo>> _analyzeFields(String path) async {
    final bytes = await PdfToolsService.safeReadPdf(path);
    final doc = PdfDocument(inputBytes: bytes);
    final result = <_FieldInfo>[];
    for (int i = 0; i < doc.form.fields.count; i++) {
      final f = doc.form.fields[i];
      final rawName = f.name;
      result.add(
        _FieldInfo(
          name: (rawName == null || rawName.isEmpty)
              ? 'Champ ${i + 1}'
              : rawName,
          type: _typeName(f),
          value: _fieldValue(f),
          icon: _typeIcon(f),
        ),
      );
    }
    doc.dispose();
    return result;
  }

  String _typeName(PdfField f) {
    if (f is PdfTextBoxField) return 'Texte';
    if (f is PdfCheckBoxField) return 'Case à cocher';
    if (f is PdfRadioButtonListField) return 'Bouton radio';
    if (f is PdfComboBoxField) return 'Liste déroulante';
    if (f is PdfListBoxField) return 'Liste';
    return 'Champ';
  }

  String _fieldValue(PdfField f) {
    if (f is PdfTextBoxField) return f.text.isEmpty ? '—' : f.text;
    if (f is PdfCheckBoxField) return f.isChecked ? '✓ Coché' : '☐ Vide';
    if (f is PdfRadioButtonListField) {
      return f.selectedValue.isEmpty ? '—' : f.selectedValue;
    }
    if (f is PdfComboBoxField) {
      return f.selectedValue.isEmpty ? '—' : f.selectedValue;
    }
    return '—';
  }

  IconData _typeIcon(PdfField f) {
    if (f is PdfTextBoxField) return Icons.text_fields;
    if (f is PdfCheckBoxField) return Icons.check_box_outlined;
    if (f is PdfRadioButtonListField) return Icons.radio_button_checked;
    if (f is PdfComboBoxField) return Icons.arrow_drop_down_circle_outlined;
    return Icons.input;
  }

  Future<void> _openViewer() async {
    if (_path == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FormViewerScreen(path: _path!, name: _name!),
      ),
    );
    // Reload field values after user may have filled the form
    if (_path != null && _hasForm && mounted) {
      setState(() => _isAnalyzing = true);
      try {
        final updated = await _analyzeFields(_path!);
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
        _FileHeader(name: _name!, onChange: _pickFile),
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              itemCount: _fields.length,
              itemBuilder: (_, i) {
                final f = _fields[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 5),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      f.icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    title: Text(
                      f.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      f.type,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      f.value,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
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

// ── File header ───────────────────────────────────────────────────────────────

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
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Changer')),
        ],
      ),
    );
  }
}

// ── Form viewer screen ────────────────────────────────────────────────────────

class _FormViewerScreen extends StatefulWidget {
  final String path;
  final String name;
  const _FormViewerScreen({required this.path, required this.name});

  @override
  State<_FormViewerScreen> createState() => _FormViewerScreenState();
}

class _FormViewerScreenState extends State<_FormViewerScreen> {
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();
  late final PdfViewerController _controller;
  bool _hasChanges = false;
  bool _isSaving = false;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _controller.saveDocument();
      await File(widget.path).writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formulaire sauvegardé'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _flatten() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aplatir le formulaire'),
        content: const Text(
          'Les champs seront convertis en texte statique. '
          'Le formulaire ne sera plus modifiable. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aplatir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final filled = await _controller.saveDocument();
      final filledBytes = filled is Uint8List
          ? filled
          : Uint8List.fromList(filled);
      final out = await Isolate.run(() => _flattenIsolate(filledBytes));
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/formulaire_aplati_$ts.pdf';
      await File(outPath).writeAsBytes(out);

      if (!mounted) return;
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      showResultSheet(
        context,
        outputPath: outPath,
        operationLabel: 'Formulaire aplati',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Formulaire non sauvegardé'),
        content: const Text(
          'Voulez-vous sauvegarder vos réponses avant de quitter ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ignorer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              await _save();
              if (mounted) Navigator.pop(context, true);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
    if (result == null) return false;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          final canPop = await _onWillPop();
          if (canPop && mounted) nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
              if (_totalPages > 0)
                Text(
                  'Page $_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          actions: [
            if (_hasChanges)
              _isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Sauvegarder',
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _save,
                    ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'flatten') _flatten();
                if (v == 'share') {
                  ShareService().sharePdf(widget.path, widget.name);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'flatten',
                  child: ListTile(
                    leading: Icon(Icons.layers_clear_outlined),
                    title: Text('Aplatir le formulaire'),
                    subtitle: Text('Convertir en PDF statique'),
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Partager'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SfPdfViewer.file(
          File(widget.path),
          key: _viewerKey,
          controller: _controller,
          enableDoubleTapZooming: true,
          enableTextSelection: false,
          onDocumentLoaded: (d) =>
              setState(() => _totalPages = d.document.pages.count),
          onPageChanged: (d) => setState(() => _currentPage = d.newPageNumber),
          onFormFieldValueChanged: (_) => setState(() => _hasChanges = true),
        ),
        bottomNavigationBar: BottomAppBar(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => _controller.previousPage()
                    : null,
              ),
              Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () => _controller.nextPage()
                    : null,
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: _hasChanges && !_isSaving ? _save : null,
                child: const Text('Sauvegarder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Uint8List _flattenIsolate(Uint8List filledBytes) {
  final doc = PdfDocument(inputBytes: filledBytes);
  doc.form.flattenAllFields();
  final saved = doc.saveSync();
  doc.dispose();
  return saved is Uint8List ? saved : Uint8List.fromList(saved);
}

class _FieldInfo {
  final String name;
  final String type;
  final String value;
  final IconData icon;
  const _FieldInfo({
    required this.name,
    required this.type,
    required this.value,
    required this.icon,
  });
}
