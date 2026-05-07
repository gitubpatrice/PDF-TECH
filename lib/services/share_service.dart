import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> sharePdf(String path, String name) async {
    await Share.shareXFiles([
      XFile(path, mimeType: 'application/pdf'),
    ], subject: name);
  }
}
