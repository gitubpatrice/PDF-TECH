import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/recent_file.dart';
import '../services/recent_files_service.dart';
import '../screens/pdf_folder_screen.dart';

/// Picker PDF custom avec deux onglets :
/// - **Récents** : liste des PDFs récemment ouverts
/// - **Parcourir** : bouton "Parcourir un autre dossier" en tête, grille de
///   raccourcis colorés (Téléchargements, Documents, PDF Tech, WhatsApp),
///   puis grille dynamique de **tous les dossiers** du stockage interne avec
///   couleurs/icônes auto.
///
/// Mode multi-sélection optionnel pour Fusionner / Images→PDF.
///
/// Retourne via Navigator.pop :
/// - `String` (path) si mode mono
/// - `List<String>` (paths) si mode multi
class PdfPickerScreen extends StatefulWidget {
  final String title;
  final bool multi;
  const PdfPickerScreen({
    super.key,
    this.title = 'Choisir un PDF',
    this.multi = false,
  });

  @override
  State<PdfPickerScreen> createState() => _PdfPickerScreenState();

  static Future<String?> pickOne(BuildContext context, {String? title}) {
    return Navigator.push<String>(context, MaterialPageRoute(
      builder: (_) => PdfPickerScreen(title: title ?? 'Choisir un PDF', multi: false),
    ));
  }

  static Future<List<String>?> pickMany(BuildContext context, {String? title}) {
    return Navigator.push<List<String>>(context, MaterialPageRoute(
      builder: (_) => PdfPickerScreen(title: title ?? 'Choisir des PDFs', multi: true),
    ));
  }
}

class _Shortcut {
  final IconData icon;
  final String label;
  final String path;
  final Color color;
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.path,
    required this.color,
  });
}

