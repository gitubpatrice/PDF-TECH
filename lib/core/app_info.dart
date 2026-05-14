/// Source unique de vérité pour les méta-données de l'app.
/// Évite la duplication entre `about_screen` et `app_update`.
library;

class AppInfo {
  AppInfo._();

  /// Version de l'app, alignée sur `pubspec.yaml`.
  /// **Ne jamais bumper sans bumper aussi `pubspec.yaml`.**
  static const String version = '1.12.4';

  /// Nombre d'outils PDF accessibles depuis le grid + viewer (annoter,
  /// lecture). Mis à jour si une tuile est ajoutée/retirée.
  static const int toolsCount = 23;

  /// URL du dépôt GitHub.
  static const String githubUrl = 'https://github.com/gitubpatrice/PDF-TECH';
}
