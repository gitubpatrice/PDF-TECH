import 'package:flutter/material.dart';

/// En-tête affichant le nom du fichier PDF sélectionné et un bouton pour le
/// changer.
class FileHeader extends StatelessWidget {
  final String name;
  final VoidCallback onChange;

  const FileHeader({super.key, required this.name, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Changer')),
        ],
      ),
    );
  }
}
