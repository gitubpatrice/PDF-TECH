import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/secure_app_preferences.dart';
import '../../utils/storage_permission_service.dart';
import '../../widgets/pdf_picker_screen.dart';
import '../folder_browser_screen.dart';
import '../pdf_folder_screen.dart';
import '../tools/compress_screen.dart';
import '../tools/images_to_pdf_screen.dart';
import '../tools/merge_screen.dart';
import '../tools/ocr_screen.dart';
import '../tools/pdf_annotate_screen.dart';
import '../tools/protect_screen.dart';
import '../tools/split_screen.dart';
import 'widgets/action_card.dart';
import 'widgets/resume_card.dart';
import 'widgets/storage_bar.dart';

/// Onglet "Accueil" du HomeScreen — stockage + reprendre + parcourir +
/// actions rapides + favoris + récents.
class HomeTab extends StatefulWidget {
  final List<RecentFile> recentFiles;
  final bool isLoading;
  final ValueChanged<String> onOpen;
  final VoidCallback onPickFile;
  final ValueChanged<RecentFile> onRemove;
  final ValueChanged<RecentFile> onToggleFavorite;
  final ValueChanged<RecentFile> onShare;
  final String Function(DateTime) formatDate;

  const HomeTab({
    super.key,
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
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static final _storageChannel = MethodChannel('com.pdftech.pdf_tech/storage');
  int _totalBytes = 0;
  int _freeBytes = 0;

  static const _quickActions = [
    (
      icon: Icons.menu_book_outlined,
      label: 'Lire un PDF',
      color: Color(0xFF1565C0),
    ),
    (icon: Icons.edit_note, label: 'Modifier', color: Color(0xFF6A1B9A)),
    (icon: Icons.merge_type, label: 'Fusionner', color: Color(0xFF1976D2)),
    (icon: Icons.call_split, label: 'Diviser', color: Color(0xFF43A047)),
    (icon: Icons.compress, label: 'Compresser', color: Color(0xFFFF7043)),
    (
      icon: Icons.add_photo_alternate_outlined,
      label: 'Images→PDF',
      color: Color(0xFF8E24AA),
    ),
    (
      icon: Icons.document_scanner_outlined,
      label: 'OCR',
      color: Color(0xFFE53935),
    ),
    (icon: Icons.lock_outline, label: 'Protéger', color: Color(0xFF00897B)),
  ];

  @override
  void initState() {
    super.initState();
    _loadStorage();
  }

  Future<void> _loadStorage() async {
    try {
      final res = await _storageChannel.invokeMethod<Map>('getStorageInfo');
      if (res != null && mounted) {
        setState(() {
          _totalBytes = (res['total'] as num).toInt();
          _freeBytes = (res['free'] as num).toInt();
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeTab._loadStorage] $e');
    }
  }

  String _formatBytes(int bytes) => FormatUtils.bytesStorage(bytes);

  void _openQuickAction(BuildContext context, int index) {
    // Les 2 premiers indices sont des actions spéciales (Lire / Modifier),
    // les suivants pointent vers les outils existants.
    if (index == 0) {
      _readLastOrPick(context);
      return;
    }
    if (index == 1) {
      _editPdf(context);
      return;
    }
    final screens = [
      const MergeScreen(),
      const SplitScreen(),
      const CompressScreen(),
      const ImagesToPdfScreen(),
      const OcrScreen(),
      const ProtectScreen(),
    ];
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screens[index - 2]),
    );
  }

  /// "Lire un PDF" : tente d'ouvrir le dernier PDF lu si son path est encore
  /// lisible (app-private ou copie SAF), sinon ouvre le picker. Sous SAF,
  /// `File(path).exists()` sur un chemin public peut échouer sans permission
  /// globale ; on catch silencieusement et on délègue au picker.
  Future<void> _readLastOrPick(BuildContext context) async {
    final last = widget.recentFiles.isNotEmpty
        ? widget.recentFiles.first
        : null;
    if (last != null) {
      try {
        if (await File(last.path).exists()) {
          if (!context.mounted) return;
          widget.onOpen(last.path);
          return;
        }
      } catch (_) {
        // Path public sans accès : on passe au picker SAF.
      }
    }
    if (!context.mounted) return;
    final picked = await PdfPickerScreen.pickOne(context, title: 'Lire un PDF');
    if (picked != null) widget.onOpen(picked);
  }

  /// "Modifier un PDF" : ouvre l'éditeur d'annotations.
  Future<void> _editPdf(BuildContext context) async {
    final picked = await PdfPickerScreen.pickOne(
      context,
      title: 'PDF à modifier',
    );
    if (picked == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfAnnotateScreen(path: picked)),
    );
  }

  /// Ouvre l'explorateur de dossiers integre pour parcourir le stockage
  /// et selectionner un PDF.
  ///
  /// P0 v1.13.4+ — mode securise par defaut : l'acces complet au stockage
  /// n'est utilise que si l'utilisateur l'a explicitement active dans les
  /// parametres. Sinon, le picker de dossier SAF natif est propose.
  Future<void> _pickAndBrowseFolder() async {
    final fullMode = await SecureAppPreferences.getFullStorageMode();
    if (!mounted) return;
    if (!fullMode) {
      final dir = await FilePicker.getDirectoryPath();
      if (dir == null || !mounted) return;
      final label = PathUtils.fileName(dir);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfFolderScreen(
            path: dir,
            title: label.isEmpty ? 'Dossier' : label,
            onPick: widget.onOpen,
          ),
        ),
      );
      return;
    }

