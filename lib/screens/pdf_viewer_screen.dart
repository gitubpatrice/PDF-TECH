import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_window.dart';
import '../services/share_service.dart';
import '../utils/atomic_write.dart';
import '../utils/snack_utils.dart';

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

  // Password handling for protected PDFs (audit P1) :
  // - `_password` est passé à `SfPdfViewer.file(... password: _password)`.
  // - Sur `onDocumentLoadFailed` (mauvais mot de passe ou PDF chiffré),
  //   un dialog demande la saisie puis on rebuild le viewer via
  //   `key: ValueKey(_passwordAttempt)` pour forcer Syncfusion à
  //   relancer le décodage avec le nouveau password.
  // - Le mot de passe n'est JAMAIS logué.
  String? _password;
  int _passwordAttempt = 0;
  bool _passwordDialogOpen = false;

  String get _prefKey => 'last_page_${widget.path.hashCode}';
  String get _nightKey => 'night_mode_pdf';

  /// F2 v1.12.4 — Cap LRU sur les clés `last_page_*` : sans purge, scanner
  /// 5000 PDFs (recursive `/storage`) gonflait SharedPreferences à plusieurs
  /// Mo. La clé `_idxKey` mémoire l'ordre LRU (path.hashCode) ; au-delà de
  /// `_lastPageMaxEntries`, on évince les plus anciennes.
  static const _idxKey = 'last_page_lru_v1';
  static const _lastPageMaxEntries = 200;

  /// F12 v1.12.4 — Debounce du `_saveLastPage` (avant : un setInt par page
  /// traversée sur scroll rapide → pression IO sur SharedPreferences XML).
  Timer? _saveLastPageDebounce;
  int? _pendingPageToSave;

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

  /// F2 v1.12.4 — Maintient un index LRU des hashCodes path. Au-delà de
  /// `_lastPageMaxEntries`, évince les plus anciennes entrées `last_page_*`.
  Future<void> _bumpLruAndCap(SharedPreferences prefs, int currentHash) async {
    final raw = prefs.getStringList(_idxKey) ?? const <String>[];
    // Retire le hash courant s'il existe déjà, puis le remet en queue.
    final updated = raw.where((h) => h != '$currentHash').toList()
      ..add('$currentHash');
    while (updated.length > _lastPageMaxEntries) {
      final evicted = updated.removeAt(0);
      await prefs.remove('last_page_$evicted');
    }
    await prefs.setStringList(_idxKey, updated);
  }

  Future<void> _saveLastPage(int page) async {
    // Debounce : on stocke la page en attente, le timer flush dans 500 ms.
    _pendingPageToSave = page;
    _saveLastPageDebounce?.cancel();
    _saveLastPageDebounce = Timer(const Duration(milliseconds: 500), () async {
      final p = _pendingPageToSave;
      if (p == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, p);
      await _bumpLruAndCap(prefs, widget.path.hashCode);
      _pendingPageToSave = null;
    });
  }

  Future<void> _toggleNightMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _nightMode = !_nightMode);
    await prefs.setBool(_nightKey, _nightMode);
  }

  @override
  void dispose() {
    // F12 v1.12.4 — flush final si une page en attente n'a pas encore été
    // persistée (debounce 500 ms). Best-effort, fire-and-forget.
    _saveLastPageDebounce?.cancel();
    final p = _pendingPageToSave;
    if (p != null) {
      unawaited(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefKey, p);
        await _bumpLruAndCap(prefs, widget.path.hashCode);
      }());
    }
    // F1 v1.12.2 — relâche SecureWindow si le PDF était password-protected.
    if (_password != null) {
      SecureWindow.disable();
    }
    // Ordre important : libérer les overlays Syncfusion AVANT de disposer le
    // controller (sinon `_searchResult.clear()` appellerait des callbacks sur
    // un controller déjà disposé).
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
      // **Atomique** (audit failles P0 v1.12) : write tmp + rename pour
      // garantir qu'un crash / batterie HS pendant l'écriture ne
      // tronque pas le PDF original. Sans ça, sur 200 Mo l'utilisateur
      // peut perdre un PDF complet.
      await atomicWriteBytes(widget.path, bytes);
      // U8 v1.12.4 — feedback haptique sur save réussi (sinon l'utilisateur
      // ne sait pas distinguer un tap qui a fonctionné d'un tap raté).
      HapticFeedback.selectionClick();
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
    // F5 v1.12.4 — Active FLAG_SECURE AVANT le `showDialog`. Avant : le
    // dialog password était affiché en clair pendant la saisie (le flag
    // n'était posé qu'après `Navigator.pop`). Une capture Recents /
    // MediaProjection pouvait intercepter le mot de passe dans cette
    // fenêtre. Cohérent avec Notes Tech F8 v1.0.9.
    final secureWasActive = _password != null;
    if (!secureWasActive) {
      SecureWindow.enable();
    }
    final ctrl = TextEditingController();
    bool obscure = true;
    try {
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
                  // U4 v1.12.4 — désactive Samsung Pass / Google Autofill
                  // (anti capture cross-app du password PDF).
                  autofillHints: const <String>[],
                  // U4 v1.12.4 — bloque sélection/copie quand masqué (anti
                  // clipboard manager tiers).
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
        // F5 v1.12.4 — Annulation : on relâche le FLAG_SECURE posé en
        // amont (sinon il restait actif sur l'écran parent jusqu'à
        // dispose).
        if (!secureWasActive) SecureWindow.disable();
        // L'utilisateur a annulé : on ferme le viewer.
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _password = entered;
        _passwordAttempt++;
      });
      // F1 v1.12.2 — FLAG_SECURE déjà actif (posé avant showDialog, F5
      // v1.12.4), on n'incrémente PAS le refcount une 2e fois.
    } finally {
      _passwordDialogOpen = false;
      // Le controller TextEditing du dialog est local, on le libère.
      ctrl.dispose();
    }
  }

  Widget _buildViewer() {
    return SfPdfViewer.file(
      File(widget.path),
      key: _viewerKey,
      controller: _controller,
      password: _password,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onDocumentLoadFailed: (details) {
        // Capte les erreurs de chargement, en particulier les PDF
        // protégés. Ne PAS loguer `_password` ni le contenu de
        // `details.description` qui peut le contenir.
        if (!mounted) return;
        final desc = details.description.toLowerCase();
        final isPwd =
            desc.contains('password') ||
            desc.contains('encrypt') ||
            desc.contains('mot de passe');
        if (isPwd) {
          _promptPassword(isWrong: _password != null);
        } else {
          showErrorSnack(context, 'Impossible d\'ouvrir le PDF');
        }
      },
      onDocumentLoaded: (d) {
        // Le callback peut tomber après dispose si l'utilisateur ferme
        // pendant le chargement → mounted check obligatoire avant
        // setState/ScaffoldMessenger.
        if (!mounted) return;
        setState(() => _totalPages = d.document.pages.count);
        if (_savedPage > 1 && _savedPage <= d.document.pages.count) {
          _controller.jumpToPage(_savedPage);
          showInfoSnack(
            context,
            'Reprise à la page $_savedPage',
            duration: const Duration(seconds: 2),
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
                    // U5 v1.12.4 — tooltip TalkBack.
                    tooltip: 'Plus d\'options',
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
                  // Libère les overlays Syncfusion de l'ancien résultat
                  // (un seul `clear()` suffit avant la nouvelle assignation).
                  _searchResult.clear();
                  if (text.isEmpty) {
                    setState(() {});
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
                // Force la reconstruction du sous-arbre quand
                // l'utilisateur saisit un nouveau password — sinon
                // Syncfusion garde le document en échec.
                child: KeyedSubtree(
                  key: ValueKey('pdf_attempt_$_passwordAttempt'),
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
    // v1.12.5 (U5) — Semantics avec `selected: active` pour TalkBack.
    // Avant : Tooltip seul → l'annonceur disait juste le label, sans
    // indiquer si le mode était activé ou non. `excludeSemantics` évite
    // que les enfants (Icon) annoncent à nouveau.
    return Semantics(
      label: label,
      selected: active,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
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
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.5),
                    ),
                  )
                : null,
            child: Icon(
              icon,
              color: active ? activeColor : Colors.grey,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
