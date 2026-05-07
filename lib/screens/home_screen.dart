import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_update.dart';
import '../services/share_service.dart';
import '../widgets/pdf_picker_screen.dart';
import 'about_screen.dart';
import 'home/cloud_tab.dart';
import 'home/home_tab.dart';
import 'home/pdf_search_delegate.dart';
import 'home/tools_tab.dart';
import 'pdf_viewer_screen.dart';

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
  final _recentFilesService = RecentFilesService();
  final _shareService = ShareService();
  List<RecentFile> _recentFiles = [];
  int _navIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecents();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    final info = await appUpdateService.checkForUpdate();
    if (info == null || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('Mise à jour v${info.version} disponible'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.body.isNotEmpty
                      ? info.body
                      : 'Une nouvelle version de PDF Tech est disponible.',
                ),
                if (info.expectedSha256 != null) ...[
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
                          info.expectedSha256!,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Tech'),
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
          ToolsTab(onPickFile: _pickAndOpen),
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
