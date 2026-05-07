import 'dart:async';
import 'dart:io';

import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/pdf_picker_screen.dart';
import '../all_pdfs_screen.dart';
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

  /// Raccourcis vers les dossiers les plus susceptibles de contenir des PDFs.
  /// Chaque tuile ouvre un PdfFolderScreen filtré .pdf — l'utilisateur n'a
  /// pas à fouiller dans le SAF système.
  static const _browseFolders = [
    (
      icon: Icons.download_outlined,
      label: 'Téléchargements',
      path: '/storage/emulated/0/Download',
      color: Color(0xFF43A047),
    ),
    (
      icon: Icons.description_outlined,
      label: 'Documents',
      path: '/storage/emulated/0/Documents',
      color: Color(0xFF1976D2),
    ),
    (
      icon: Icons.chat_outlined,
      label: 'WhatsApp',
      path:
          '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
      color: Color(0xFF25D366),
    ),
    (
      icon: Icons.folder_special_outlined,
      label: 'PDF Tech',
      path: '/storage/emulated/0/Documents/PDF Tech',
      color: Color(0xFFFF7043),
    ),
  ];

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
          _freeBytes = (res['free'] as num).toInt();
        });
      }
    } catch (_) {}
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

  /// "Lire un PDF" : ouvre le dernier PDF lu si dispo (et fichier existe
  /// toujours), sinon ouvre le PdfPickerScreen pour choisir.
  Future<void> _readLastOrPick(BuildContext context) async {
    final last = widget.recentFiles.isNotEmpty
        ? widget.recentFiles.first
        : null;
    if (last != null && await File(last.path).exists()) {
      if (!context.mounted) return;
      widget.onOpen(last.path);
      return;
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfAnnotateScreen(path: picked)),
    );
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
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );
    if (ok != true) return false;

    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Permission refusée — activez "Tous les fichiers" dans Réglages',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Réglages',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
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
    final exists = await dir.exists();
    if (!mounted) return;
    if (!exists) {
      if (label == 'PDF Tech') {
        try {
          await dir.create(recursive: true);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible de créer le dossier PDF Tech : $e'),
            ),
          );
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dossier "$label" introuvable sur ce téléphone'),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PdfFolderScreen(path: path, title: label, onPick: widget.onOpen),
      ),
    );
  }

  /// Scan récursif de tout /sdcard pour trouver tous les PDFs du tél.
  /// Utile pour le premier lancement quand l'utilisateur ne sait pas où
  /// sont ses fichiers. Affiche un dialog de progression avec bouton
  /// "Annuler" qui interrompt proprement le scan.
  Future<void> _scanAllPdfs() async {
    if (!await _ensureStorageAccess()) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final found = <File>[];
    int scanned = 0;

    // Completer qui sert de flag d'annulation : complété par le bouton
    // "Annuler" du dialog ; observé par `_walk` pour s'arrêter proprement.
    final canceller = Completer<void>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Recherche des PDFs sur votre téléphone…')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!canceller.isCompleted) canceller.complete();
            },
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    try {
      await _walk(
        Directory('/storage/emulated/0'),
        found,
        () => scanned++,
        canceller,
      );
    } catch (_) {
      /* perm denied — on continue avec ce qu'on a */
    }

    final wasCancelled = canceller.isCompleted;

    if (!mounted) return;
    navigator.pop(); // ferme le dialog progress

    if (wasCancelled && found.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Scan annulé')));
      return;
    }
    if (found.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Aucun PDF trouvé sur ce téléphone')),
      );
      return;
    }
    // Pré-calcule les FileStat une seule fois — sinon `sort()` appelle
    // `statSync()` deux fois par comparaison (O(n log n) IO sur main isolate).
    final withStat = <(File, FileStat)>[
      for (final f in found) (f, f.statSync()),
    ]..sort((a, b) => b.$2.modified.compareTo(a.$2.modified));
    final foundSorted = withStat.map((e) => e.$1).toList(growable: false);
    final statsByPath = {for (final entry in withStat) entry.$1.path: entry.$2};

    navigator.push(
      MaterialPageRoute(
        builder: (_) => AllPdfsScreen(
          files: foundSorted,
          statsByPath: statsByPath,
          onPick: widget.onOpen,
        ),
      ),
    );
  }

  /// Walk récursif limité aux sous-dossiers utilisateur, ignore caches/Android.
  /// [depth] borne la profondeur (sécurité contre liens/symlinks pathologiques
  /// et arbo très profondes qui figent le scan). Le paramètre [canceller]
  /// permet d'interrompre proprement depuis l'UI.
  static const int _walkMaxDepth = 8;
  Future<void> _walk(
    Directory dir,
    List<File> out,
    void Function() onTick,
    Completer<void> canceller, {
    int depth = 0,
  }) async {
    if (depth >= _walkMaxDepth) return;
    if (canceller.isCompleted) return;
    final skip = {'Android', '.thumbnails', '.cache'};
    try {
      await for (final e in dir.list(recursive: false, followLinks: false)) {
        if (canceller.isCompleted) return;
        onTick();
        if (e is File) {
          if (e.path.toLowerCase().endsWith('.pdf')) out.add(e);
        } else if (e is Directory) {
          final name = PathUtils.fileName(e.path);
          if (skip.contains(name) || name.startsWith('.')) continue;
          await _walk(e, out, onTick, canceller, depth: depth + 1);
        }
      }
    } catch (_) {
      /* dossier inaccessible */
    }
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
        // Toujours visible — accès direct aux dossiers les plus probables.
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
            ..._browseFolders.map(
              (f) => ActionCard(
                icon: f.icon,
                label: f.label,
                color: f.color,
                onTap: () => _browseFolder(f.path, f.label),
              ),
            ),
            ActionCard(
              icon: Icons.search,
              label: 'Trouver mes PDFs',
              color: const Color(0xFFAB47BC),
              onTap: _scanAllPdfs,
            ),
            ActionCard(
              icon: Icons.folder_outlined,
              label: 'Choisir…',
              color: const Color(0xFF607D8B),
              onTap: () => widget.onPickFile(),
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
                title: Text('Retirer'),
              ),
            ),
          ],
        ),
        onTap: () => widget.onOpen(file.path),
      ),
    );
  }
}
