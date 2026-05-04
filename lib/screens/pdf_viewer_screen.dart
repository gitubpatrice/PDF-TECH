import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/share_service.dart';

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

  String get _prefKey => 'last_page_${widget.path.hashCode}';
  String get _nightKey => 'night_mode_pdf';

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPage = prefs.getInt(_prefKey) ?? 1;
      _nightMode = prefs.getBool(_nightKey) ?? false;
    });
  }

  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, page);
  }

  Future<void> _toggleNightMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _nightMode = !_nightMode);
    await prefs.setBool(_nightKey, _nightMode);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchResult.clear();
    super.dispose();
  }

  void _toggleBars() {
    if (_annotationMode != PdfAnnotationMode.none) return;
    setState(() => _showBars = !_showBars);
  }

  Future<void> _share() async {
    await ShareService().sharePdf(widget.path, widget.title);
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
      await File(widget.path).writeAsBytes(bytes);
      setState(() => _hasUnsavedChanges = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Annotations sauvegardées'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de sauvegarde : $e')));
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

  Widget _buildViewer() {
    return SfPdfViewer.file(
      File(widget.path),
      key: _viewerKey,
      controller: _controller,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onDocumentLoaded: (d) {
        // Le callback peut tomber après dispose si l'utilisateur ferme
        // pendant le chargement → mounted check obligatoire avant
        // setState/ScaffoldMessenger.
        if (!mounted) return;
        setState(() => _totalPages = d.document.pages.count);
        if (_savedPage > 1 && _savedPage <= d.document.pages.count) {
          _controller.jumpToPage(_savedPage);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reprise à la page $_savedPage'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onPageChanged: (d) {
        setState(() => _currentPage = d.newPageNumber);
        _saveLastPage(d.newPageNumber);
      },
      onAnnotationAdded: (_) => setState(() => _hasUnsavedChanges = true),
      onAnnotationEdited: (_) => setState(() => _hasUnsavedChanges = true),
      onAnnotationRemoved: (_) => setState(() => _hasUnsavedChanges = true),
      onFormFieldValueChanged: (_) => setState(() => _hasUnsavedChanges = true),
    );
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
            ? AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                    if (_totalPages > 0)
                      Text(
                        'Page $_currentPage / $_totalPages',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                actions: [
                  if (_hasUnsavedChanges)
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
                            tooltip: 'Sauvegarder les annotations',
                            icon: const Icon(Icons.save_outlined),
                            onPressed: _saveAnnotations,
                          ),
                  IconButton(
                    tooltip: _nightMode ? 'Mode jour' : 'Mode nuit',
                    icon: Icon(_nightMode ? Icons.light_mode : Icons.dark_mode),
                    onPressed: _toggleNightMode,
                  ),
                  IconButton(
                    tooltip: 'Rechercher',
                    icon: Icon(_isSearchOpen ? Icons.search_off : Icons.search),
                    onPressed: () =>
                        setState(() => _isSearchOpen = !_isSearchOpen),
                  ),
                  IconButton(
                    tooltip: 'Signets',
                    icon: const Icon(Icons.bookmark_outline),
                    onPressed: () =>
                        _viewerKey.currentState?.openBookmarkView(),
                  ),
                  IconButton(
                    tooltip: 'Partager',
                    icon: const Icon(Icons.share),
                    onPressed: _share,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'zoom_in':
                          _controller.zoomLevel = (_controller.zoomLevel + 0.25)
                              .clamp(1.0, 5.0);
                        case 'zoom_out':
                          _controller.zoomLevel = (_controller.zoomLevel - 0.25)
                              .clamp(0.5, 5.0);
                        case 'fit':
                          _controller.zoomLevel = 1.0;
                        case 'jump':
                          _showPageJumpDialog();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'zoom_in',
                        child: ListTile(
                          leading: Icon(Icons.zoom_in),
                          title: Text('Zoom avant'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'zoom_out',
                        child: ListTile(
                          leading: Icon(Icons.zoom_out),
                          title: Text('Zoom arrière'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'fit',
                        child: ListTile(
                          leading: Icon(Icons.fit_screen),
                          title: Text('Ajuster à l\'écran'),
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'jump',
                        child: ListTile(
                          leading: Icon(Icons.input),
                          title: Text('Aller à la page…'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : null,
        body: Column(
          children: [
            if (_isSearchOpen && _showBars)
              _SearchBar(
                controller: _searchController,
                onSearch: (text) {
                  if (text.isEmpty) {
                    _searchResult.clear();
                    return;
                  }
                  setState(() {
                    _searchResult = _controller.searchText(text);
                  });
                },
                onNext: () => _searchResult.nextInstance(),
                onPrev: () => _searchResult.previousInstance(),
                onClose: () {
                  setState(() => _isSearchOpen = false);
                  _searchResult.clear();
                  _searchController.clear();
                },
              ),
            Expanded(
              child: GestureDetector(
                onTap: _toggleBars,
                child: _nightMode
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          -1,
                          0,
                          0,
                          0,
                          255,
                          0,
                          -1,
                          0,
                          0,
                          255,
                          0,
                          0,
                          -1,
                          0,
                          255,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: _buildViewer(),
                      )
                    : _buildViewer(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _showBars
            ? _AnnotationBar(
                currentPage: _currentPage,
                totalPages: _totalPages,
                activeMode: _annotationMode,
                onModeChanged: _setAnnotationMode,
                onPrev: _currentPage > 1
                    ? () => _controller.previousPage()
                    : null,
                onNext: _currentPage < _totalPages
                    ? () => _controller.nextPage()
                    : null,
              )
            : null,
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Rechercher dans le PDF…',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: onSearch,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 20),
            onPressed: onPrev,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 20),
            onPressed: onNext,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ── Annotation bar ────────────────────────────────────────────────────────────

class _AnnotationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final PdfAnnotationMode activeMode;
  final ValueChanged<PdfAnnotationMode> onModeChanged;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _AnnotationBar({
    required this.currentPage,
    required this.totalPages,
    required this.activeMode,
    required this.onModeChanged,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModeButton(
            icon: Icons.highlight,
            label: 'Surligner',
            activeColor: Colors.yellow[700]!,
            active: activeMode == PdfAnnotationMode.highlight,
            onTap: () => onModeChanged(PdfAnnotationMode.highlight),
          ),
          _ModeButton(
            icon: Icons.format_underline,
            label: 'Souligner',
            activeColor: Colors.blue,
            active: activeMode == PdfAnnotationMode.underline,
            onTap: () => onModeChanged(PdfAnnotationMode.underline),
          ),
          _ModeButton(
            icon: Icons.strikethrough_s,
            label: 'Barrer',
            activeColor: Colors.red,
            active: activeMode == PdfAnnotationMode.strikethrough,
            onTap: () => onModeChanged(PdfAnnotationMode.strikethrough),
          ),
          _ModeButton(
            icon: Icons.format_color_text,
            label: 'Ondulé',
            activeColor: Colors.purple,
            active: activeMode == PdfAnnotationMode.squiggly,
            onTap: () => onModeChanged(PdfAnnotationMode.squiggly),
          ),
          _ModeButton(
            icon: Icons.sticky_note_2_outlined,
            label: 'Note',
            activeColor: Colors.orange,
            active: activeMode == PdfAnnotationMode.stickyNote,
            onTap: () => onModeChanged(PdfAnnotationMode.stickyNote),
          ),
          const VerticalDivider(indent: 8, endIndent: 8),
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Text(
            '$currentPage/$totalPages',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color activeColor;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: active
              ? BoxDecoration(
                  color: activeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: activeColor.withValues(alpha: 0.5)),
                )
              : null,
          child: Icon(
            icon,
            color: active ? activeColor : Colors.grey,
            size: 22,
          ),
        ),
      ),
    );
  }
}
