import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/recent_file.dart';
import '../services/recent_files_service.dart';
import '../services/share_service.dart';
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
import 'cloud/google_drive_screen.dart';

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
  }

  Future<void> _loadRecents() async {
    final files = await _recentFilesService.load();
    if (mounted) setState(() { _recentFiles = files; _isLoading = false; });
  }

  Future<void> _pickAndOpen() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    await _openPdf(result.files.single.path!);
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
        title: const Text('PDF Studio'),
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
            onRemove: _removeRecent,
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

class _HomeTab extends StatelessWidget {
  final List<RecentFile> recentFiles;
  final bool isLoading;
  final ValueChanged<String> onOpen;
  final ValueChanged<RecentFile> onRemove;
  final ValueChanged<RecentFile> onShare;
  final String Function(DateTime) formatDate;

  const _HomeTab({
    required this.recentFiles,
    required this.isLoading,
    required this.onOpen,
    required this.onRemove,
    required this.onShare,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recentFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf,
                size: 96,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
            const SizedBox(height: 20),
            Text('Aucun fichier récent',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur "Ouvrir un PDF" pour commencer',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: recentFiles.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('Récemment ouverts',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey)),
          );
        }
        final file = recentFiles[index - 1];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.picture_as_pdf,
                  color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(file.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${formatDate(file.lastOpened)} · ${file.formattedSize}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'share') onShare(file);
                if (v == 'remove') onRemove(file);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Partager'))),
                PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Retirer'))),
              ],
            ),
            onTap: () => onOpen(file.path),
          ),
        );
      },
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
        leading: const Icon(Icons.picture_as_pdf),
        title: Text(results[i].name),
        onTap: () {
          close(context, null);
          onOpen(results[i].path);
        },
      ),
    );
  }
}
