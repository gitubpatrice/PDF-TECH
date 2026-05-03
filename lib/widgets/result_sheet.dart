import 'package:flutter/material.dart';
import '../screens/pdf_viewer_screen.dart';
import 'cloud_share_row.dart';

Future<void> showResultSheet(
  BuildContext context, {
  required String outputPath,
  required String operationLabel,
}) async {
  final fileName = outputPath.split(RegExp(r'[/\\]')).last;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 48),
            const SizedBox(height: 10),
            Text(
              operationLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              fileName,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            // Bouton "Ouvrir" pleine largeur (action principale)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ouvrir le PDF'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PdfViewerScreen(path: outputPath, title: fileName),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Partager ou envoyer',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // Boutons partager + cloud direct
            CloudShareRow(path: outputPath),
          ],
        ),
      ),
    ),
  );
}
