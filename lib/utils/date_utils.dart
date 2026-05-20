/// Utilitaires de formatage de date partagés.
///
/// v1.12.5 (D3) — extrait de `home_screen.dart` et `pdf_folder_screen.dart`
/// (deux implémentations divergentes de la même logique). Pattern unique
/// : "Aujourd'hui / Hier / Il y a N jours / dd/MM/yyyy" + DateFormat
/// `static final` (perf P2.1 v1.12.4 préservée).
library;

import 'package:intl/intl.dart';

class DateFormatUtils {
  DateFormatUtils._();

  // P2.1 v1.12.4 — DateFormat hissé en static final (allocation unique
  // partagée par tous les call sites). Avant : alloué à chaque appel
  // `_formatDate`, invoqué par chaque carte récent/favori au rebuild.
  static final DateFormat _dfDMY = DateFormat('dd/MM/yyyy');

  /// Format relatif : "Aujourd'hui" (J0), "Hier" (J-1), "Il y a N jours"
  /// (J-2..J-6), sinon `dd/MM/yyyy`. Aligné sur la perception UX :
  /// l'utilisateur reconnaît mieux "Il y a 3 jours" que "17/05/2026".
  ///
  /// v1.12.5 (D3 fix) — gestion explicite du clock skew (date future) :
  /// si `diff.inDays < 0` on retombe sur le format absolu pour éviter
  /// "Il y a -365 jours" sur une date corrompue ou un fichier modifié
  /// après l'heure système (cas constaté : restauration backup, NTP).
  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays < 0) return _dfDMY.format(date);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return _dfDMY.format(date);
  }
}
