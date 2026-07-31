import 'package:flutter/material.dart';
import 'package:pdf_tech/services/pdf_tools_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Modèle décrivant un champ de formulaire détecté dans un PDF.
class FormFieldInfo {
  final String name;
  final String type;
  final String value;
  final IconData icon;

  const FormFieldInfo({
    required this.name,
    required this.type,
    required this.value,
    required this.icon,
  });
}

/// Analyse les champs interactifs d'un PDF et retourne une liste de
/// [FormFieldInfo] affichable.
class FormFieldAnalyzer {
  const FormFieldAnalyzer();

  Future<List<FormFieldInfo>> analyze(String path) async {
    final bytes = await PdfToolsService.safeReadPdf(path);
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final result = <FormFieldInfo>[];
      for (int i = 0; i < doc.form.fields.count; i++) {
        final f = doc.form.fields[i];
        final rawName = f.name;
        result.add(
          FormFieldInfo(
            name: (rawName == null || rawName.isEmpty)
                ? 'Champ ${i + 1}'
                : rawName,
            type: _typeName(f),
            value: _fieldValue(f),
            icon: _typeIcon(f),
          ),
        );
      }
      return result;
    } finally {
      // G16 v1.12.3 — dispose() garanti même si parse Syncfusion throw sur
      // PDF malformé. Avant : leak FD natif sur exceptions.
      doc.dispose();
    }
  }

  String _typeName(PdfField f) {
    if (f is PdfTextBoxField) return 'Texte';
    if (f is PdfCheckBoxField) return 'Case à cocher';
    if (f is PdfRadioButtonListField) return 'Bouton radio';
    if (f is PdfComboBoxField) return 'Liste déroulante';
    if (f is PdfListBoxField) return 'Liste';
    return 'Champ';
  }

  String _fieldValue(PdfField f) {
    if (f is PdfTextBoxField) return f.text.isEmpty ? '—' : f.text;
    if (f is PdfCheckBoxField) return f.isChecked ? '✓ Coché' : '☐ Vide';
    if (f is PdfRadioButtonListField) {
      return f.selectedValue.isEmpty ? '—' : f.selectedValue;
    }
    if (f is PdfComboBoxField) {
      return f.selectedValue.isEmpty ? '—' : f.selectedValue;
    }
    return '—';
  }

  IconData _typeIcon(PdfField f) {
    if (f is PdfTextBoxField) return Icons.text_fields;
    if (f is PdfCheckBoxField) return Icons.check_box_outlined;
    if (f is PdfRadioButtonListField) return Icons.radio_button_checked;
    if (f is PdfComboBoxField) return Icons.arrow_drop_down_circle_outlined;
    return Icons.input;
  }
}
