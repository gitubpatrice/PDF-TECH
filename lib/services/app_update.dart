import 'package:files_tech_core/files_tech_core.dart';

/// Instance partagée de [UpdateService] configurée pour PDF Tech.
/// La version doit rester synchronisée avec `pubspec.yaml` et
/// `AboutScreen._version`.
const appUpdateService = UpdateService(
  owner: 'gitubpatrice',
  repo: 'PDF-TECH',
  currentVersion: '1.8.0',
);
