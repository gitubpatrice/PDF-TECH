import 'dart:async';
import 'dart:isolate';

/// Helper centralisé pour exécuter une tâche dans un Isolate avec un timeout
/// dur. Évite qu'un PDF pathologique (loop interne Syncfusion, fichier
/// corrompu, zip-bomb) ne fige indéfiniment l'UI thread en attendant un
/// résultat qui ne viendra jamais.
///
/// Le timeout par défaut est de 2 minutes — largement suffisant pour les
/// opérations PDF normales (merge/split/compress sur 200 Mo) tout en
/// imposant une limite finie. Lever un [TimeoutException] permet à
/// l'appelant de l'attraper et d'afficher un message clair à l'utilisateur.
///
/// Mutex `max=1` : empêche un pile-up post-timeout (si l'utilisateur lance
/// 3 opérations en série pendant que la 1re hang, on ne spawn pas 3 isolates
/// concurrents qui consomment chacun 200 Mo+ de RAM). Sérialisation native
/// des opérations PDF — elles passent les unes après les autres.
///
/// Note : `Isolate.run` ne propose pas (encore) d'annulation native — le
/// timeout côté caller laisse l'isolate mourir naturellement quand son
/// résultat est ignoré. Pour un vrai cancel, il faudrait passer par
/// `Isolate.spawn` + un port de contrôle.
Future<void> _gate = Future<void>.value();

Future<T> runPdfIsolate<T>(
  FutureOr<T> Function() task, {
  Duration timeout = const Duration(minutes: 2),
}) {
  final completer = Completer<T>();
  _gate = _gate.then((_) async {
    try {
      final result = await Isolate.run(task).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('PDF parsing dépasse ${timeout.inSeconds}s');
        },
      );
      completer.complete(result);
    } catch (e, st) {
      completer.completeError(e, st);
    }
  });
  return completer.future;
}
