import 'package:flutter/material.dart';

/// Barre de recherche flottante affichée au-dessus du viewer PDF.
class PdfSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  const PdfSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Rechercher dans le PDF…',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: onSearch,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 20),
            tooltip: 'Résultat précédent',
            onPressed: onPrevious,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 20),
            tooltip: 'Résultat suivant',
            onPressed: onNext,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Fermer la recherche',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