class _PdfPickerScreenState extends State<PdfPickerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _recentService = RecentFilesService();
  List<RecentFile> _recents = [];
  List<Directory> _allFolders = [];
  bool _loading = true;
  final List<String> _selected = [];

  /// Raccourcis curés : dossiers les plus susceptibles de contenir des PDFs.
  static const _shortcuts = [
    _Shortcut(
      icon: Icons.download_outlined,
      label: 'Téléchargements',
      path: '/storage/emulated/0/Download',
      color: Color(0xFF43A047),
    ),
    _Shortcut(
      icon: Icons.description_outlined,
      label: 'Documents',
      path: '/storage/emulated/0/Documents',
      color: Color(0xFF1976D2),
    ),
    _Shortcut(
      icon: Icons.folder_special_outlined,
      label: 'PDF Tech',
      path: '/storage/emulated/0/Documents/PDF Tech',
      color: Color(0xFFFF7043),
    ),
    _Shortcut(
      icon: Icons.chat_outlined,
      label: 'WhatsApp',
      path: '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
      color: Color(0xFF25D366),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
    _loadAllFolders();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await _recentService.load();
    if (!mounted) return;
    // Filtre cohérent avec RFT picker : on ne garde que les fichiers qui
    // existent ET dont l'extension est .pdf (un picker PDF doit lister des
    // PDFs même si RecentFilesService stockait par accident d'autres types).
    final checks = await Future.wait(
        r.map((f) async => (await File(f.path).exists()) ? f : null));
    final existing = checks
        .whereType<RecentFile>()
        .where((f) => f.name.toLowerCase().endsWith('.pdf'))
        .toList();
    if (!mounted) return;
    setState(() { _recents = existing; _loading = false; });
  }

  /// Liste tous les dossiers de premier niveau du stockage interne, exclus :
  /// dossiers déjà raccourcis (anti-doublon), Android/ (data app), cachés.
  Future<void> _loadAllFolders() async {
    try {
      final root = Directory('/storage/emulated/0');
      if (!await root.exists()) return;
      final shortcutPaths = _shortcuts.map((s) => s.path).toSet();
      final entries = await root.list(followLinks: false).toList();
      final folders = entries
          .whereType<Directory>()
          .where((d) {
            final name = d.path.split(RegExp(r'[/\\]')).last;
            if (name.startsWith('.')) return false;
            if (name == 'Android') return false;
            if (shortcutPaths.contains(d.path)) return false;
            return true;
          })
          .toList()
        ..sort((a, b) => a.path.split(RegExp(r'[/\\]')).last.toLowerCase()
            .compareTo(b.path.split(RegExp(r'[/\\]')).last.toLowerCase()));
      if (!mounted) return;
      setState(() => _allFolders = folders);
    } catch (_) {/* perm refusée — silent */}
  }

  /// Icône smart selon le nom : reconnaît les patterns fréquents.
  IconData _smartIconFor(String name) {
    final n = name.toLowerCase();
    if (RegExp(r'photo|image|picture|dcim|camera').hasMatch(n)) {
      return Icons.photo_camera_outlined;
    }
    if (RegExp(r'vid[ée]o|movie|film|cin[ée]ma').hasMatch(n)) {
      return Icons.videocam_outlined;
    }
    if (RegExp(r'music|audio|sound|son|chanson|podcast').hasMatch(n)) {
      return Icons.music_note_outlined;
    }
    if (RegExp(r'doc|text|note|word|excel|pdf').hasMatch(n)) {
      return Icons.description_outlined;
    }
    if (RegExp(r'download|t[ée]l[ée]chargement').hasMatch(n)) {
      return Icons.download_outlined;
    }
    if (RegExp(r'backup|sauvegarde|archive').hasMatch(n)) {
      return Icons.backup_outlined;
    }
    if (RegExp(r'screenshot|capture').hasMatch(n)) {
      return Icons.screenshot_outlined;
    }
    if (RegExp(r'book|livre|epub|read|lecture').hasMatch(n)) {
      return Icons.menu_book_outlined;
    }
    if (RegExp(r'whatsapp|telegram|signal|messenger|chat').hasMatch(n)) {
      return Icons.chat_outlined;
    }
    if (RegExp(r'zip|tar|rar|7z').hasMatch(n)) {
      return Icons.folder_zip_outlined;
    }
    return Icons.folder_outlined;
  }

  /// Couleur déterministe via hash du nom — palette 12 couleurs Material 600.
  static const _autoPalette = <Color>[
    Color(0xFF1976D2), Color(0xFF43A047), Color(0xFFE53935), Color(0xFFFF7043),
    Color(0xFF8E24AA), Color(0xFFE91E63), Color(0xFF00897B), Color(0xFF3949AB),
    Color(0xFF6D4C41), Color(0xFF455A64), Color(0xFF7CB342), Color(0xFF039BE5),
  ];

  Color _autoColorFor(String name) {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return _autoPalette[hash % _autoPalette.length];
  }

  void _pick(String path) {
    if (widget.multi) {
      setState(() {
        if (!_selected.contains(path)) _selected.add(path);
      });
    } else {
      Navigator.pop(context, path);
    }
  }

  void _toggleSelect(String path) {
    setState(() {
      _selected.contains(path) ? _selected.remove(path) : _selected.add(path);
    });
  }

  Future<void> _browseAnyFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || !mounted) return;
    final label = dir.split(RegExp(r'[/\\]')).last;
    await _browseFolder(dir, label.isEmpty ? 'Dossier' : label);
  }

  Future<void> _browseFolder(String path, String label) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      // Auto-création pour le dossier PDF Tech (notre dossier app)
      if (label == 'PDF Tech') {
        try {
          await dir.create(recursive: true);
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dossier "$label" introuvable')));
          return;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dossier "$label" introuvable')));
        return;
      }
    }
    if (!mounted) return;
    final picked = await Navigator.push<String>(context, MaterialPageRoute(
      builder: (_) => PdfFolderScreen(
        path: path, title: label,
        onPick: (p) => Navigator.pop(context, p),
      ),
    ));
    if (picked != null && mounted) _pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Récents', icon: Icon(Icons.history)),
            Tab(text: 'Parcourir', icon: Icon(Icons.folder_outlined)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_buildRecents(), _buildBrowse()],
            ),
      floatingActionButton: widget.multi && _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context, _selected),
              icon: const Icon(Icons.check),
              label: Text('Valider (${_selected.length})'),
            )
          : null,
    );
  }

  Widget _buildRecents() {
    if (_recents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('Aucun PDF récent',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Ouvrez un PDF depuis l\'onglet Parcourir pour le voir ici.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _recents.length,
      itemBuilder: (_, i) {
        final f = _recents[i];
        final selected = _selected.contains(f.path);
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text(f.name, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
          subtitle: Text(f.formattedSize,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: widget.multi
              ? Checkbox(
                  value: selected,
                  onChanged: (_) => _toggleSelect(f.path))
              : const Icon(Icons.chevron_right),
          selected: selected,
          onTap: () => widget.multi ? _toggleSelect(f.path) : _pick(f.path),
        );
      },
    );
  }

  Widget _buildBrowse() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            'Raccourcis',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Grille raccourcis curés (Téléchargements, Documents, PDF Tech, WhatsApp)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 2.7,
          children: _shortcuts.map((s) => _ShortcutCard(
            icon: s.icon, label: s.label, color: s.color,
            onTap: () => _browseFolder(s.path, s.label),
          )).toList(),
        ),

        if (_allFolders.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              'Tous les dossiers',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          // Grille dynamique de tous les dossiers du stockage interne
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 2.7,
            children: _allFolders.map((d) {
              final name = d.path.split(RegExp(r'[/\\]')).last;
              return _ShortcutCard(
                icon: _smartIconFor(name),
                label: name,
                color: _autoColorFor(name),
                onTap: () => _browseFolder(d.path, name),
              );
            }).toList(),
          ),
        ],

        if (widget.multi && _selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.30),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  '${_selected.length} fichier${_selected.length > 1 ? 's' : ''} sélectionné${_selected.length > 1 ? 's' : ''} — appuyez sur Valider en bas à droite',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],

        // "Parcourir un autre dossier" en bas avec marge réduite — toujours
        // visible sans avoir à scroller à fond (padding bottom du ListView = 8)
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.folder_open,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Parcourir un autre dossier',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'Sélecteur (sous-dossiers, SD, etc.)',
                style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _browseAnyFolder,
          ),
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ShortcutCard({
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
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2),
            ),
          ]),
        ),
      ),
    );
  }
}