    final hasStorage = await StoragePermissionService.requestWithDialog(
      context,
    );
    if (!mounted) return;
    if (!hasStorage) {
      // Fallback SAF si la permission globale est refusee.
      final dir = await FilePicker.getDirectoryPath();
      if (dir == null || !mounted) return;
      final label = PathUtils.fileName(dir);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfFolderScreen(
            path: dir,
            title: label.isEmpty ? 'Dossier' : label,
            onPick: widget.onOpen,
          ),
        ),
      );
      return;
    }

    final rootDir = Directory('/sdcard');
    if (!mounted) return;
    if (!await rootDir.exists()) return;
    if (!mounted) return;
    final root = rootDir.path;

    final picked = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FolderBrowserScreen(path: root, title: 'Stockage', pickFile: true),
      ),
    );
    if (picked != null && mounted) widget.onOpen(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final favorites = widget.recentFiles.where((f) => f.isFavorite).toList();
    final recents = widget.recentFiles.where((f) => !f.isFavorite).toList();
    final lastFile = widget.recentFiles.isNotEmpty
        ? widget.recentFiles.first
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        // ── Stockage ────────────────────────────────────────────────────────
        if (_totalBytes > 0) ...[
          _sectionHeader(
            context,
            'Stockage interne',
            Icons.storage_outlined,
            Colors.blueGrey,
          ),
          const SizedBox(height: 6),
          StorageBar(
            freeBytes: _freeBytes,
            totalBytes: _totalBytes,
            formatBytes: _formatBytes,
          ),
          const SizedBox(height: 16),
        ],

        // ── Reprendre ───────────────────────────────────────────────────────
        if (lastFile != null) ...[
          _sectionHeader(
            context,
            'Reprendre',
            Icons.play_circle_outline,
            Colors.blue,
          ),
          const SizedBox(height: 6),
          ResumeCard(
            file: lastFile,
            formatDate: widget.formatDate,
            onTap: () => widget.onOpen(lastFile.path),
          ),
          const SizedBox(height: 16),
        ],

        // ── Parcourir ───────────────────────────────────────────────────────
        // P0 v1.13.2 — sans MANAGE_EXTERNAL_STORAGE, l'app utilise le Storage
        // Access Framework : file_picker crée une copie temporaire lisible
        // ou retourne un path app-private. Plus de scan global, plus de
        // raccourcis hardcodés vers /storage/emulated/0/….
        _sectionHeader(
          context,
          'Parcourir',
          Icons.folder_open_outlined,
          Colors.teal,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
          children: [
            ActionCard(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Choisir un PDF',
              color: const Color(0xFF1565C0),
              onTap: () => widget.onPickFile(),
            ),
            ActionCard(
              icon: Icons.folder_outlined,
              label: 'Choisir un dossier',
              color: const Color(0xFF43A047),
              onTap: _pickAndBrowseFolder,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Actions rapides ─────────────────────────────────────────────────
        _sectionHeader(
          context,
          'Actions rapides',
          Icons.bolt_outlined,
          Colors.deepOrange,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
          children: _quickActions
              .asMap()
              .entries
              .map(
                (e) => ActionCard(
                  icon: e.value.icon,
                  label: e.value.label,
                  color: e.value.color,
                  onTap: () => _openQuickAction(context, e.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),

        // ── Favoris ─────────────────────────────────────────────────────────
        if (favorites.isNotEmpty) ...[
          _sectionHeader(context, 'Favoris', Icons.star, Colors.amber),
          ...favorites.map((f) => _fileCard(context, f)),
          const SizedBox(height: 8),
        ],

        // ── Récents ─────────────────────────────────────────────────────────
        _sectionHeader(
          context,
          'Récemment ouverts',
          Icons.history,
          Colors.grey,
        ),
        if (widget.recentFiles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 56,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucun PDF ouvert pour l\'instant',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Utilisez les raccourcis ci-dessus pour parcourir\n'
                      'vos dossiers ou rechercher tous vos PDFs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

  Widget _sectionHeader(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileCard(BuildContext context, RecentFile file) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Stack(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                color: Color(0xFFC62828),
                size: 24,
              ),
            ),
            if (file.isFavorite)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(Icons.star, size: 12, color: Colors.amber),
              ),
          ],
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          '${widget.formatDate(file.lastOpened)} · ${file.formattedSize}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: PopupMenuButton<String>(
          // U5 v1.12.4 — tooltip TalkBack pour le menu fichier.
          tooltip: 'Actions du fichier',
          onSelected: (v) {
            if (v == 'favorite') widget.onToggleFavorite(file);
            if (v == 'share') widget.onShare(file);
            if (v == 'remove') widget.onRemove(file);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'favorite',
              child: ListTile(
                leading: Icon(
                  file.isFavorite ? Icons.star_border : Icons.star,
                  color: Colors.amber,
                ),
                title: Text(
                  file.isFavorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris',
                ),
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text('Partager'),
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                // U18 v1.12.4 — précise que c'est la liste qui est affectée,
                // pas le fichier (icône delete + label "Retirer" était
                // ambigu, l'utilisateur pouvait croire à une suppression
                // disque).
                title: Text('Retirer de la liste'),
              ),
            ),
          ],
        ),
        onTap: () => widget.onOpen(file.path),
      ),
    );
  }
}
