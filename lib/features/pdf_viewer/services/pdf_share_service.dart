import 'package:pdf_tech/services/share_service.dart';

/// Wrapper découplé autour de [ShareService] pour le partage d'un PDF ouvert
/// dans le viewer.
class PdfShareService {
  final ShareService _share = ShareService();

  Future<void> sharePdf(String path, String title) =>
      _share.sharePdf(path, title);
}
