import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

/// Version chiffree de [UpdateService] : le cache de verification de mise a
/// jour est stocke dans [FlutterSecureStorage] au lieu de [SharedPreferences].
class SecureUpdateService {
  final String owner;
  final String repo;
  final String currentVersion;
  final Duration cacheDuration;

  const SecureUpdateService({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    this.cacheDuration = const Duration(hours: 12),
  });

  String get _cacheKey => 'secure_update_last_check_ms_$repo';

  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final last = await SecureStorageService.readInt(_cacheKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now - last < cacheDuration.inMilliseconds) return null;

      final uri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );
      final response = await http
          .get(uri, headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      await SecureStorageService.writeInt(_cacheKey, now);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final tagRaw = data['tag_name'];
      if (tagRaw is! String) return null;
      final tag = tagRaw.replaceFirst(RegExp(r'^v'), '');
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(tag)) return null;
      if (!_isNewer(tag, currentVersion)) return null;

      String? apkUrl;
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is! Map) continue;
          final name = a['name'];
          final url = a['browser_download_url'];
          if (name is! String || url is! String) continue;
          if (!name.toLowerCase().endsWith('.apk')) continue;
          final u = Uri.tryParse(url);
          if (u == null || u.scheme != 'https') continue;
          if (u.host != 'github.com' &&
              u.host != 'objects.githubusercontent.com') {
            continue;
          }
          apkUrl = url;
          break;
        }
      }

      final body = data['body'] is String ? data['body'] as String : '';
      return UpdateInfo(
        version: tag,
        body: body,
        apkUrl: apkUrl,
        expectedSha256: _extractSha256(body),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureUpdateService] checkForUpdate error: $e');
      }
      return null;
    }
  }

  static String? _extractSha256(String body) {
    final match = RegExp(
      r'sha-?256\s*[:=]\s*([0-9a-fA-F]{64})',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1)?.toLowerCase();
  }

  static bool isNewer(String remote, String local) => _isNewer(remote, local);

  static bool _isNewer(String remote, String local) {
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
  final String? expectedSha256;

  const UpdateInfo({
    required this.version,
    required this.body,
    this.apkUrl,
    this.expectedSha256,
  });
}
