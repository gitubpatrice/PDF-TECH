import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_tech/utils/snack_utils.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Widget encapsulant [SfPdfViewer] avec le filtre night mode et la gestion
/// basique des événements document.
class PdfDocumentViewer extends StatelessWidget {
  final String path;
  final PdfViewerController controller;
  final String? password;
  final bool nightMode;
  final int passwordAttempt;
  final void Function(PdfDocumentLoadedDetails) onDocumentLoaded;
  final void Function(PdfPageChangedDetails) onPageChanged;
  final VoidCallback onAnnotationChanged;
  final void Function(bool isWrong) onPasswordRequested;

  const PdfDocumentViewer({
    super.key,
    required this.path,
    required this.controller,
    this.password,
    required this.nightMode,
    required this.passwordAttempt,
    required this.onDocumentLoaded,
    required this.onPageChanged,
    required this.onAnnotationChanged,
    required this.onPasswordRequested,
  });

  @override
  Widget build(BuildContext context) {
    final viewer = SfPdfViewer.file(
      File(path),
      controller: controller,
      password: password,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onDocumentLoadFailed: (details) {
        // Ne PAS loguer `password` ni `details.description`.
        final desc = details.description.toLowerCase();
        final isPassword =
            desc.contains('password') ||
            desc.contains('encrypt') ||
            desc.contains('mot de passe');
        if (isPassword) {
          onPasswordRequested(password != null);
        } else {
          showErrorSnack(context, 'Impossible d\'ouvrir le PDF');
        }
      },
      onDocumentLoaded: onDocumentLoaded,
      onPageChanged: onPageChanged,
      onAnnotationAdded: (_) => onAnnotationChanged(),
      onAnnotationEdited: (_) => onAnnotationChanged(),
      onAnnotationRemoved: (_) => onAnnotationChanged(),
      onFormFieldValueChanged: (_) => onAnnotationChanged(),
    );

    // Reconstruit le sous-arbre quand le password change pour forcer
    // Syncfusion à relancer le décodage avec le nouveau mot de passe.
    return KeyedSubtree(
      key: ValueKey('pdf_attempt_$passwordAttempt'),
      child: nightMode
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                -1,
                0,
                0,
                0,
                255,
                0,
                -1,
                0,
                0,
                255,
                0,
                0,
                -1,
                0,
                255,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: viewer,
            )
          : viewer,
    );
  }
}
