/// Helper centralisé pour exécuter une tâche dans un Isolate avec un timeout
/// dur. Évite qu'un PDF pathologique (loop interne Syncfusion, fichier
/// corrompu, zip-bomb) ne fige indéfiniment l'UI thread en attendant un
/// résultat qui ne viendra jamais.
///
/// Le timeout par défaut est de 2 minutes — largement suffisant pour les
/// opérations PDF normales (merge/split/compress sur 200 Mo) tout en
/// imposant une limite finie.
///
/// Mutex `max=1` : empêche un pile-up post-timeout (si l'utilisateur lance
/// 3 opérations en série pendant que la 1re hang, on ne spawn pas 3 isolates
/// concurrents qui consomment chacun 200 Mo+ de RAM). Sérialisation native
/// des opérations PDF — elles passent les unes après les autres.
///
/// Note : `Isolate.run` ne propose pas (encore) d'annulation native — le
/// timeout côté caller laisse l'isolate mourir naturellement quand son
/// résultat est ignoré.
library;

import 'dart:async';
import 'dart:isolate';

/// Slot courant occupé (1 isolate vivant max). `null` = libre.
/// Reset à chaque fin (succès ou erreur ou timeout) pour éviter
/// la fuite de Futures chaînés à l'infini sur la durée de vie de l'app
/// (audit fragiles : ancien `_gate = _gate.then(...)` produisait une
/// chaîne permanente — 1000 ops = 1000 closures vivantes).
Completer<void>? _currentOp;

Future<T> runPdfIsolate<T>(
  FutureOr<T> Function() task, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  // Acquire : si une op est déjà en cours, on attend qu'elle se
  // termine (succès ou échec) avant de prendre le verrou. Pattern
  // mutex sériel sans chaîne `then` infinie.
  while (_currentOp != null) {
    try {
      await _currentOp!.future;
    } catch (_) {
      // L'op précédente a échoué — on s'en fiche, on prend le verrou.
    }
  }
  final mySlot = Completer<void>();
  _currentOp = mySlot;
  try {
    final result = await Isolate.run(task).timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException('PDF parsing dépasse ${timeout.inSeconds}s');
      },
    );
    mySlot.complete();
    return result;
  } catch (e, st) {
    mySlot.completeError(e, st);
    rethrow;
  } finally {
    // Release : libère le slot si on est encore le détenteur.
    if (identical(_currentOp, mySlot)) {
      _currentOp = null;
    }
  }
}
