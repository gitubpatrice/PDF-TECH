import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:files_tech_core/files_tech_core.dart';
import '../services/share_service.dart';
import '../services/app_update.dart';
import 'pdf_viewer_screen.dart';
import 'tools/merge_screen.dart';
import 'tools/split_screen.dart';
import 'tools/protect_screen.dart';
import 'tools/rotate_screen.dart';
import 'tools/watermark_screen.dart';
import 'tools/create_pdf_screen.dart';
import 'tools/compress_screen.dart';
import 'tools/signature_screen.dart';
import 'tools/form_fill_screen.dart';
import 'tools/ocr_screen.dart';
import 'tools/delete_pages_screen.dart';
import 'tools/reorder_pages_screen.dart';
import 'tools/export_images_screen.dart';
import 'tools/metadata_screen.dart';
import 'tools/page_numbers_screen.dart';
import 'tools/stamp_screen.dart';
import 'tools/header_footer_screen.dart';
import 'tools/extract_images_screen.dart';
import 'tools/compare_screen.dart';
import 'tools/images_to_pdf_screen.dart';
import 'tools/decrypt_screen.dart';
import 'cloud/google_drive_screen.dart';
import 'about_screen.dart';
import 'pdf_folder_screen.dart';
import '../widgets/pdf_picker_screen.dart';
import 'tools/pdf_annotate_screen.dart';

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
                Text(info.body.isNotEmpty
                    ? info.body
                    : 'Une nouvelle version de PDF Tech est disponible.'),
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
                        Row(children: [
                          Icon(Icons.verified_outlined,
                              size: 14, color: cs.primary),
                          const SizedBox(width: 6),
                          const Text('SHA-256 attendu (APK arm64-v8a)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
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
                child: const Text('Plus tard')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        );
      },
    );
  }

  Future<void> _loadRecents() async {
    final files = await _recentFilesService.load();
    if (mounted) setState(() { _recentFiles = files; _isLoading = false; });
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
    final name = path.split(RegExp(r'[/\\]')).last;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerScreen(path: path, title: name)),
    );
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:  return Icons.light_mode;
      case ThemeMode.dark:   return Icons.dark_mode;
      case ThemeMode.system: return Icons.brightness_auto;
    }
  }

  Future<void> _removeRecent(RecentFile file) async {
    final updated = await _recentFilesService.remove(_recentFiles, file.path);
    if (mounted) setState(() => _recentFiles = updated);
  }

  Future<void> _toggleFavorite(RecentFile file) async {
    final updated = await _recentFilesService.toggleFavorite(_recentFiles, file.path);
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
                delegate: _PdfSearchDelegate(_recentFiles, _openPdf),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'À propos',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
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
          _HomeTab(
            recentFiles: _recentFiles,
            isLoading: _isLoading,
            onOpen: _openPdf,
            onPickFile: _pickAndOpen,
            onRemove: _removeRecent,
            onToggleFavorite: _toggleFavorite,
            onShare: (f) => _shareService.sharePdf(f.path, f.name),
            formatDate: _formatDate,
          ),
          _ToolsTab(onPickFile: _pickAndOpen),
          const _CloudTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build),
              label: 'Outils'),
          NavigationDestination(
              icon: Icon(Icons.cloud_outlined),
              selectedIcon: Icon(Icons.cloud),
              label: 'Cloud'),
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

// ── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final List<RecentFile> recentFiles;
  final bool isLoading;
  final ValueChanged<String> onOpen;
  final VoidCallback onPickFile;
  final ValueChanged<RecentFile> onRemove;
  final ValueChanged<RecentFile> onToggleFavorite;
  final ValueChanged<RecentFile> onShare;
  final String Function(DateTime) formatDate;

  const _HomeTab({
    required this.recentFiles,
    required this.isLoading,
    required this.onOpen,
    required this.onPickFile,
    required this.onRemove,
    required this.onToggleFavorite,
    required this.onShare,
    required this.formatDate,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static final _storageChannel = MethodChannel('com.pdftech.pdf_tech/storage');
  int _totalBytes = 0;
  int _freeBytes  = 0;

  /// Raccourcis vers les dossiers les plus susceptibles de contenir des PDFs.
  /// Chaque tuile ouvre un PdfFolderScreen filtré .pdf — l'utilisateur n'a
  /// pas à fouiller dans le SAF système.
  static const _browseFolders = [
    (icon: Icons.download_outlined,    label: 'Téléchargements',
        path: '/storage/emulated/0/Download',                color: Color(0xFF43A047)),
    (icon: Icons.description_outlined, label: 'Documents',
        path: '/storage/emulated/0/Documents',               color: Color(0xFF1976D2)),
    (icon: Icons.chat_outlined,        label: 'WhatsApp',
        path: '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
        color: Color(0xFF25D366)),
    (icon: Icons.folder_special_outlined, label: 'PDF Tech',
        path: '/storage/emulated/0/Documents/PDF Tech',     color: Color(0xFFFF7043)),
  ];

  static const _quickActions = [
    (icon: Icons.menu_book_outlined,      label: 'Lire un PDF',   color: Color(0xFF1565C0)),
    (icon: Icons.edit_note,               label: 'Modifier',      color: Color(0xFF6A1B9A)),
    (icon: Icons.merge_type,              label: 'Fusionner',     color: Color(0xFF1976D2)),
    (icon: Icons.call_split,              label: 'Diviser',       color: Color(0xFF43A047)),
    (icon: Icons.compress,                label: 'Compresser',    color: Color(0xFFFF7043)),
    (icon: Icons.add_photo_alternate_outlined, label: 'Images→PDF', color: Color(0xFF8E24AA)),
    (icon: Icons.document_scanner_outlined,    label: 'OCR',       color: Color(0xFFE53935)),
    (icon: Icons.lock_outline,            label: 'Protéger',      color: Color(0xFF00897B)),
  ];

  @override
  void initState() {
    super.initState();
    _loadStorage();
    _ensurePdfTechFolder();
  }

  /// Crée /storage/emulated/0/Documents/PDF Tech/ silencieusement au boot
  /// pour qu'il existe quand l'utilisateur clique sur la tuile correspondante.
  /// Si la perm MANAGE_EXTERNAL_STORAGE n'est pas accordée, l'erreur est
  /// silencieuse — la création sera retentée au prochain clic sur la tuile.
  Future<void> _ensurePdfTechFolder() async {
    try {
      final dir = Directory('/storage/emulated/0/Documents/PDF Tech');
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (_) {}
  }

  Future<void> _loadStorage() async {
    try {
      final res = await _storageChannel.invokeMethod<Map>('getStorageInfo');
      if (res != null && mounted) {
        setState(() {
          _totalBytes = (res['total'] as num).toInt();
          _freeBytes  = (res['free']  as num).toInt();
        });
      }
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _openQuickAction(BuildContext context, int index) {
    // Les 2 premiers indices sont des actions spéciales (Lire / Modifier),
    // les suivants pointent vers les outils existants.
    if (index == 0) { _readLastOrPick(context); return; }
    if (index == 1) { _editPdf(context); return; }
    final screens = [
      const MergeScreen(),
      const SplitScreen(),
      const CompressScreen(),
      const ImagesToPdfScreen(),
      const OcrScreen(),
      const ProtectScreen(),
    ];
    Navigator.push(context, MaterialPageRoute(builder: (_) => screens[index - 2]));
  }

  /// "Lire un PDF" : ouvre le dernier PDF lu si dispo (et fichier existe
  /// toujours), sinon ouvre le PdfPickerScreen pour choisir.
  Future<void> _readLastOrPick(BuildContext context) async {
    final last = widget.recentFiles.isNotEmpty
        ? widget.recentFiles.first
        : null;
    if (last != null && File(last.path).existsSync()) {
      widget.onOpen(last.path);
      return;
    }
    final picked = await PdfPickerScreen.pickOne(context, title: 'Lire un PDF');
    if (picked != null) widget.onOpen(picked);
  }

  /// "Modifier un PDF" : ouvre l'éditeur d'annotations.
  Future<void> _editPdf(BuildContext context) async {
    final picked = await PdfPickerScreen.pickOne(context,
        title: 'PDF à modifier');
    if (picked == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => PdfAnnotateScreen(path: picked)));
  }

  /// Demande MANAGE_EXTERNAL_STORAGE avec un dialog explicatif si manquant.
  /// Sur refus, propose d'ouvrir Réglages. Retourne true si autorisé.
  Future<bool> _ensureStorageAccess() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (!mounted) return false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.folder_outlined, size: 36),
        title: const Text('Accès aux fichiers requis'),
        content: const Text(
          'PDF Tech a besoin d\'accéder à tous les fichiers de votre '
          'téléphone pour parcourir Téléchargements, Documents, WhatsApp '
          'et trouver vos PDFs.\n\nAucun fichier n\'est transmis ailleurs.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Autoriser')),
        ],
      ),
    );
    if (ok != true) return false;

    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Permission refusée — activez "Tous les fichiers" dans Réglages'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Réglages',
        onPressed: () => openAppSettings(),
      ),
    ));
    return false;
  }

  /// Ouvre un PdfFolderScreen filtré sur le path donné. Si le dossier n'existe
  /// pas, deux cas :
  /// - "PDF Tech" (notre dossier app) : on le crée automatiquement, c'est
  ///   l'emplacement où l'app sauvegarde les PDFs générés.
  /// - Autre dossier (ex: WhatsApp jamais utilisé) : message clair, pas de
  ///   création silencieuse pour ne pas créer des dossiers étrangers.
  Future<void> _browseFolder(String path, String label) async {
    if (!await _ensureStorageAccess()) return;
    if (!mounted) return;
    final dir = Directory(path);
    if (!dir.existsSync()) {
      if (label == 'PDF Tech') {
        try {
          await dir.create(recursive: true);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Impossible de créer le dossier PDF Tech : $e'),
          ));
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dossier "$label" introuvable sur ce téléphone'),
        ));
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfFolderScreen(
        path: path,
        title: label,
        onPick: widget.onOpen,
      ),
    ));
  }

  /// Scan récursif de tout /sdcard pour trouver tous les PDFs du tél.
  /// Utile pour le premier lancement quand l'utilisateur ne sait pas où
  /// sont ses fichiers. Affiche un dialog de progression.
  Future<void> _scanAllPdfs() async {
    if (!await _ensureStorageAccess()) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final found = <File>[];
    int scanned = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Recherche des PDFs sur votre téléphone…')),
        ]),
      ),
    );

    try {
      await _walk(Directory('/storage/emulated/0'), found, () => scanned++);
    } catch (_) {/* perm denied — on continue avec ce qu'on a */}

    if (!mounted) return;
    navigator.pop(); // ferme le dialog progress

    if (found.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Aucun PDF trouvé sur ce téléphone'),
      ));
      return;
    }
    found.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    // Affichage : on réutilise PdfFolderScreen avec un dossier virtuel "/" et
    // une liste pré-construite. Plus simple : on crée une nouvelle route
    // dédiée. Ici on push direct un Scaffold avec ListView.
    navigator.push(MaterialPageRoute(
      builder: (_) => _AllPdfsScreen(
        files: found,
        onPick: widget.onOpen,
      ),
    ));
  }

  /// Walk récursif limité aux sous-dossiers utilisateur, ignore caches/Android.
  Future<void> _walk(
      Directory dir, List<File> out, void Function() onTick) async {
    final skip = {'Android', '.thumbnails', '.cache'};
    try {
      await for (final e in dir.list(recursive: false, followLinks: false)) {
        onTick();
        if (e is File) {
          if (e.path.toLowerCase().endsWith('.pdf')) out.add(e);
        } else if (e is Directory) {
          final name = e.path.split('/').last;
          if (skip.contains(name) || name.startsWith('.')) continue;
          await _walk(e, out, onTick);
        }
      }
    } catch (_) {/* dossier inaccessible */}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return const Center(child: CircularProgressIndicator());

    final favorites = widget.recentFiles.where((f) => f.isFavorite).toList();
    final recents   = widget.recentFiles.where((f) => !f.isFavorite).toList();
    final lastFile  = widget.recentFiles.isNotEmpty ? widget.recentFiles.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [

        // ── Stockage ────────────────────────────────────────────────────────
        if (_totalBytes > 0) ...[
          _sectionHeader(context, 'Stockage interne', Icons.storage_outlined, Colors.blueGrey),
          const SizedBox(height: 6),
          _StorageBar(freeBytes: _freeBytes, totalBytes: _totalBytes, formatBytes: _formatBytes),
          const SizedBox(height: 16),
        ],

        // ── Reprendre ───────────────────────────────────────────────────────
        if (lastFile != null) ...[
          _sectionHeader(context, 'Reprendre', Icons.play_circle_outline, Colors.blue),
          const SizedBox(height: 6),
          _ResumeCard(
            file: lastFile,
            formatDate: widget.formatDate,
            onTap: () => widget.onOpen(lastFile.path),
          ),
          const SizedBox(height: 16),
        ],

        // ── Parcourir ───────────────────────────────────────────────────────
        // Toujours visible — accès direct aux dossiers les plus probables.
        _sectionHeader(context, 'Parcourir', Icons.folder_open_outlined, Colors.teal),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
          children: [
            ..._browseFolders.map((f) => _ActionCard(
                  icon: f.icon,
                  label: f.label,
                  color: f.color,
                  onTap: () => _browseFolder(f.path, f.label),
                )),
            _ActionCard(
              icon: Icons.search,
              label: 'Trouver mes PDFs',
              color: const Color(0xFFAB47BC),
              onTap: _scanAllPdfs,
            ),
            _ActionCard(
              icon: Icons.folder_outlined,
              label: 'Choisir…',
              color: const Color(0xFF607D8B),
              onTap: () => widget.onPickFile(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Actions rapides ─────────────────────────────────────────────────
        _sectionHeader(context, 'Actions rapides', Icons.bolt_outlined, Colors.deepOrange),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
          children: _quickActions.asMap().entries.map((e) => _ActionCard(
            icon: e.value.icon,
            label: e.value.label,
            color: e.value.color,
            onTap: () => _openQuickAction(context, e.key),
          )).toList(),
        ),
        const SizedBox(height: 16),

        // ── Favoris ─────────────────────────────────────────────────────────
        if (favorites.isNotEmpty) ...[
          _sectionHeader(context, 'Favoris', Icons.star, Colors.amber),
          ...favorites.map((f) => _fileCard(context, f)),
          const SizedBox(height: 8),
        ],

        // ── Récents ─────────────────────────────────────────────────────────
        _sectionHeader(context, 'Récemment ouverts', Icons.history, Colors.grey),
        if (widget.recentFiles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.7)),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucun PDF ouvert pour l\'instant',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Utilisez les raccourcis ci-dessus pour parcourir\n'
                      'vos dossiers ou rechercher tous vos PDFs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: widget.onPickFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Choisir un PDF'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...recents.map((f) => _fileCard(context, f)),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _fileCard(BuildContext context, RecentFile file) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Stack(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf,
                color: Color(0xFFC62828), size: 24),
          ),
          if (file.isFavorite)
            const Positioned(right: 0, top: 0,
                child: Icon(Icons.star, size: 12, color: Colors.amber)),
        ]),
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13)),
        subtitle: Text('${widget.formatDate(file.lastOpened)} · ${file.formattedSize}',
            style: const TextStyle(fontSize: 11)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'favorite') widget.onToggleFavorite(file);
            if (v == 'share')    widget.onShare(file);
            if (v == 'remove')   widget.onRemove(file);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'favorite', child: ListTile(
                leading: Icon(file.isFavorite ? Icons.star_border : Icons.star, color: Colors.amber),
                title: Text(file.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'))),
            const PopupMenuItem(value: 'share', child: ListTile(
                leading: Icon(Icons.share), title: Text('Partager'))),
            const PopupMenuItem(value: 'remove', child: ListTile(
                leading: Icon(Icons.delete_outline), title: Text('Retirer'))),
          ],
        ),
        onTap: () => widget.onOpen(file.path),
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _StorageBar extends StatelessWidget {
  final int freeBytes;
  final int totalBytes;
  final String Function(int) formatBytes;

  const _StorageBar({
    required this.freeBytes,
    required this.totalBytes,
    required this.formatBytes,
  });

  @override
  Widget build(BuildContext context) {
    final usedBytes = totalBytes - freeBytes;
    final ratio = totalBytes > 0 ? usedBytes / totalBytes : 0.0;
    final color = ratio > 0.9
        ? Colors.red
        : ratio > 0.75
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(children: [
          Row(children: [
            Text(formatBytes(usedBytes),
                style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15)),
            Text(' utilisés sur ${formatBytes(totalBytes)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const Spacer(),
            Text('${formatBytes(freeBytes)} libres',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.toDouble(),
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final RecentFile file;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _ResumeCard({
    required this.file,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFC62828); // Material Red 700 — identité PDF
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.picture_as_pdf, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${formatDate(file.lastOpened)} · ${file.formattedSize}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            )),
            Icon(Icons.play_circle_fill,
                color: color.withValues(alpha: 0.8), size: 28),
          ]),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tools tab ─────────────────────────────────────────────────────────────────

class _ToolsTab extends StatelessWidget {
  final VoidCallback onPickFile;

  const _ToolsTab({required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    final tools = [
      (
        icon: Icons.merge_type,
        label: 'Fusionner',
        subtitle: 'Combiner plusieurs PDFs',
        color: Colors.blue,
        screen: const MergeScreen(),
      ),
      (
        icon: Icons.call_split,
        label: 'Diviser',
        subtitle: 'Extraire des pages',
        color: Colors.green,
        screen: const SplitScreen(),
      ),
      (
        icon: Icons.lock_outline,
        label: 'Protéger',
        subtitle: 'Ajouter un mot de passe',
        color: Colors.red,
        screen: const ProtectScreen(),
      ),
      (
        icon: Icons.rotate_right,
        label: 'Rotation',
        subtitle: 'Tourner les pages',
        color: Colors.teal,
        screen: const RotateScreen(),
      ),
      (
        icon: Icons.water_drop_outlined,
        label: 'Filigrane',
        subtitle: 'Ajouter un filigrane',
        color: Colors.indigo,
        screen: const WatermarkScreen(),
      ),
      (
        icon: Icons.create_outlined,
        label: 'Créer PDF',
        subtitle: 'Nouveau document',
        color: Colors.purple,
        screen: const CreatePdfScreen(),
      ),
      (
        icon: Icons.compress,
        label: 'Compresser',
        subtitle: 'Réduire la taille',
        color: Colors.orange,
        screen: const CompressScreen(),
      ),
      (
        icon: Icons.draw_outlined,
        label: 'Signature',
        subtitle: 'Insérer une signature',
        color: Colors.pink,
        screen: const SignatureScreen(),
      ),
      (
        icon: Icons.assignment_outlined,
        label: 'Formulaires',
        subtitle: 'Remplir un formulaire',
        color: Colors.cyan,
        screen: const FormFillScreen(),
      ),
      (
        icon: Icons.document_scanner_outlined,
        label: 'OCR',
        subtitle: 'Extraire le texte',
        color: Colors.deepOrange,
        screen: const OcrScreen(),
      ),
      (
        icon: Icons.delete_sweep_outlined,
        label: 'Supprimer',
        subtitle: 'Retirer des pages',
        color: Colors.red,
        screen: const DeletePagesScreen(),
      ),
      (
        icon: Icons.swap_vert_circle_outlined,
        label: 'Réorganiser',
        subtitle: 'Changer l\'ordre des pages',
        color: Colors.amber,
        screen: const ReorderPagesScreen(),
      ),
      (
        icon: Icons.image_outlined,
        label: 'Exporter images',
        subtitle: 'Pages en PNG / JPEG',
        color: Colors.lightGreen,
        screen: const ExportImagesScreen(),
      ),
      (
        icon: Icons.info_outline,
        label: 'Métadonnées',
        subtitle: 'Titre, auteur, sujet',
        color: Colors.blueGrey,
        screen: const MetadataScreen(),
      ),
      (
        icon: Icons.format_list_numbered,
        label: 'Numéroter',
        subtitle: 'Ajouter des numéros',
        color: Colors.cyan,
        screen: const PageNumbersScreen(),
      ),
      (
        icon: Icons.approval_outlined,
        label: 'Tampon',
        subtitle: 'CONFIDENTIEL, APPROUVÉ…',
        color: Colors.red,
        screen: const StampScreen(),
      ),
      (
        icon: Icons.vertical_split_outlined,
        label: 'En-tête / Pied',
        subtitle: 'Texte fixe sur les pages',
        color: Colors.indigo,
        screen: const HeaderFooterScreen(),
      ),
      (
        icon: Icons.image_search,
        label: 'Extraire images',
        subtitle: 'Images intégrées au PDF',
        color: Colors.teal,
        screen: const ExtractImagesScreen(),
      ),
      (
        icon: Icons.compare_outlined,
        label: 'Comparer',
        subtitle: 'Deux PDFs côte à côte',
        color: Colors.deepPurple,
        screen: const CompareScreen(),
      ),
      (
        icon: Icons.add_photo_alternate_outlined,
        label: 'Images → PDF',
        subtitle: 'JPG/PNG vers un PDF',
        color: Colors.lightGreen,
        screen: const ImagesToPdfScreen(),
      ),
      (
        icon: Icons.lock_open_outlined,
        label: 'Déchiffrer',
        subtitle: 'Retirer le mot de passe',
        color: Colors.teal,
        screen: const DecryptScreen(),
      ),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) {
        final tool = tools[i];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => tool.screen),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tool.icon, size: 36, color: tool.color),
                  const SizedBox(height: 8),
                  Text(tool.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(tool.subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Cloud tab ─────────────────────────────────────────────────────────────────

class _CloudTab extends StatelessWidget {
  const _CloudTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Stockage cloud',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Connectez vos comptes pour accéder à vos PDFs depuis le cloud.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        const SizedBox(height: 16),
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.add_to_drive, color: Colors.blue, size: 32),
            title: const Text('Google Drive'),
            subtitle: const Text('Upload, téléchargement, partage'),
            trailing: FilledButton.tonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoogleDriveScreen()),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.cloud_queue, color: Color(0xFF0061FE), size: 32),
            title: const Text('Dropbox'),
            subtitle: const Text('Bientôt disponible'),
            trailing: FilledButton.tonal(
              onPressed: null,
              child: const Text('Bientôt'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Search delegate ───────────────────────────────────────────────────────────

class _PdfSearchDelegate extends SearchDelegate<void> {
  final List<RecentFile> files;
  final ValueChanged<String> onOpen;

  _PdfSearchDelegate(this.files, this.onOpen);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = query.isEmpty
        ? files
        : files
            .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
            .toList();

    if (results.isEmpty) {
      return const Center(child: Text('Aucun résultat'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFC62828)),
        title: Text(results[i].name),
        onTap: () {
          close(context, null);
          onOpen(results[i].path);
        },
      ),
    );
  }
}

/// Affiche les résultats du scan global "Trouver tous mes PDFs". Liste plate
/// avec recherche, triée par date modifiée DESC. Tap pour ouvrir.
class _AllPdfsScreen extends StatefulWidget {
  final List<File> files;
  final void Function(String path) onPick;
  const _AllPdfsScreen({required this.files, required this.onPick});

  @override
  State<_AllPdfsScreen> createState() => _AllPdfsScreenState();
}

class _AllPdfsScreenState extends State<_AllPdfsScreen> {
  String _search = '';

  String _formatSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.files
        : widget.files
            .where((f) => f.path
                .split('/')
                .last
                .toLowerCase()
                .contains(_search.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tous mes PDFs', style: TextStyle(fontSize: 16)),
            Text('${widget.files.length} trouvés sur le téléphone',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher…',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Aucun PDF correspondant',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final f = filtered[i];
                      final stat = f.statSync();
                      final name = f.path.split('/').last;
                      final dirName =
                          f.parent.path.split('/').last;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        child: ListTile(
                          dense: true,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC62828).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.picture_as_pdf,
                                color: Color(0xFFC62828), size: 22),
                          ),
                          title: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            '$dirName · ${_formatSize(stat.size)}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onPick(f.path);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
