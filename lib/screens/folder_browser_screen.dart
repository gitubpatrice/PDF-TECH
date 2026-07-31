import 'dart:io';
import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

/// Explorateur de dossiers intégré. Nécessite [MANAGE_EXTERNAL_STORAGE]
/// (ou un path déjà accessible) pour parcourir le stockage externe.
///
/// Retourne via `Navigator.pop` :
/// - `String` (path du fichier PDF choisi) si [pickFile] est true
/// - `String` (path du dossier choisi) si [pickFile] est false
class FolderBrowserScreen extends StatefulWidget {
  final String path;
  final String title;
  final bool pickFile;

  const FolderBrowserScreen({
    super.key,
    required this.path,
    required this.title,
    this.pickFile = false,
  });

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  List<FileSystemEntity> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dir = Directory(widget.path);
      if (!await dir.exists()) {
        if (!mounted) return;
        setState(() {
          _error = 'Dossier introuvable';
          _loading = false;
        });
        return;
      }
      final entries = await dir
          .list(followLinks: false)
          .where((e) => e is Directory || _isPdf(e))
          .toList();
      entries.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir && !bDir) return -1;
        if (!aDir && bDir) return 1;
        return PathUtils.fileName(
          a.path,
        ).toLowerCase().compareTo(PathUtils.fileName(b.path).toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de lire le dossier';
        _loading = false;
      });
    }
  }

  bool _isPdf(FileSystemEntity e) =>
      e is File && e.path.toLowerCase().endsWith('.pdf');

  Future<void> _enter(String path) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FolderBrowserScreen(
          path: path,
          title: PathUtils.fileName(path),
          pickFile: widget.pickFile,
        ),
      ),
    );
    if (result != null && mounted) Navigator.pop(context, result);
  }

  void _selectFolder() => Navigator.pop(context, widget.path);

  void _selectFile(String path) => Navigator.pop(context, path);

  IconData _folderIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('download')) return Icons.download_rounded;
    if (lower.contains('document')) return Icons.description_rounded;
    if (lower.contains('music') || lower.contains('audio'))
      return Icons.music_note_rounded;
    if (lower.contains('video') || lower.contains('movie'))
      return Icons.movie_rounded;
    if (lower.contains('image') ||
        lower.contains('picture') ||
        lower.contains('photo'))
      return Icons.photo_rounded;
    if (lower.contains('dcim') || lower.contains('camera'))
      return Icons.camera_alt_rounded;
    if (lower.contains('whatsapp')) return Icons.chat_rounded;
    if (lower.contains('telegram')) return Icons.telegram_rounded;
    if (lower.contains('android')) return Icons.android_rounded;
    if (lower.contains('sync') || lower.contains('cloud'))
      return Icons.cloud_rounded;
    return Icons.folder_rounded;
  }

  Color _folderColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('download')) return const Color(0xFF43A047);
    if (lower.contains('document')) return const Color(0xFF1565C0);
    if (lower.contains('music') || lower.contains('audio'))
      return const Color(0xFF8E24AA);
    if (lower.contains('video') || lower.contains('movie'))
      return const Color(0xFFE53935);
    if (lower.contains('image') ||
        lower.contains('picture') ||
        lower.contains('photo'))
      return const Color(0xFFFB8C00);
    if (lower.contains('dcim') || lower.contains('camera'))
      return const Color(0xFF00897B);
    if (lower.contains('whatsapp')) return const Color(0xFF25D366);
    if (lower.contains('telegram')) return const Color(0xFF29B6F6);
    if (lower.contains('android')) return const Color(0xFF3DDC84);
    if (lower.contains('sync') || lower.contains('cloud'))
      return const Color(0xFF039BE5);
    return const Color(0xFFFFB300);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16)),
            if (!_loading && _error == null)
              Text(
                '${_entries.length} élément${_entries.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
          if (!widget.pickFile)
            TextButton.icon(
              onPressed: _selectFolder,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Utiliser ce dossier'),
              style: TextButton.styleFrom(foregroundColor: cs.onPrimary),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.grey)),
            )
          : _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 64,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun dossier ou PDF ici',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : GridView.count(
              padding: const EdgeInsets.all(8),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.2,
              children: _entries.map((e) {
                final isDir = e is Directory;
                final name = PathUtils.fileName(e.path);
                final folderColor = _folderColor(name);
                return GestureDetector(
                  onTap: () => isDir
                      ? _enter(e.path)
                      : widget.pickFile
                      ? _selectFile(e.path)
                      : null,
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: Center(
                              child: Icon(
                                isDir
                                    ? _folderIcon(name)
                                    : Icons.picture_as_pdf_rounded,
                                color: isDir
                                    ? folderColor
                                    : const Color(0xFFC62828),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDir ? 'Dossier' : 'PDF',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
      bottomNavigationBar: !widget.pickFile
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _selectFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Utiliser ce dossier'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
