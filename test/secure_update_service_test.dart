import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tech/services/secure_update_service.dart';

/// `SecureUpdateService` est une **copie locale** de l'`UpdateService` de
/// `files_tech_core`, enrichie d'une vérification de l'empreinte SHA-256 de
/// l'APK. Corriger le paquet partagé ne la corrige donc pas : c'est un jumeau,
/// et un jumeau se répare séparément.
///
/// Les quatre défauts trouvés dans le paquet partagé le 2026-08-11 étaient
/// présents ici **ligne pour ligne**. Ces tests épinglent le plus insidieux :
/// une comparaison de versions qui pouvait proposer une **rétrogradation**.
void main() {
  group('comparaison de versions', () {
    test('une version distante plus récente est détectée', () {
      expect(SecureUpdateService.isNewer('1.13.6', '1.13.5'), isTrue);
      expect(SecureUpdateService.isNewer('1.14.0', '1.13.9'), isTrue);
      expect(SecureUpdateService.isNewer('2.0.0', '1.99.99'), isTrue);
    });

    test('une version identique ou plus ancienne ne l\'est pas', () {
      expect(SecureUpdateService.isNewer('1.13.5', '1.13.5'), isFalse);
      expect(SecureUpdateService.isNewer('1.13.4', '1.13.5'), isFalse);
    });

    test('une version locale SUFFIXÉE ne provoque pas de rétrogradation', () {
      // LE test de ce fichier.
      //
      // Chaque composant illisible valait `0` (`int.tryParse(...) ?? 0`). Sur
      // une version locale `1.13.5-beta`, le dernier composant tombait donc à
      // zéro, et `1.13.4` passait pour plus récent : l'application proposait
      // d'installer une version ANTÉRIEURE, présentée comme une mise à jour.
      //
      // `AppInfo.version` vaut aujourd'hui un `X.Y.Z` propre, donc le défaut ne
      // mordait pas — mais rien dans le code ne l'imposait, et une version de
      // pré-publication suffisait à le réveiller.
      for (final local in <String>['1.13.5-beta', '1.13.5+7', '1.13.5-rc.1']) {
        expect(
          SecureUpdateService.isNewer('1.13.4', local),
          isFalse,
          reason: 'local « $local » : rétrogradation proposée',
        );
      }
    });

    test('une version illisible ne propose rien', () {
      // Repli sûr : proposer une mise à jour qu'on ne sait pas comparer, c'est
      // risquer de proposer une rétrogradation.
      for (final paire in <List<String>>[
        ['', '1.13.5'],
        ['1.13.5', ''],
        ['abc', '1.13.5'],
        ['1.13', '1.13.5'],
        ['1.13.5.1', '1.13.5'],
      ]) {
        expect(
          SecureUpdateService.isNewer(paire[0], paire[1]),
          isFalse,
          reason: '« ${paire[0]} » contre « ${paire[1]} »',
        );
      }
    });

    test('un composant démesuré est refusé, pas converti', () {
      final enorme = '${'9' * 50000}.0.0';
      final chrono = Stopwatch()..start();
      expect(SecureUpdateService.isNewer(enorme, '1.13.5'), isFalse);
      chrono.stop();
      expect(chrono.elapsedMilliseconds, lessThan(200));
    });
  });

  group('bornes de la requête', () {
    test('le plafond de réponse est fixe et modeste', () {
      expect(SecureUpdateService.maxResponseBytes, 512 * 1024);
    });

    test('un seul hôte est accepté, y compris après redirection', () {
      expect(SecureUpdateService.allowedHosts, {'api.github.com'});
    });
  });
}
