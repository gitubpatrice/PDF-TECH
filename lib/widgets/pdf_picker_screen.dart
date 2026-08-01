import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:files_tech_core/files_tech_core.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/folder_browser_screen.dart';
import '../screens/pdf_folder_screen.dart';
import '../utils/snack_utils.dart';
import '../utils/storage_permission_service.dart';

/// Picker PDF custom avec deux onglets :
/// - **Récents** : liste des PDFs récemment ouverts
/// - **Parcourir** : actions pour ouvrir le picker SAF fichier ou dossier.
///
/// P0 v1.13.2 — migration MANAGE_EXTERNAL_STORAGE → SAF : le picker ne scanne
/// plus les chemins absolus `/storage/emulated/0/…`. Il utilise file_picker
/// (Storage Access Framework) qui retourne des paths lisibles par l'app.
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
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PdfPickerScreen(title: title ?? 'Choisir un PDF', multi: false),
      ),
    );
  }

  static Future<List<String>?> pickMany(BuildContext context, {String? title}) {
    return Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PdfPickerScreen(title: title ?? 'Choisir des PDFs', multi: true),
      ),
    );
  }
}

class _PdfPickerScreenState extends State<PdfPickerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _recentService = RecentFilesService();
  List<RecentFile> _recents = [];
  bool _loading = true;
  final List<String> _selected = [];

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
    // Filtre : on ne garde que les fichiers PDF. Sous SAF, un path public peut
    // ne plus être lisible sans permission persistante ; on catch l'erreur de
    // exists() et on élimine silencieusement l'entrée invalide.
    final checks = await Future.wait(
      r.map((f) async {
        try {
          return f.name.toLowerCase().endsWith('.pdf') ? f : null;
        } catch (_) {
          return null;
        }
      }),
    );
    final existing = checks.whereType<RecentFile>().toList();
    if (!mounted) return;
    setState(() {
      _recents = existing;
      _loading = false;
    });
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

  /// Ouvre le picker de PDFs. Avec [MANAGE_EXTERNAL_STORAGE], on scanne
  /// directement `/sdcard/Download` dans notre propre UI (pas de dépendance au
  /// DocumentsUI potentiellement bugué de l’émulateur). Sinon on fallback sur
  /// `file_picker` SAF.
  Future<void> _pickFiles() async {
    if (kDebugMode) {
      debugPrint(
        '[PdfPickerScreen] _pickFiles() invoked (multi=${widget.multi})',
      );
    }

    final hasStorage = await StoragePermissionService.requestWithDialog(
      context,
    );
    if (kDebugMode) {
      debugPrint('[PdfPickerScreen] storage permission granted: $hasStorage');
    }
    if (!mounted) return;
    if (!hasStorage) {
      // L’utilisateur refuse la permission globale : on propose le picker SAF.
      if (kDebugMode) {
        debugPrint('[PdfPickerScreen] falling back to file_picker SAF');
      }
      await _pickWithFilePicker();
      return;
    }

    // Scan direct de Download quand la permission globale est accordée.
    final downloadDir = await _downloadDirectory();
    if (kDebugMode) {
      debugPrint('[PdfPickerScreen] download dir: $downloadDir');
    }
    if (!mounted) return;
    if (downloadDir == null) {
      showErrorSnack(context, 'Impossible d’accéder au dossier Download');
      return;
    }
    if (kDebugMode) {
      debugPrint('[PdfPickerScreen] opening PdfFolderScreen for Download');
    }
    if (!mounted) return;
    final picked = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PdfFolderScreen(path: downloadDir, title: 'Download'),
      ),
    );
    if (kDebugMode) {
      debugPrint('[PdfPickerScreen] PdfFolderScreen returned: $picked');
    }
    if (!mounted) return;
    if (picked != null && picked.toLowerCase().endsWith('.pdf')) {
      if (widget.multi) {
        setState(() {
          if (!_selected.contains(picked)) _selected.add(picked);
        });
      } else {
        Navigator.pop(context, picked);
      }
    }
  }

  /// Picker SAF fallback (sans permission globale).
  Future<void> _pickWithFilePicker() async {
    List<String> paths = [];
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: widget.multi,
        dialogTitle: widget.multi
            ? 'Sélectionner des PDFs'
            : 'Sélectionner un PDF',
      );
      if (result != null && result.files.isNotEmpty) {
        paths = result.files
            .map((f) => f.path)
            .where((p) => p != null)
            .cast<String>()
            .where((p) => p.toLowerCase().endsWith('.pdf'))
            .toList();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PdfPickerScreen] file_picker error: $e\n$st');
      }
    }

    if (!mounted) return;
    if (paths.isEmpty) return;

    if (widget.multi) {
      setState(() {
        for (final p in paths) {
          if (!_selected.contains(p)) _selected.add(p);
        }
      });
    } else {
      Navigator.pop(context, paths.first);
    }
  }

  /// Ouvre l’explorateur de dossiers intégré puis navigue dans le dossier
  /// choisi pour y sélectionner un PDF.
  Future<void> _pickAndBrowseFolder() async {
    if (kDebugMode) {
      debugPrint('[PdfPickerScreen] _pickAndBrowseFolder() invoked');
    }

    final hasStorage = await StoragePermissionService.requestWithDialog(
      context,
    );
    if (kDebugMode) {
      debugPrint('[PdfPickerScreen] storage permission granted: $hasStorage');
    }
    if (!mounted) return;
    if (!hasStorage) {
      // L’utilisateur refuse la permission globale : on propose le picker SAF.
      await _pickFolderWithSaf();
      return;
    }

    final rootDir = await _externalRootDirectory();
    if (!mounted) return;
    if (rootDir == null) {
      showErrorSnack(context, 'Impossible d’accéder au stockage');
      return;
    }

    final picked = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FolderBrowserScreen(
          path: rootDir,
          title: 'Stockage',
          pickFile: true,
        ),
      ),
    );
    if (kDebugMode) {
      debugPrint('[PdfPickerScreen] folder browser returned: $picked');
    }
    if (!mounted) return;
    if (picked != null && picked.toLowerCase().endsWith('.pdf')) {
      if (widget.multi) {
        setState(() {
          if (!_selected.contains(picked)) _selected.add(picked);
        });
      } else {
        Navigator.pop(context, picked);
      }
    }
  }

  /// Picker de dossier SAF fallback (sans permission globale).
  Future<void> _pickFolderWithSaf() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Sélectionner un dossier',
    );
    if (dir == null || !mounted) return;
    final label = PathUtils.fileName(dir);
    final picked = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PdfFolderScreen(
          path: dir,
          title: label.isEmpty ? 'Dossier' : label,
        ),
      ),
    );
    if (!mounted) return;
    if (picked != null && picked.toLowerCase().endsWith('.pdf')) {
      if (widget.multi) {
        setState(() {
          if (!_selected.contains(picked)) _selected.add(picked);
        });
      } else {
        Navigator.pop(context, picked);
      }
    }
  }

  /// Retourne la racine du stockage externe (`/sdcard` ou équivalent).
  Future<String?> _externalRootDirectory() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return null;
      final root = Directory(extDir.parent.parent.parent.parent.path);
      if (await root.exists()) return root.path;
      final fallback = Directory('/sdcard');
      if (await fallback.exists()) return fallback.path;
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PdfPickerScreen] _externalRootDirectory error: $e');
      }
      return null;
    }
  }

  /// Retourne le chemin de `/sdcard/Download` ou équivalent externe.
  Future<String?> _downloadDirectory() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return null;
      final download = Directory(
        '${extDir.parent.parent.parent.parent.path}/Download',
      );
      if (await download.exists()) return download.path;
      // Fallback : /sdcard/Download
      final fallback = Directory('/sdcard/Download');
      if (await fallback.exists()) return fallback.path;
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PdfPickerScreen] _downloadDirectory error: $e');
      }
      return null;
    }
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
              Icon(
                Icons.menu_book_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'Aucun PDF récent',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
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
          leading: const Icon(
            Icons.picture_as_pdf,
            color: Colors.red,
            size: 20,
          ),
          title: Text(
            f.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            f.formattedSize,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          trailing: widget.multi
              ? Checkbox(
                  value: selected,
                  onChanged: (_) => _toggleSelect(f.path),
                )
              : const Icon(Icons.chevron_right),
          selected: selected,
          onTap: () => widget.multi ? _toggleSelect(f.path) : _pick(f.path),
        );
      },
    );
  }

  Widget _buildBrowse() {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                Icons.picture_as_pdf_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(
                'Choisir un PDF',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                widget.multi
                    ? 'Ouvrir le gestionnaire de fichiers et sélectionner un ou plusieurs PDFs'
                    : 'Ouvrir le gestionnaire de fichiers et sélectionner un fichier PDF',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickFiles,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.folder_open,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(
                'Choisir un dossier',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Parcourir un dossier et ses sous-dossiers',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickAndBrowseFolder,
            ),
          ),
          if (widget.multi && _selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.30),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${_selected.length} fichier${_selected.length > 1 ? 's' : ''} sélectionné${_selected.length > 1 ? 's' : ''} — appuyez sur Valider en bas à droite',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
