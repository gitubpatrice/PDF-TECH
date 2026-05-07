import 'package:flutter/material.dart';

// TODO v1.10 : généraliser PdfFileHeader à tous les écrans tools/* qui dupliquent
// le pattern Card + ListTile picker (compress, protect, rotate, decrypt, signature,
// split, metadata, delete_pages, reorder_pages, watermark, stamp, header_footer,
// page_numbers, extract_images, compare, form_fill). ~300-400 lignes à factoriser.
// Dette technique identifiée dans l'audit v1.9.x — pas un oubli.

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
