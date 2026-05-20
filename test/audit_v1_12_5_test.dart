// Tests garde pour l'audit expert PDF Tech v1.12.5.
//
// Verrouille les invariants introduits par les fixes :
//   - D3 : DateFormatUtils.relative (format unifié)
//   - D5 : drift detection AppInfo.version
//
// Un futur refactor qui régresserait ces invariants serait immédiatement
// détecté en CI.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pdf_tech/core/app_info.dart';
import 'package:pdf_tech/utils/date_utils.dart';

void main() {
  group('D3 v1.12.5 — DateFormatUtils.relative', () {
    test('aujourd\'hui retourne "Aujourd\'hui"', () {
      expect(DateFormatUtils.relative(DateTime.now()), "Aujourd'hui");
    });

    test('hier retourne "Hier"', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateFormatUtils.relative(yesterday), 'Hier');
    });

    test('entre J-2 et J-6 retourne "Il y a N jours"', () {
      for (var i = 2; i < 7; i++) {
        final d = DateTime.now().subtract(Duration(days: i));
        expect(DateFormatUtils.relative(d), 'Il y a $i jours');
      }
    });

    test('>= 7 jours retourne dd/MM/yyyy', () {
      final d = DateTime.now().subtract(const Duration(days: 10));
      final expected = DateFormat('dd/MM/yyyy').format(d);
      expect(DateFormatUtils.relative(d), expected);
    });

    test(
      'date dans le futur (clock skew) ne crash pas et retombe sur dd/MM/yyyy',
      () {
        final future = DateTime.now().add(const Duration(days: 365));
        // diff.inDays sera négatif → ne match aucune branche < 7 → format DMY.
        final out = DateFormatUtils.relative(future);
        // Vérifie au minimum qu'on n'est pas en "Aujourd'hui"/"Hier"/"Il y a N jours"
        expect(out.contains('Aujourd'), isFalse);
        expect(out.contains('Hier'), isFalse);
        expect(out.contains('Il y a'), isFalse);
      },
    );
  });

  group('AppInfo — drift detection', () {
    test('AppInfo.version synchro pubspec (v1.12.5)', () {
      expect(
        AppInfo.version,
        '1.12.5',
        reason:
            'AppInfo.version DOIT être bumpée en parallèle de '
            'pubspec.yaml (cf. feedback_appinfo_version_bump.md). Si ce '
            'test fail, la constante a divergé.',
      );
    });
  });
}
