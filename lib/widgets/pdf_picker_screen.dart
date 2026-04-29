import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/recent_file.dart';
import '../services/recent_files_service.dart';
import '../screens/pdf_folder_screen.dart';

/// Picker PDF custom avec deux onglets :
/// - **Récents** : liste des PDFs récemment ouverts (depuis RecentFilesService)
/// - **Parcourir** : grille d'icônes vers Téléchargements / Documents /
///   PDF Tech / WhatsApp + bouton "Choisir avec le picker système"
///
/// Bien plus utile pour l'utilisateur que le SAF Android brut, qui montre
/// "Récents" du système (pas spécifique aux PDFs) et oblige à fouiller.
///
/// Mode multi-sélection optionnel pour les outils Fusionner / Images→PDF.
///
/// Retourne via Navigator.pop :
/// - `String` (un path) si mode mono,
/// - `List<String>` (paths) si mode multi.
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

  /// Helper : ouvre le picker en mode mono et retourne le path (ou null).
  /// À utiliser dans les outils qui prennent UN seul PDF.
  static Future<String?> pickOne(BuildContext context, {String? title}) {
    return Navigator.push<String>(context, MaterialPageRoute(
      builder: (_) => PdfPickerScreen(title: title ?? 'Choisir un PDF', multi: false),
    ));
  }

  /// Helper : mode multi, retourne la liste des paths (ou null).
  static Future<List<String>?> pickMany(BuildContext context, {String? title}) {
    return Navigator.push<List<String>>(context, MaterialPageRoute(
      builder: (_) => PdfPickerScreen(title: title ?? 'Choisir des PDFs', multi: true),
    ));
  }
}

class _PdfPickerScreenState extends State<PdfPickerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _recentService = RecentFilesService();
  List<RecentFile> _recents = [];
  bool _loading = true;
  final List<String> _selected = [];

  static const _folders = [
    (icon: Icons.download_outlined,    label: 'Téléchargements',
        path: '/storage/emulated/0/Download',                color: Color(0xFF43A047)),
    (icon: Icons.description_outlined, label: 'Documents',
        path: '/storage/emulated/0/Documents',               color: Color(0xFF1976D2)),
    (icon: Icons.folder_special_outlined, label: 'PDF Tech',
        path: '/storage/emulated/0/Documents/PDF Tech',     color: Color(0xFFFF7043)),
    (icon: Icons.chat_outlined,        label: 'WhatsApp',
        path: '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
        color: Color(0xFF25D366)),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await _recentService.load();
    if (!mounted) return;
    // Filtre async : ne garde que les fichiers qui existent encore.
    // existsSync sur N fichiers stockage lent jankerait l'UI au build du tab.
    final checks = await Future.wait(
        r.map((f) async => (await File(f.path).exists()) ? f : null));
    final existing = checks.whereType<RecentFile>().toList();
    if (!mounted) return;
    setState(() { _recents = existing; _loading = false; });
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
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  Future<void> _pickWithSystem() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: widget.multi,
    );
    if (res == null) return;
    if (!mounted) return;
    if (widget.multi) {
      setState(() {
        for (final f in res.files) {
          if (f.path != null && !_selected.contains(f.path)) {
            _selected.add(f.path!);
          }
        }
      });
    } else {
      // res.files.single peut lever StateError si la liste est vide ; firstOrNull
      // est plus défensif sans changer le comportement nominal.
      final path = res.files.isEmpty ? null : res.files.first.path;
      if (path != null) Navigator.pop(context, path);
    }
  }

  /// Ouvre le sélecteur de dossier système Android (SAF). L'utilisateur peut
  /// naviguer dans n'importe quel dossier de son téléphone et le picker
  /// retourne le path. On l'ouvre ensuite dans PdfFolderScreen filtré .pdf.
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
                'Ouvrez un PDF depuis l\'onglet Parcourir pour le voir apparaître ici.',
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
      padding: const EdgeInsets.all(12),
      children: [
        // Grille d'icônes accès direct
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: _folders.map((f) => Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _browseFolder(f.path, f.label),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: f.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(f.icon, color: f.color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 16),
        // Choisir un dossier dans tout le téléphone
        Card(
          child: ListTile(
            leading: Icon(Icons.folder_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Parcourir un autre dossier',
                style: TextStyle(fontSize: 13)),
            subtitle: const Text(
                'Choisir n\'importe quel dossier du téléphone',
                style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _browseAnyFolder,
          ),
        ),
        // Bouton picker système
        Card(
          child: ListTile(
            leading: Icon(Icons.folder_open,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Choisir avec le picker système',
                style: TextStyle(fontSize: 13)),
            subtitle: const Text(
                'Sélecteur Android (Drive, Téléchargements…)',
                style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickWithSystem,
          ),
        ),
        if (widget.multi && _selected.isNotEmpty) ...[
          const SizedBox(height: 16),
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
      ],
    );
  }
}
