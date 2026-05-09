import 'package:flutter/material.dart';
import '../../widgets/pdf_picker_screen.dart';
import '../tools/compare_screen.dart';
import '../tools/compress_screen.dart';
import '../tools/create_pdf_screen.dart';
import '../tools/decrypt_screen.dart';
import '../tools/delete_pages_screen.dart';
import '../tools/export_images_screen.dart';
import '../tools/extract_images_screen.dart';
import '../tools/form_fill_screen.dart';
import '../tools/header_footer_screen.dart';
import '../tools/images_to_pdf_screen.dart';
import '../tools/merge_screen.dart';
import '../tools/metadata_screen.dart';
import '../tools/ocr_screen.dart';
import '../tools/page_numbers_screen.dart';
import '../tools/pdf_annotate_screen.dart';
import '../tools/protect_screen.dart';
import '../tools/reorder_pages_screen.dart';
import '../tools/rotate_screen.dart';
import '../tools/signature_screen.dart';
import '../tools/split_screen.dart';
import '../tools/stamp_screen.dart';
import '../tools/watermark_screen.dart';

/// Onglet "Outils" du HomeScreen — grille 2 colonnes de tous les outils PDF.
///
/// Chaque tuile expose un `onTap` qui peut soit pousser directement un
/// écran, soit déclencher un picker (cas Annoter). Patterns mélangés mais
/// uniformes côté caller (`Navigator.push` ou `_pickAndAnnotate`).
class ToolsTab extends StatelessWidget {
  final VoidCallback onPickFile;

  const ToolsTab({super.key, required this.onPickFile});

