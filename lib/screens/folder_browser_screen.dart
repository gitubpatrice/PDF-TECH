import 'dart:io';

import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

/// Explorateur de fichiers intégré. Nécessite [MANAGE_EXTERNAL_STORAGE]
/// (ou un path déjà accessible) pour parcourir le stockage externe.
///
/// Affiche tous les dossiers et fichiers du téléphone comme un explorateur
/// classique, avec 3 modes de rendu :
/// - **Icônes** : grille 2 colonnes, miniatures pour les images.
/// - **Liste** : liste compacte avec icône / miniature, nom et type.
/// - **Détails** : liste avec taille et date de modification.
///
/// Seuls les fichiers PDF sont sélectionnables quand [pickFile] est true.
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

enum _ViewMode { icons, list, details }

class _FileItem {
  final FileSystemEntity entity;
  final FileStat? stat;
  final String name;

  const _FileItem({required this.entity, this.stat, required this.name});

  bool get isDirectory => entity is Directory;
  bool get isPdf => !isDirectory && name.toLowerCase().endsWith('.pdf');
  bool get isImage {
    if (isDirectory) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  String get formattedSize {
    final s = stat;
    if (s == null || isDirectory) return '';
    return FormatUtils.bytesStorage(s.size);
  }

  String get formattedDate {
    final s = stat;
    if (s == null) return '';
    return DateFormatUtils.relative(s.modified);
  }
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  List<_FileItem> _items = [];
  bool _loading = true;
  String? _error;
  _ViewMode _viewMode = _ViewMode.icons;

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

      final entries = await dir.list(followLinks: false).toList();
      entries.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir && !bDir) return -1;
        if (!aDir && bDir) return 1;
        return PathUtils.fileName(
          a.path,
        ).toLowerCase().compareTo(PathUtils.fileName(b.path).toLowerCase());
      });

      // Précharge les FileStat en parallèle pour les modes Liste/Détails.
      // Les dossiers système inaccessibles sont ignorés silencieusement.
      final items = await Future.wait(
        entries.map((e) async {
          try {
            final stat = await e.stat();
            return _FileItem(
              entity: e,
              name: PathUtils.fileName(e.path),
              stat: stat,
            );
          } catch (_) {
            return _FileItem(entity: e, name: PathUtils.fileName(e.path));
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _items = items;
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

  void _onItemTap(_FileItem item) {
    if (item.isDirectory) {
      _enter(item.entity.path);
    } else if (item.isPdf) {
      _selectFile(item.entity.path);
    }
  }

  static IconData _folderIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('download')) return Icons.download_rounded;
    if (lower.contains('document')) return Icons.description_rounded;
    if (lower.contains('music') || lower.contains('audio')) {
      return Icons.music_note_rounded;
    }
    if (lower.contains('video') || lower.contains('movie')) {
      return Icons.movie_rounded;
    }
    if (lower.contains('image') ||
        lower.contains('picture') ||
        lower.contains('photo')) {
      return Icons.photo_rounded;
    }
    if (lower.contains('dcim') || lower.contains('camera')) {
      return Icons.camera_alt_rounded;
    }
    if (lower.contains('whatsapp')) return Icons.chat_rounded;
    if (lower.contains('telegram')) return Icons.telegram_rounded;
    if (lower.contains('android')) return Icons.android_rounded;
    if (lower.contains('sync') || lower.contains('cloud')) {
      return Icons.cloud_rounded;
    }
    return Icons.folder_rounded;
  }

  static Color _folderColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('download')) return const Color(0xFF43A047);
    if (lower.contains('document')) return const Color(0xFF1565C0);
    if (lower.contains('music') || lower.contains('audio')) {
      return const Color(0xFF8E24AA);
    }
    if (lower.contains('video') || lower.contains('movie')) {
      return const Color(0xFFE53935);
    }
    if (lower.contains('image') ||
        lower.contains('picture') ||
        lower.contains('photo')) {
      return const Color(0xFFFB8C00);
    }
    if (lower.contains('dcim') || lower.contains('camera')) {
      return const Color(0xFF00897B);
    }
    if (lower.contains('whatsapp')) return const Color(0xFF25D366);
    if (lower.contains('telegram')) return const Color(0xFF29B6F6);
    if (lower.contains('android')) return const Color(0xFF3DDC84);
    if (lower.contains('sync') || lower.contains('cloud')) {
      return const Color(0xFF039BE5);
    }
    return const Color(0xFFFFB300);
  }

  static IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov')) {
      return Icons.video_file_rounded;
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg')) {
      return Icons.audio_file_rounded;
    }
    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.rtf') ||
        lower.endsWith('.odt')) {
      return Icons.description_rounded;
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.ods')) {
      return Icons.table_chart_rounded;
    }
    if (lower.endsWith('.ppt') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.odp')) {
      return Icons.slideshow_rounded;
    }
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.gz')) {
      return Icons.folder_zip_rounded;
    }
    if (lower.endsWith('.apk')) return Icons.android_rounded;
    if (lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.css') ||
        lower.endsWith('.js')) {
      return Icons.code_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  static Color _fileColor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return const Color(0xFFC62828);
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      return const Color(0xFFFB8C00);
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov')) {
      return const Color(0xFFE53935);
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg')) {
      return const Color(0xFF8E24AA);
    }
    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.rtf') ||
        lower.endsWith('.odt')) {
      return const Color(0xFF1565C0);
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.ods')) {
      return const Color(0xFF2E7D32);
    }
    if (lower.endsWith('.ppt') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.odp')) {
      return const Color(0xFFE65100);
    }
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.gz')) {
      return const Color(0xFF795548);
    }
    if (lower.endsWith('.apk')) return const Color(0xFF3DDC84);
    if (lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.css') ||
        lower.endsWith('.js')) {
      return const Color(0xFF039BE5);
    }
    return const Color(0xFF607D8B);
  }

  static String _fileLabel(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'PDF';
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      return 'Image';
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov')) {
      return 'Vidéo';
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg')) {
      return 'Audio';
    }
    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.rtf') ||
        lower.endsWith('.odt')) {
      return 'Document';
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.ods')) {
      return 'Tableur';
    }
    if (lower.endsWith('.ppt') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.odp')) {
      return 'Présentation';
    }
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.gz')) {
      return 'Archive';
    }
    if (lower.endsWith('.apk')) return 'APK';
    if (lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.css') ||
        lower.endsWith('.js')) {
      return 'Code';
    }
    return 'Fichier';
  }

  Widget _leadingThumbnail(_FileItem item, double size) {
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.15),
        child: Image.file(
          File(item.entity.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).toInt(),
          cacheHeight: (size * 2).toInt(),
          errorBuilder: (context, error, stackTrace) =>
              _fallbackIcon(item, size),
        ),
      );
    }
    return _fallbackIcon(item, size);
  }

  Widget _fallbackIcon(_FileItem item, double size) {
    return Icon(
      item.isDirectory ? _folderIcon(item.name) : _fileIcon(item.name),
      color: item.isDirectory ? _folderColor(item.name) : _fileColor(item.name),
      size: size * 0.75,
    );
  }

  Widget _buildIconView() {
    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      padding: const EdgeInsets.all(8),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.0,
      children: _items.map((item) {
        return GestureDetector(
          onTap: () => _onItemTap(item),
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(child: _leadingThumbnail(item, 56)),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.isDirectory ? 'Dossier' : _fileLabel(item.name),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        return ListTile(
          dense: true,
          leading: SizedBox(
            width: 40,
            height: 40,
            child: _leadingThumbnail(item, 40),
          ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            item.isDirectory ? 'Dossier' : _fileLabel(item.name),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => _onItemTap(item),
        );
      },
    );
  }

  Widget _buildDetailsView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        return ListTile(
          dense: true,
          leading: SizedBox(
            width: 40,
            height: 40,
            child: _leadingThumbnail(item, 40),
          ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            item.isDirectory ? 'Dossier' : _fileLabel(item.name),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.formattedSize.isNotEmpty)
                  Text(
                    item.formattedSize,
                    style: const TextStyle(fontSize: 11),
                  ),
                Text(
                  item.formattedDate,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          onTap: () => _onItemTap(item),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.grey)),
      );
    }
    if (_items.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
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
              'Aucun fichier ici',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return switch (_viewMode) {
      _ViewMode.icons => _buildIconView(),
      _ViewMode.list => _buildListView(),
      _ViewMode.details => _buildDetailsView(),
    };
  }

  void _setViewMode(_ViewMode mode) {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
  }

  Widget _viewModeSelector() {
    return ToggleButtons(
      isSelected: [
        _viewMode == _ViewMode.icons,
        _viewMode == _ViewMode.list,
        _viewMode == _ViewMode.details,
      ],
      onPressed: (index) => _setViewMode(_ViewMode.values[index]),
      borderRadius: BorderRadius.circular(8),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
      children: const [
        Tooltip(
          message: 'Icônes',
          child: Icon(Icons.grid_view_rounded, size: 20),
        ),
        Tooltip(
          message: 'Liste',
          child: Icon(Icons.view_list_rounded, size: 20),
        ),
        Tooltip(
          message: 'Détails',
          child: Icon(Icons.view_headline_rounded, size: 20),
        ),
      ],
    );
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
                '${_items.length} élément${_items.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          _viewModeSelector(),
          const SizedBox(width: 8),
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
      body: _buildBody(),
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
