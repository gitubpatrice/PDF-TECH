import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/pdf_viewer_screen.dart';

Future<void> showResultSheet(
  BuildContext context, {
  required String outputPath,
  required String operationLabel,
}) async {
  final fileName = outputPath.split(RegExp(r'[/\\]')).last;

  await showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 56),
            const SizedBox(height: 12),
            Text(operationLabel,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(fileName,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ouvrir'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(
                            path: outputPath,
                            title: fileName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Partager'),
                    onPressed: () async {
                      Navigator.pop(context);
                      await Share.shareXFiles(
                        [XFile(outputPath, mimeType: 'application/pdf')],
                        subject: fileName,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
