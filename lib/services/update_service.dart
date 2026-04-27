import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdateService {
  static const _owner   = 'gitubpatrice';
  static const _repo    = 'PDF-TECH';
  static const _current = '1.0.0';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final uri = Uri.parse(
          'https://api.github.com/repos/$_owner/$_repo/releases/latest');
      final response = await http.get(uri, headers: {
        'Accept': 'application/vnd.github+json',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String).replaceFirst('v', '');
      if (!_isNewer(tag, _current)) return null;

      final assets = data['assets'] as List<dynamic>;
      String? apkUrl;
      for (final a in assets) {
        final name = a['name'] as String;
        if (name.endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String;
          break;
        }
      }

      return UpdateInfo(
        version: tag,
        body: data['body'] as String? ?? '',
        apkUrl: apkUrl,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isNewer(String remote, String local) {
    final r = remote.split('.').map(int.tryParse).toList();
    final l = local.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final rv = i < r.length ? (r[i] ?? 0) : 0;
      final lv = i < l.length ? (l[i] ?? 0) : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }
}

class UpdateInfo {
  final String version;
  final String body;
  final String? apkUrl;
  const UpdateInfo({required this.version, required this.body, this.apkUrl});
}
