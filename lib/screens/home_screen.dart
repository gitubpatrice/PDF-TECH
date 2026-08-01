import 'dart:async';

import 'package:files_tech_core/files_tech_core.dart'
    show RecentFile, PathUtils;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;

import '../services/app_update.dart';
import '../utils/date_utils.dart';
import '../services/secure_recent_files_service.dart';
import '../services/secure_update_service.dart';
import '../services/share_service.dart';
import '../widgets/pdf_picker_screen.dart';
import 'about_screen.dart';
import 'home/cloud_tab.dart';
import 'home/home_tab.dart';
import 'home/pdf_search_delegate.dart';
import 'home/tools_tab.dart';
import '../features/pdf_viewer/pdf_viewer_screen.dart';

/// Écran d'accueil orchestrateur — gère la navigation entre les 3 onglets
/// (Accueil / Outils / Cloud), le chargement des fichiers récents, l'ouverture
/// de PDFs et la vérification des mises à jour. La logique métier de chaque
/// onglet est isolée dans `lib/screens/home/*.dart`.
class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recentFilesService = const SecureRecentFilesService();
  final _shareService = ShareService();
  List<RecentFile> _recentFiles = [];
  int _navIndex = 0;
  bool _isLoading = true;

  /// Réception des PDFs ouverts depuis une autre app (Infomaniak Mail
  /// « Visualiser », gestionnaire de fichiers…). Le natif copie le flux
  /// content:// dans le cache et expose le path via ce channel.
  static const _incomingChannel = MethodChannel(
    'com.pdftech.pdf_tech/incoming',
  );

  @override
  void initState() {
    super.initState();
    _loadRecents();
    // Warm start : le natif pousse le path quand l'app est déjà vivante.
    _incomingChannel.setMethodCallHandler(_onIncomingCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
      _consumeInitialPdf();
    });
  }

  @override
  void dispose() {
    _incomingChannel.setMethodCallHandler(null);
    super.dispose();
  }

  /// Cold start : tire le PDF capturé par le natif au lancement.
  Future<void> _consumeInitialPdf() async {
    try {
      final path = await _incomingChannel.invokeMethod<String>('getInitialPdf');
      if (path != null && path.isNotEmpty) await _openIncoming(path);
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeScreen._consumeInitialPdf] $e');
    }
  }

  Future<dynamic> _onIncomingCall(MethodCall call) async {
    if (call.method == 'onNewPdf') {
      final path = call.arguments as String?;
      if (path != null && path.isNotEmpty) await _openIncoming(path);
    }
    return null;
  }

  /// Ouvre directement le viewer sur un PDF importé. Volontairement hors
  /// « récents » : le fichier vit dans le cache (purgé), un raccourci récent
  /// pointerait vers un path mort. Conception mono-déclenchement (cold start
  /// lit le path une fois, warm start le pousse une fois) → ouvrir un nouveau
  /// PDF pendant la lecture en empile un autre, comportement attendu.
  Future<void> _openIncoming(String path) async {
    if (!mounted) return;
    final name = PathUtils.fileName(path);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(path: path, title: name),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    // H2 v1.12.3 — guard try/catch : checkForUpdate peut throw (timeout
    // réseau, JSON malformé). Sans guard, l'exception remontait dans
    // FlutterError.onError au boot via addPostFrameCallback.
    UpdateInfo? info;
    try {
      info = await appUpdateService.checkForUpdate();
    } catch (e) {
      // F15 v1.12.4 — gate kDebugMode pour ne pas leak l'erreur dans
      // logcat release (peut contenir path utilisateur / URL).
      if (kDebugMode) debugPrint('[HomeScreen._checkUpdate] $e');
      return;
    }
    if (info == null || !mounted) return;
    final updateInfo = info;
    unawaited(
      showDialog(
        context: context,
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: Text('Mise à jour v${updateInfo.version} disponible'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    updateInfo.body.isNotEmpty
                        ? updateInfo.body
                        : 'Une nouvelle version de PDF Tech est disponible.',
                  ),
                  if (updateInfo.expectedSha256 != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 14,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'SHA-256 attendu (APK arm64-v8a)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            updateInfo.expectedSha256!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Plus tard'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadRecents() async {
    final files = await _recentFilesService.load();
    if (mounted) {
      setState(() {
        _recentFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndOpen() async {
    final path = await PdfPickerScreen.pickOne(context, title: 'Ouvrir un PDF');
    if (path == null) return;
    await _openPdf(path);
  }

  Future<void> _openPdf(String path) async {
    final updated = await _recentFilesService.addOrUpdate(_recentFiles, path);
    if (mounted) setState(() => _recentFiles = updated);

    if (!mounted) return;
    final name = PathUtils.fileName(path);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(path: path, title: name),
      ),
    );
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  Future<void> _removeRecent(RecentFile file) async {
    final updated = await _recentFilesService.remove(_recentFiles, file.path);
    if (mounted) setState(() => _recentFiles = updated);
  }

  Future<void> _toggleFavorite(RecentFile file) async {
    final updated = await _recentFilesService.toggleFavorite(
      _recentFiles,
      file.path,
    );
    if (mounted) setState(() => _recentFiles = updated);
  }

  // v1.12.5 (D3) — délégué à DateFormatUtils.relative (extrait dans
  // utils/date_utils.dart) pour partager l'implémentation avec
  // pdf_folder_screen. Pattern P2.1 v1.12.4 (DateFormat static) préservé.
  String _formatDate(DateTime date) => DateFormatUtils.relative(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/logo_damier.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 10),
            const Text('PDF Tech'),
          ],
        ),
        actions: [
          if (_navIndex == 0 && _recentFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Rechercher',
              onPressed: () => showSearch(
                context: context,
                delegate: PdfSearchDelegate(_recentFiles, _openPdf),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'À propos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          PopupMenuButton<ThemeMode>(
            tooltip: 'Thème',
            icon: Icon(_themeModeIcon(widget.themeMode)),
            onSelected: widget.onThemeChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ThemeMode.light,
                child: ListTile(
                  leading: Icon(Icons.light_mode),
                  title: Text('Clair'),
                ),
              ),
              PopupMenuItem(
                value: ThemeMode.dark,
                child: ListTile(
                  leading: Icon(Icons.dark_mode),
                  title: Text('Sombre'),
                ),
              ),
              PopupMenuItem(
                value: ThemeMode.system,
                child: ListTile(
                  leading: Icon(Icons.brightness_auto),
                  title: Text('Automatique'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _navIndex,
        children: [
          HomeTab(
            recentFiles: _recentFiles,
            isLoading: _isLoading,
            onOpen: _openPdf,
            onPickFile: _pickAndOpen,
            onRemove: _removeRecent,
            onToggleFavorite: _toggleFavorite,
            onShare: (f) => _shareService.sharePdf(f.path, f.name),
            formatDate: _formatDate,
          ),
          const ToolsTab(),
          const CloudTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Outils',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Cloud',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndOpen,
        icon: const Icon(Icons.folder_open),
        label: const Text('Ouvrir un PDF'),
      ),
    );
  }
}
