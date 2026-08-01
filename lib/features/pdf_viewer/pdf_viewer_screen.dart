import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:pdf_tech/services/secure_window.dart';
import 'package:pdf_tech/utils/atomic_write.dart';
import 'package:pdf_tech/utils/snack_utils.dart';

import 'services/secure_last_page_service.dart';
import 'services/pdf_share_service.dart';
import 'widgets/pdf_annotation_bar.dart';
import 'widgets/pdf_document_viewer.dart';
import 'widgets/pdf_search_bar.dart';
import 'widgets/pdf_viewer_app_bar.dart';

class PdfViewerScreen extends StatefulWidget {
  final String path;
  final String title;

  const PdfViewerScreen({super.key, required this.path, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();
  late final PdfViewerController _controller;
  late final SecureLastPageService _lastPageService;
  late final PdfShareService _shareService;

  bool _showBars = true;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isSearchOpen = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  PdfAnnotationMode _annotationMode = PdfAnnotationMode.none;
  bool _nightMode = false;
  int _savedPage = 1;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();

  String? _password;
  int _passwordAttempt = 0;
  bool _passwordDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _lastPageService = SecureLastPageService();
    _shareService = PdfShareService();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await _lastPageService.load(widget.path);
    setState(() {
      _savedPage = prefs.page;
      _nightMode = prefs.nightMode;
    });
  }

  Future<void> _toggleNightMode() async {
    final next = await _lastPageService.toggleNightMode(_nightMode);
    setState(() => _nightMode = next);
  }

  @override
  void dispose() {
    _lastPageService.dispose();
    unawaited(_lastPageService.flush(widget.path));
    if (_password != null) {
      SecureWindow.disable();
    }
    _searchResult.clear();
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleBars() {
    if (_annotationMode != PdfAnnotationMode.none) return;
    setState(() => _showBars = !_showBars);
  }

  Future<void> _share() async {
    await _shareService.sharePdf(widget.path, widget.title);
  }

  void _setAnnotationMode(PdfAnnotationMode mode) {
    final next = _annotationMode == mode ? PdfAnnotationMode.none : mode;
    setState(() => _annotationMode = next);
    _controller.annotationMode = next;
    if (next != PdfAnnotationMode.none && !_showBars) {
      setState(() => _showBars = true);
    }
  }

  Future<void> _saveAnnotations() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _controller.saveDocument();
      await atomicWriteBytes(widget.path, bytes);
      await HapticFeedback.selectionClick();
      setState(() => _hasUnsavedChanges = false);
      if (!mounted) return;
      showInfoSnack(
        context,
        'Annotations sauvegardées',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annotations non sauvegardées'),
        content: const Text(
          'Voulez-vous sauvegarder vos annotations avant de quitter ?',
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
              await _saveAnnotations();
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

  void _showPageJumpDialog() {
    final ctrl = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aller à la page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Page 1 – $_totalPages'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(ctrl.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                _controller.jumpToPage(page);
              }
              Navigator.pop(context);
            },
            child: const Text('Aller'),
          ),
        ],
      ),
    );
  }

  Future<void> _promptPassword({required bool isWrong}) async {
    if (_passwordDialogOpen || !mounted) return;
    _passwordDialogOpen = true;
    final secureWasActive = _password != null;
    if (!secureWasActive) {
      await SecureWindow.enable();
    }
    final ctrl = TextEditingController();
    bool obscure = true;
    try {
      if (!mounted) return;
      final entered = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('PDF protégé'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWrong
                      ? 'Mot de passe incorrect. Réessayez :'
                      : 'Ce PDF est protégé. Entrez le mot de passe :',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  obscureText: obscure,
                  autofocus: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const <String>[],
                  enableInteractiveSelection: !obscure,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setLocal(() => obscure = !obscure),
                    ),
                  ),
                  onSubmitted: (v) => Navigator.pop(ctx, v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Ouvrir'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (entered == null || entered.isEmpty) {
        if (!secureWasActive) await SecureWindow.disable();
        if (!mounted) return;
        await Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _password = entered;
        _passwordAttempt++;
      });
    } finally {
      _passwordDialogOpen = false;
      ctrl.dispose();
    }
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'zoom_in':
        _controller.zoomLevel = (_controller.zoomLevel + 0.25).clamp(1.0, 5.0);
      case 'zoom_out':
        _controller.zoomLevel = (_controller.zoomLevel - 0.25).clamp(0.5, 5.0);
      case 'fit':
        _controller.zoomLevel = 1.0;
      case 'jump':
        _showPageJumpDialog();
    }
  }

  void _handleDocumentLoaded(PdfDocumentLoadedDetails details) {
    if (!mounted) return;
    setState(() => _totalPages = details.document.pages.count);
    if (_savedPage > 1 && _savedPage <= details.document.pages.count) {
      _controller.jumpToPage(_savedPage);
      showInfoSnack(
        context,
        'Reprise à la page $_savedPage',
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _handlePageChanged(PdfPageChangedDetails details) {
    setState(() => _currentPage = details.newPageNumber);
    _lastPageService.scheduleSave(widget.path, details.newPageNumber);
  }

  void _handleSearch(String text) {
    _searchResult.clear();
    if (text.isEmpty) {
      setState(() {});
      return;
    }
    setState(() {
      _searchResult = _controller.searchText(text);
    });
  }

  void _closeSearch() {
    setState(() => _isSearchOpen = false);
    _searchResult.clear();
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          final canPop = await _onWillPop();
          if (canPop && mounted) {
            nav.pop();
          }
        }
      },
      child: Scaffold(
        appBar: _showBars
            ? PdfViewerAppBar(
                title: widget.title,
                currentPage: _currentPage,
                totalPages: _totalPages,
                hasUnsavedChanges: _hasUnsavedChanges,
                isSaving: _isSaving,
                nightMode: _nightMode,
                isSearchOpen: _isSearchOpen,
                viewerKey: _viewerKey,
                onSave: _saveAnnotations,
                onToggleNightMode: _toggleNightMode,
                onToggleSearch: () =>
                    setState(() => _isSearchOpen = !_isSearchOpen),
                onShare: _share,
                onMenuAction: _handleMenuAction,
              )
            : null,
        body: Column(
          children: [
            if (_isSearchOpen && _showBars)
              PdfSearchBar(
                controller: _searchController,
                onSearch: _handleSearch,
                onNext: () => _searchResult.nextInstance(),
                onPrevious: () => _searchResult.previousInstance(),
                onClose: _closeSearch,
              ),
            Expanded(
              child: GestureDetector(
                onTap: _toggleBars,
                child: PdfDocumentViewer(
                  path: widget.path,
                  controller: _controller,
                  password: _password,
                  nightMode: _nightMode,
                  passwordAttempt: _passwordAttempt,
                  onDocumentLoaded: _handleDocumentLoaded,
                  onPageChanged: _handlePageChanged,
                  onAnnotationChanged: () =>
                      setState(() => _hasUnsavedChanges = true),
                  onPasswordRequested: (isWrong) =>
                      _promptPassword(isWrong: isWrong),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _showBars
            ? PdfAnnotationBar(
                currentPage: _currentPage,
                totalPages: _totalPages,
                activeMode: _annotationMode,
                onModeChanged: _setAnnotationMode,
                onPreviousPage: _currentPage > 1
                    ? () => _controller.previousPage()
                    : null,
                onNextPage: _currentPage < _totalPages
                    ? () => _controller.nextPage()
                    : null,
              )
            : null,
      ),
    );
  }
}
