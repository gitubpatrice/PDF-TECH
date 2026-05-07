import 'package:flutter/material.dart';
import '../tools/merge_screen.dart';
import '../tools/split_screen.dart';
import '../tools/protect_screen.dart';
import '../tools/rotate_screen.dart';
import '../tools/watermark_screen.dart';
import '../tools/create_pdf_screen.dart';
import '../tools/compress_screen.dart';
import '../tools/signature_screen.dart';
import '../tools/form_fill_screen.dart';
import '../tools/ocr_screen.dart';
import '../tools/delete_pages_screen.dart';
import '../tools/reorder_pages_screen.dart';
import '../tools/export_images_screen.dart';
import '../tools/metadata_screen.dart';
import '../tools/page_numbers_screen.dart';
import '../tools/stamp_screen.dart';
import '../tools/header_footer_screen.dart';
import '../tools/extract_images_screen.dart';
import '../tools/compare_screen.dart';
import '../tools/images_to_pdf_screen.dart';
import '../tools/decrypt_screen.dart';

/// Onglet "Outils" du HomeScreen — grille 2 colonnes de tous les outils PDF.
/// Tap → push de l'écran outil correspondant.
class ToolsTab extends StatelessWidget {
  final VoidCallback onPickFile;

  const ToolsTab({super.key, required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    final tools = [
      (
        icon: Icons.merge_type,
        label: 'Fusionner',
        subtitle: 'Combiner plusieurs PDFs',
        color: Colors.blue,
        screen: const MergeScreen(),
      ),
      (
        icon: Icons.call_split,
        label: 'Diviser',
        subtitle: 'Extraire des pages',
        color: Colors.green,
        screen: const SplitScreen(),
      ),
      (
        icon: Icons.lock_outline,
        label: 'Protéger',
        subtitle: 'Ajouter un mot de passe',
        color: Colors.red,
        screen: const ProtectScreen(),
      ),
      (
        icon: Icons.rotate_right,
        label: 'Rotation',
        subtitle: 'Tourner les pages',
        color: Colors.teal,
        screen: const RotateScreen(),
      ),
      (
        icon: Icons.water_drop_outlined,
        label: 'Filigrane',
        subtitle: 'Ajouter un filigrane',
        color: Colors.indigo,
        screen: const WatermarkScreen(),
      ),
      (
        icon: Icons.create_outlined,
        label: 'Créer PDF',
        subtitle: 'Nouveau document',
        color: Colors.purple,
        screen: const CreatePdfScreen(),
      ),
      (
        icon: Icons.compress,
        label: 'Compresser',
        subtitle: 'Réduire la taille',
        color: Colors.orange,
        screen: const CompressScreen(),
      ),
      (
        icon: Icons.draw_outlined,
        label: 'Signature',
        subtitle: 'Insérer une signature',
        color: Colors.pink,
        screen: const SignatureScreen(),
      ),
      (
        icon: Icons.assignment_outlined,
        label: 'Formulaires',
        subtitle: 'Remplir un formulaire',
        color: Colors.cyan,
        screen: const FormFillScreen(),
      ),
      (
        icon: Icons.document_scanner_outlined,
        label: 'OCR',
        subtitle: 'Extraire le texte',
        color: Colors.deepOrange,
        screen: const OcrScreen(),
      ),
      (
        icon: Icons.delete_sweep_outlined,
        label: 'Supprimer',
        subtitle: 'Retirer des pages',
        color: Colors.red,
        screen: const DeletePagesScreen(),
      ),
      (
        icon: Icons.swap_vert_circle_outlined,
        label: 'Réorganiser',
        subtitle: 'Changer l\'ordre des pages',
        color: Colors.amber,
        screen: const ReorderPagesScreen(),
      ),
      (
        icon: Icons.image_outlined,
        label: 'Exporter images',
        subtitle: 'Pages en PNG / JPEG',
        color: Colors.lightGreen,
        screen: const ExportImagesScreen(),
      ),
      (
        icon: Icons.info_outline,
        label: 'Métadonnées',
        subtitle: 'Titre, auteur, sujet',
        color: Colors.blueGrey,
        screen: const MetadataScreen(),
      ),
      (
        icon: Icons.format_list_numbered,
        label: 'Numéroter',
        subtitle: 'Ajouter des numéros',
        color: Colors.cyan,
        screen: const PageNumbersScreen(),
      ),
      (
        icon: Icons.approval_outlined,
        label: 'Tampon',
        subtitle: 'CONFIDENTIEL, APPROUVÉ…',
        color: Colors.red,
        screen: const StampScreen(),
      ),
      (
        icon: Icons.vertical_split_outlined,
        label: 'En-tête / Pied',
        subtitle: 'Texte fixe sur les pages',
        color: Colors.indigo,
        screen: const HeaderFooterScreen(),
      ),
      (
        icon: Icons.image_search,
        label: 'Extraire images',
        subtitle: 'Images intégrées au PDF',
        color: Colors.teal,
        screen: const ExtractImagesScreen(),
      ),
      (
        icon: Icons.compare_outlined,
        label: 'Comparer',
        subtitle: 'Deux PDFs côte à côte',
        color: Colors.deepPurple,
        screen: const CompareScreen(),
      ),
      (
        icon: Icons.add_photo_alternate_outlined,
        label: 'Images → PDF',
        subtitle: 'JPG/PNG vers un PDF',
        color: Colors.lightGreen,
        screen: const ImagesToPdfScreen(),
      ),
      (
        icon: Icons.lock_open_outlined,
        label: 'Déchiffrer',
        subtitle: 'Retirer le mot de passe',
        color: Colors.teal,
        screen: const DecryptScreen(),
      ),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) {
        final tool = tools[i];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => tool.screen),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tool.icon, size: 36, color: tool.color),
                  const SizedBox(height: 8),
                  Text(
                    tool.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
