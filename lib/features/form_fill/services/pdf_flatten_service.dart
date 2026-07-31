import 'dart:typed_data';

import 'package:pdf_tech/services/isolate_runner.dart';
import 'package:pdf_tech/services/pdf_tools_service.dart';
import 'package:pdf_tech/utils/atomic_write.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service d'aplatissement d'un formulaire PDF rempli.
///
/// Convertit les champs interactifs en contenu statique.
class PdfFlattenService {
  const PdfFlattenService();

  /// Aplatit [filledBytes] et écrit le résultat dans un fichier de sortie.
  Future<String> flattenAndWrite(
    Uint8List filledBytes, {
    required String outputName,
  }) async {
    final out = await runPdfIsolate(() => _flattenInIsolate(filledBytes));
    final outPath = await PdfToolsService.outputPath(outputName);
    await atomicWriteBytes(outPath, out);
    return outPath;
  }

  static Uint8List _flattenInIsolate(Uint8List filledBytes) {
    final doc = PdfDocument(inputBytes: filledBytes);
    try {
      doc.form.flattenAllFields();
      final saved = doc.saveSync();
      return saved is Uint8List ? saved : Uint8List.fromList(saved);
    } finally {
      doc.dispose();
    }
  }
}
