import 'package:flutter/material.dart';

/// Ligne d'en-tête réutilisable affichant le nom du PDF sélectionné
/// avec un bouton "Changer". Factorise un widget précédemment dupliqué
/// dans la majorité des écrans `tools/*`.
class PdfFileHeader extends StatelessWidget {
  final String name;
  final VoidCallback? onChange;
  final String changeLabel;

  const PdfFileHeader({
    super.key,
    required this.name,
    this.onChange,
    this.changeLabel = 'Changer',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
        if (onChange != null)
          TextButton(onPressed: onChange, child: Text(changeLabel)),
      ],
    );
  }
}

/// Extrait le nom de fichier depuis un chemin (compatible Android/Windows).
String fileNameOf(String path) => path.split(RegExp(r'[/\\]')).last;
