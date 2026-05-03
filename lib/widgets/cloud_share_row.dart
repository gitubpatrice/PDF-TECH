import 'package:files_tech_core/files_tech_core.dart' as core;
import 'package:flutter/material.dart';

/// Wrapper PDF Tech autour de [core.CloudShareRow] : injecte le channel
/// `com.pdftech.pdf_tech/share` et l'alignement center par défaut.
class CloudShareRow extends StatelessWidget {
  final String path;
  final String mime;
  const CloudShareRow({
    super.key,
    required this.path,
    this.mime = 'application/pdf',
  });

  @override
  Widget build(BuildContext context) => core.CloudShareRow(
    path: path,
    mime: mime,
    channelName: 'com.pdftech.pdf_tech/share',
    alignment: WrapAlignment.center,
  );
}
