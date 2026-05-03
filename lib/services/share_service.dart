import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> sharePdf(String path, String name) async {
    await Share.shareXFiles([
      XFile(path, mimeType: 'application/pdf'),
    ], subject: name);
  }

  Future<void> shareByEmail(String path, String name) async {
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf')],
      subject: name,
      text: 'Veuillez trouver le document PDF ci-joint.',
    );
  }
}
