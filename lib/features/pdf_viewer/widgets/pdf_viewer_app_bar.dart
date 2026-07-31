import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// AppBar du viewer PDF avec titre, compteur de page et actions.
class PdfViewerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int currentPage;
  final int totalPages;
  final bool hasUnsavedChanges;
  final bool isSaving;
  final bool nightMode;
  final bool isSearchOpen;
  final GlobalKey<SfPdfViewerState> viewerKey;
  final VoidCallback onSave;
  final VoidCallback onToggleNightMode;
  final VoidCallback onToggleSearch;
  final VoidCallback onShare;
  final void Function(String value) onMenuAction;

  const PdfViewerAppBar({
    super.key,
    required this.title,
    required this.currentPage,
    required this.totalPages,
    required this.hasUnsavedChanges,
    required this.isSaving,
    required this.nightMode,
    required this.isSearchOpen,
    required this.viewerKey,
    required this.onSave,
    required this.onToggleNightMode,
    required this.onToggleSearch,
    required this.onShare,
    required this.onMenuAction,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15),
          ),
          if (totalPages > 0)
            Text(
              'Page $currentPage / $totalPages',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
      actions: [
        if (hasUnsavedChanges)
          isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Sauvegarder les annotations',
                  icon: const Icon(Icons.save_outlined),
                  onPressed: onSave,
                ),
        IconButton(
          tooltip: nightMode ? 'Mode jour' : 'Mode nuit',
          icon: Icon(nightMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: onToggleNightMode,
        ),
        IconButton(
          tooltip: 'Rechercher',
          icon: Icon(isSearchOpen ? Icons.search_off : Icons.search),
          onPressed: onToggleSearch,
        ),
        IconButton(
          tooltip: 'Signets',
          icon: const Icon(Icons.bookmark_outline),
          onPressed: () => viewerKey.currentState?.openBookmarkView(),
        ),
        IconButton(
          tooltip: 'Partager',
          icon: const Icon(Icons.share),
          onPressed: onShare,
        ),
        PopupMenuButton<String>(
          tooltip: 'Plus d\'options',
          onSelected: onMenuAction,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'zoom_in',
              child: ListTile(
                leading: Icon(Icons.zoom_in),
                title: Text('Zoom avant'),
              ),
            ),
            PopupMenuItem(
              value: 'zoom_out',
              child: ListTile(
                leading: Icon(Icons.zoom_out),
                title: Text('Zoom arrière'),
              ),
            ),
            PopupMenuItem(
              value: 'fit',
              child: ListTile(
                leading: Icon(Icons.fit_screen),
                title: Text('Ajuster à l\'écran'),
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'jump',
              child: ListTile(
                leading: Icon(Icons.input),
                title: Text('Aller à la page…'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
