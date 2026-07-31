import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Barre d'outils d'annotation affichée en bas du viewer.
class PdfAnnotationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final PdfAnnotationMode activeMode;
  final ValueChanged<PdfAnnotationMode> onModeChanged;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  const PdfAnnotationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.activeMode,
    required this.onModeChanged,
    this.onPreviousPage,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModeButton(
            icon: Icons.highlight,
            label: 'Surligner',
            activeColor: Colors.yellow[700]!,
            active: activeMode == PdfAnnotationMode.highlight,
            onTap: () => onModeChanged(PdfAnnotationMode.highlight),
          ),
          _ModeButton(
            icon: Icons.format_underline,
            label: 'Souligner',
            activeColor: Colors.blue,
            active: activeMode == PdfAnnotationMode.underline,
            onTap: () => onModeChanged(PdfAnnotationMode.underline),
          ),
          _ModeButton(
            icon: Icons.strikethrough_s,
            label: 'Barrer',
            activeColor: Colors.red,
            active: activeMode == PdfAnnotationMode.strikethrough,
            onTap: () => onModeChanged(PdfAnnotationMode.strikethrough),
          ),
          _ModeButton(
            icon: Icons.format_color_text,
            label: 'Ondulé',
            activeColor: Colors.purple,
            active: activeMode == PdfAnnotationMode.squiggly,
            onTap: () => onModeChanged(PdfAnnotationMode.squiggly),
          ),
          _ModeButton(
            icon: Icons.sticky_note_2_outlined,
            label: 'Note',
            activeColor: Colors.orange,
            active: activeMode == PdfAnnotationMode.stickyNote,
            onTap: () => onModeChanged(PdfAnnotationMode.stickyNote),
          ),
          const VerticalDivider(indent: 8, endIndent: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Page précédente',
            onPressed: onPreviousPage,
          ),
          Text(
            '$currentPage/$totalPages',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Page suivante',
            onPressed: onNextPage,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color activeColor;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Semantics avec `selected: active` pour TalkBack.
    return Semantics(
      label: label,
      selected: active,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: active
                ? BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.5),
                    ),
                  )
                : null,
            child: Icon(
              icon,
              color: active ? activeColor : Colors.grey,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