  /// Picker dédié pour Annoter (audit branchements P0 v1.12) :
  /// l'écran d'annotation a besoin d'un PDF — on déclenche le SAF puis
  /// on push l'éditeur. Dupliquait `home_tab._editPdf` ; centralisé ici
  /// pour cohérence.
  static Future<void> _pickAndAnnotate(BuildContext context) async {
    final picked = await PdfPickerScreen.pickOne(
      context,
      title: 'PDF à annoter',
    );
    if (picked == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PdfAnnotateScreen(path: picked)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = <_Tool>[
      _Tool(
        icon: Icons.merge_type,
        label: 'Fusionner',
        subtitle: 'Combiner plusieurs PDFs',
        color: Colors.blue,
        screen: const MergeScreen(),
      ),
      _Tool(
        icon: Icons.call_split,
        label: 'Diviser',
        subtitle: 'Extraire des pages',
        color: Colors.green,
        screen: const SplitScreen(),
      ),
      _Tool(
        icon: Icons.lock_outline,
        label: 'Protéger',
        subtitle: 'Ajouter un mot de passe',
        color: Colors.red,
        screen: const ProtectScreen(),
      ),
      _Tool(
        icon: Icons.rotate_right,
        label: 'Rotation',
        subtitle: 'Tourner les pages',
        color: Colors.teal,
        screen: const RotateScreen(),
      ),
      _Tool(
        icon: Icons.water_drop_outlined,
        label: 'Filigrane',
        subtitle: 'Ajouter un filigrane',
        color: Colors.indigo,
        screen: const WatermarkScreen(),
      ),
      _Tool(
        icon: Icons.create_outlined,
        label: 'Créer PDF',
        subtitle: 'Nouveau document',
        color: Colors.purple,
        screen: const CreatePdfScreen(),
      ),
      _Tool(
        icon: Icons.compress,
        label: 'Compresser',
        subtitle: 'Réduire la taille',
        color: Colors.orange,
        screen: const CompressScreen(),
      ),
      _Tool(
        icon: Icons.draw_outlined,
        label: 'Signature',
        subtitle: 'Insérer une signature',
        color: Colors.pink,
        screen: const SignatureScreen(),
      ),
      _Tool(
        icon: Icons.assignment_outlined,
        label: 'Formulaires',
        subtitle: 'Remplir un formulaire',
        color: Colors.cyan,
        screen: const FormFillScreen(),
      ),
      _Tool(
        icon: Icons.document_scanner_outlined,
        label: 'OCR',
        subtitle: 'Extraire le texte',
        color: Colors.deepOrange,
        screen: const OcrScreen(),
      ),
      _Tool(
        icon: Icons.delete_sweep_outlined,
        label: 'Supprimer',
        subtitle: 'Retirer des pages',
        color: Colors.red,
        screen: const DeletePagesScreen(),
      ),
      _Tool(
        icon: Icons.swap_vert_circle_outlined,
        label: 'Réorganiser',
        subtitle: "Changer l'ordre des pages",
        color: Colors.amber,
        screen: const ReorderPagesScreen(),
      ),
      _Tool(
        icon: Icons.image_outlined,
        label: 'Exporter images',
        subtitle: 'Pages en PNG / JPEG',
        color: Colors.lightGreen,
        screen: const ExportImagesScreen(),
      ),
      _Tool(
        icon: Icons.info_outline,
        label: 'Métadonnées',
        subtitle: 'Titre, auteur, sujet',
        color: Colors.blueGrey,
        screen: const MetadataScreen(),
      ),
      _Tool(
        icon: Icons.format_list_numbered,
        label: 'Numéroter',
        subtitle: 'Ajouter des numéros',
        color: Colors.cyan,
        screen: const PageNumbersScreen(),
      ),
      _Tool(
        icon: Icons.approval_outlined,
        label: 'Tampon',
        subtitle: 'CONFIDENTIEL, APPROUVÉ…',
        color: Colors.red,
        screen: const StampScreen(),
      ),
      _Tool(
        icon: Icons.vertical_split_outlined,
        label: 'En-tête / Pied',
        subtitle: 'Texte fixe sur les pages',
        color: Colors.indigo,
        screen: const HeaderFooterScreen(),
      ),
      _Tool(
        icon: Icons.image_search,
        label: 'Extraire images',
        subtitle: 'Images intégrées au PDF',
        color: Colors.teal,
        screen: const ExtractImagesScreen(),
      ),
      _Tool(
        icon: Icons.compare_outlined,
        label: 'Comparer',
        subtitle: 'Deux PDFs côte à côte',
        color: Colors.deepPurple,
        screen: const CompareScreen(),
      ),
      _Tool(
        icon: Icons.add_photo_alternate_outlined,
        label: 'Images → PDF',
        subtitle: 'JPG/PNG vers un PDF',
        color: Colors.lightGreen,
        screen: const ImagesToPdfScreen(),
      ),
      _Tool(
        icon: Icons.lock_open_outlined,
        label: 'Déchiffrer',
        subtitle: 'Retirer le mot de passe',
        color: Colors.teal,
        screen: const DecryptScreen(),
      ),
      // 22e tuile (audit branchements v1.12) — Annoter était auparavant
      // accessible UNIQUEMENT via la quick-action "Modifier" du HomeTab,
      // ce qui rendait l'outil invisible depuis la grille.
      _Tool(
        icon: Icons.edit_note,
        label: 'Annoter',
        subtitle: 'Surligner, dessiner, notes',
        color: const Color(0xFF6A1B9A),
        action: _pickAndAnnotate,
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
            onTap: () => tool.open(context),
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

/// Modèle interne pour une tuile d'outil.
/// Soit [screen] est défini (push direct), soit [action] (callback custom).
/// Au moins l'un des deux doit être fourni.
class _Tool {
  const _Tool({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.screen,
    this.action,
  }) : assert(
         screen != null || action != null,
         'screen ou action doit être défini',
       );

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Widget? screen;
  final Future<void> Function(BuildContext)? action;

  Future<void> open(BuildContext context) async {
    final s = screen;
    final a = action;
    if (s != null) {
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => s));
      return;
    }
    if (a != null) {
      await a(context);
    }
  }
}
