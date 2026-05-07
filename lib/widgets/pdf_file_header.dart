import 'package:flutter/material.dart';
import 'package:files_tech_core/files_tech_core.dart';

/// Ligne d'en-tête réutilisable affichant le nom du PDF sélectionné
/// avec un bouton "Changer". Variante compacte (pas de Card) — utilisée
/// quand un PDF est déjà choisi et qu'on veut juste rappeler son nom
/// au-dessus d'un formulaire.
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

/// Carte de sélection de PDF utilisée comme entête d'écran-outil.
/// Affiche un placeholder "Aucun fichier sélectionné" tant que [fileName]
/// est `null`, puis le nom du fichier (+ sous-titre optionnel) une fois choisi.
/// Le bouton trailing et le tap sur la carte appellent tous deux [onPick].
///
/// Factorise le pattern Card+ListTile précédemment dupliqué dans une dizaine
/// d'écrans `tools/*` (compress, protect, rotate, split, watermark, signature…).
class PdfFilePickerCard extends StatelessWidget {
  final String? fileName;
  final String? subtitle;
  final VoidCallback onPick;
  final String pickLabel;
  final String emptyLabel;

  const PdfFilePickerCard({
    super.key,
    required this.fileName,
    required this.onPick,
    this.subtitle,
    this.pickLabel = 'Choisir',
    this.emptyLabel = 'Aucun fichier sélectionné',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.picture_as_pdf,
          color: Color(0xFFC62828),
          size: 32,
        ),
        title: Text(fileName ?? emptyLabel),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: TextButton(onPressed: onPick, child: Text(pickLabel)),
        onTap: onPick,
      ),
    );
  }
}

/// Extrait le nom de fichier depuis un chemin (compatible Android/Windows).
String fileNameOf(String path) => PathUtils.fileName(path);
