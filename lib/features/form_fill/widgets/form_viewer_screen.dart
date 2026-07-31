import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf_tech/services/secure_window.dart';
import 'package:pdf_tech/services/share_service.dart';
import 'package:pdf_tech/utils/snack_utils.dart';
import 'package:pdf_tech/widgets/result_sheet.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../services/form_save_service.dart';
import '../services/pdf_flatten_service.dart';

/// Viewer dédié au remplissage d'un formulaire PDF.
class FormViewerScreen extends StatefulWidget {
  final String path;
  final String name;

  const FormViewerScreen({super.key, required this.path, required this.name});

  @override
  State<FormViewerScreen> createState() => _FormViewerScreenState();
}

class _FormViewerScreenState extends State<FormViewerScreen> {
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();
  late final PdfViewerController _controller;
  final FormSaveService _saveService = const FormSaveService();
  final PdfFlattenService _flattenService = const PdfFlattenService();

  bool _hasChanges = false;
  bool _isSaving = false;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    // Bloque captures d'écran / aperçu Recents : un formulaire PDF contient
    // souvent des PII (nom, adresse, données bancaires/santé). Aligné sur
    // signature_screen (F1 v1.12.2). SecureWindow est refcount-aware.
    SecureWindow.enable();
  }

  @override
  void dispose() {
    SecureWindow.disable();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _controller.saveDocument();
      await _saveService.save(widget.path, bytes);
      if (!mounted) return;
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      showInfoSnack(
        context,
        'Formulaire sauvegardé',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorSnack(context, e);
    }
  }

  Future<void> _flatten() async {
    final cs = Theme.of(context).colorScheme;
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
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
            ),
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
      final outPath = await _flattenService.flattenAndWrite(
        filledBytes,
        outputName: 'formulaire_aplati',
      );

      if (!mounted) return;
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      unawaited(
        showResultSheet(
          context,
          outputPath: outPath,
          operationLabel: 'Formulaire aplati',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorSnack(context, e);
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
                tooltip: 'Page précédente',
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
                tooltip: 'Page suivante',
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
