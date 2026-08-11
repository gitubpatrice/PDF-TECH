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
      final corps = await _fetch(uri);
      if (corps == null) return null;

      final Map<String, dynamic> data;
      try {
        final decode = jsonDecode(corps);
        if (decode is! Map<String, dynamic>) return null;
        data = decode;
      } on FormatException {
        return null;
      }

      // Le cache n'est marque qu'ICI, une fois la reponse reellement comprise.
      //
      // Il l'etait auparavant juste apres le controle du code HTTP, donc AVANT
      // `jsonDecode`. Un « 200 » accompagne d'une page HTML — le cas ordinaire
      // d'un portail captif Wi-Fi — marquait la verification comme faite, et
      // plus aucun controle n'avait lieu pendant douze heures, meme une fois la
      // connexion redevenue normale.
      await SecureStorageService.writeInt(_cacheKey, now);

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

  /// Plafond de la reponse acceptee, en octets.
  ///
  /// Une release GitHub tient dans quelques kilo-octets. `response.body` lisait
  /// TOUT en memoire sans borne : un intermediaire — proxy d'entreprise,
  /// autorite installee sur l'appareil, portail captif — pouvait faire avaler
  /// une reponse de plusieurs centaines de megaoctets.
  static const int maxResponseBytes = 512 * 1024;

  /// Hotes acceptes, y compris **apres redirection**.
  ///
  /// `http.get` suit les redirections seul et ne revalide ni l'hote ni le
  /// schema : un `302` vers un autre hote — ou vers `http://` en clair —
  /// alimentait l'application avec un JSON d'origine quelconque.
  static const Set<String> allowedHosts = {'api.github.com'};

  /// Recupere le corps de la reponse, ou `null` si quoi que ce soit cloche.
  ///
  /// Les redirections sont suivies **a la main**, pour revalider l'hote et le
  /// schema a chaque saut.
  /// Duree maximale de TOUTE l'operation, redirections et lecture du corps
  /// comprises.
  ///
  /// Le delai ne portait d'abord que sur `client.send`, c'est-a-dire sur
  /// l'obtention des en-tetes. Un serveur repondant « 200 » aussitot puis
  /// n'envoyant plus rien laissait la lecture attendre indefiniment. C'etait
  /// une REGRESSION par rapport a `http.get(...).timeout(...)`, qui englobait
  /// la lecture de `response.body`. Signalee par la relecture GPT du
  /// 2026-08-11.
  static const Duration budgetTotal = Duration(seconds: 20);

  /// Delai maximal entre deux fragments recus.
  static const Duration budgetParFragment = Duration(seconds: 10);

  static Future<String?> _fetch(Uri uri) async {
    final client = http.Client();
    final echeance = DateTime.now().add(budgetTotal);
    Duration reste() {
      final r = echeance.difference(DateTime.now());
      return r.isNegative ? Duration.zero : r;
    }

    try {
      var cible = uri;
      for (var saut = 0; saut < 5; saut++) {
        if (cible.scheme != 'https' || !allowedHosts.contains(cible.host)) {
          return null;
        }
        if (reste() == Duration.zero) return null;
        final requete = http.Request('GET', cible)
          ..followRedirects = false
          ..headers['Accept'] = 'application/vnd.github+json';
        final reponse = await client.send(requete).timeout(reste());

        if (reponse.isRedirect) {
          final vers = reponse.headers['location'];
          // Un `Location` vide se resout sur l'URL courante : sans ce
          // controle, une redirection vide faisait cinq requetes identiques
          // avant d'abandonner.
          if (vers == null || vers.isEmpty) {
            await reponse.stream.drain<void>();
            return null;
          }
          cible = cible.resolve(vers);
          await reponse.stream.drain<void>();
          continue;
        }
        if (reponse.statusCode != 200) {
          await reponse.stream.drain<void>();
          return null;
        }
        final annonce = reponse.contentLength;
        if (annonce != null && annonce > maxResponseBytes) {
          await reponse.stream.drain<void>();
          return null;
        }

        final octets = <int>[];
        await for (final tranche in reponse.stream.timeout(budgetParFragment)) {
          if (DateTime.now().isAfter(echeance)) return null;
          // La borne est verifiee AVANT d'ajouter le fragment. Elle l'etait
          // apres : un serveur envoyant un seul fragment de 600 Ko le faisait
          // donc entierement allouer avant d'etre refuse.
          if (octets.length + tranche.length > maxResponseBytes) return null;
          octets.addAll(tranche);
        }
        return utf8.decode(octets, allowMalformed: true);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static bool _isNewer(String remote, String local) {
    final r = _composants(remote);
    final l = _composants(local);
    // Une version illisible d'un cote ou de l'autre ne permet AUCUNE
    // comparaison. Proposer une mise a jour dans le doute, c'est risquer de
    // proposer une retrogradation ; ne rien proposer est le repli sur.
    if (r == null || l == null) return false;
    for (var i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  /// Les trois composants de [version], ou `null` si ce n'est pas un `X.Y.Z`
  /// strict.
  ///
  /// **Pourquoi refuser plutot que combler.** Chaque composant illisible valait
  /// `0` (`int.tryParse(...) ?? 0`). Une version locale suffixee — `1.2.3-beta`,
  /// `1.2.3+4` — voyait donc son dernier composant ramene a zero, et `1.2.2`
  /// passait pour plus recent que `1.2.3-beta` : l'application proposait une
  /// **retrogradation** presentee comme une mise a jour.
  ///
  /// `AppInfo.version` vaut aujourd'hui un `X.Y.Z` propre, donc le defaut ne
  /// mordait pas — mais rien dans le code ne l'imposait.
  static List<int>? _composants(String version) {
    final parts = version.split('.');
    if (parts.length != 3) return null;
    final out = <int>[];
    for (final p in parts) {
      if (p.isEmpty || p.length > 9) return null;
      final v = int.tryParse(p);
      if (v == null || v < 0) return null;
      out.add(v);
    }
    return out;
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
