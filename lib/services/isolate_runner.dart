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
/// Note : `Isolate.run` ne propose pas (encore) d'annulation native — le
/// timeout côté caller laisse l'isolate mourir naturellement quand son
/// résultat est ignoré. Pour un vrai cancel, il faudrait passer par
/// `Isolate.spawn` + un port de contrôle.
Future<T> runPdfIsolate<T>(
  FutureOr<T> Function() task, {
  Duration timeout = const Duration(minutes: 2),
}) {
  return Isolate.run(task).timeout(
    timeout,
    onTimeout: () {
      throw TimeoutException('PDF parsing dépasse ${timeout.inSeconds}s');
    },
  );
}
