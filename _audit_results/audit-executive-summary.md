# Rapport d’Audit Sécurité Mobile — PDF Tech v1.13.3

**Date** : 2026-08-01  
**Application** : PDF Tech v1.13.3  
**Plateforme** : Flutter (Dart) + Android natif (Kotlin)  
**Scope** : code source de `J:/applications/pdf_tech`, dépendance `files_tech_core`, APK release `pdf-tech-universel-1.13.3.apk`  
**Méthodologie** : OWASP Mobile Top 10 (2024) + audit de code source statique + tests de pénétration défensifs (boîte blanche).

---

## Score global

| Rapport | Score |
|---|---|
| Audit de code source | 68/100 |
| Évaluation OWASP Mobile Top 10 | 66/100 |
| Tests de pénétration | ~67/100 |
| **Score consolidé** | **67/100** |

**Verdict** : posture défensive globalement **correcte pour une app PDF offline et open-source**, avec des points forts solides (pas de secrets applicatifs, no cleartext, no backup, FileProvider restreint, anti path-traversal, AES-256). Les points bloquants concernent presque exclusivement la **gestion des secrets de signature** et la **permission d’accès universel au stockage**. Ce sont des problèmes de configuration / opérations, pas des failles de logique applicative.

---

## Synthèse des findings (dédupliqués)

| Sévérité | Nombre | Type principal |
|---|---|---|
| Critique | 1 | Secrets de signature en clair dans le working tree |
| Haute | 2 | Fallback signing debug + `MANAGE_EXTERNAL_STORAGE` |
| Moyenne | 4 | Signature v1 Janus, `debugPrint` non protégés, API stockage dépréciées, messages d’erreur bruts |
| Basse | 3 | Métadonnées récentes en clair, erreurs silencieuses update, autres points mineurs |
| Info | 4 | `minSdk` non pinné, absence de pinning TLS, composants standard AndroidX, logging crypto justifié |

---

## Top 5 actions prioritaires

| # | Action | Sévérité | Effort | Fichier(s) concerné(s) |
|---|---|---|---|---|
| 1 | Supprimer `android/key.properties` et `android/app/keystore.jks` du working tree local ; ne conserver les secrets de signature que dans le coffre-fort CI (GitHub Actions secrets). | Critique | < 1h | `android/key.properties`, `android/app/keystore.jks` |
| 2 | Interdire le fallback signing debug en build release. Faire échouer le build release si les credentials release sont absents. | Haute | < 1h | `android/app/build.gradle.kts` |
| 3 | Réduire la dépendance à `MANAGE_EXTERNAL_STORAGE` : privilégier le Storage Access Framework par défaut, documenter la justification pour F-Droid. | Haute | 1 jour | `AndroidManifest.xml`, `storage_permission_service.dart`, picker PDF |
| 4 | Désactiver `enableV1Signing` (attaque Janus) si la compatibilité API < 24 n’est pas indispensable. | Moyenne | < 1h | `android/app/build.gradle.kts` |
| 5 | Protéger les `debugPrint` par `if (kDebugMode)` pour éviter la fuite de paths utilisateur en logcat release. | Moyenne | < 1h | `lib/widgets/pdf_picker_screen.dart`, `lib/utils/saf_picker.dart` |

---

## Findings détaillés (dédupliqués)

### 1 — Secrets de signature en clair dans le working tree (Critique)
- **Fichier** : `android/key.properties:1-2` + `android/app/keystore.jks`
- **Description** : mots de passe du keystore et fichier binaire keystore présents localement en clair.
- **Impact** : toute personne ayant accès au poste de développement peut signer des APK frauduleux sous l’identité PDF Tech.
- **Remédiation** : supprimer les fichiers du working tree, utiliser uniquement des variables d’environnement / GitHub Actions secrets en CI. S’assurer qu’ils sont bien dans `.gitignore` et dans les backups interdits.

### 2 — Fallback signing debug en release (Haute)
- **Fichier** : `android/app/build.gradle.kts:100-108`
- **Description** : si les credentials release manquent, le build release est signé avec la clé debug Android.
- **Impact** : un APK release signé debug peut être remplacé par n’importe quel autre APK debug.
- **Remédiation** : supprimer le fallback debug et faire échouer le build si les credentials release sont absents.

### 3 — Permission `MANAGE_EXTERNAL_STORAGE` (Haute)
- **Fichier** : `AndroidManifest.xml:11-12`, `storage_permission_service.dart`
- **Description** : accès universel au stockage partagé déclaré.
- **Impact** : si une partie du code Dart est compromise, la permission permet de lire/écrire presque partout sur le stockage externe.
- **Remédiation** : privilégier le Storage Access Framework (SAF), documenter la justification pour F-Droid, évaluer si le scan direct de `Download` est encore nécessaire.

### 4 — Signature APK v1 activée (attaque Janus) (Moyenne)
- **Fichier** : `android/app/build.gradle.kts:52-54`
- **Description** : `enableV1Signing = true` en parallèle de v2/v3.
- **Impact** : la signature v1 est vulnérable à l’attaque Janus.
- **Remédiation** : passer `enableV1Signing = false` si la compatibilité API < 24 n’est pas indispensable.

### 5 — `debugPrint` non protégés en release (Moyenne)
- **Fichier** : `lib/widgets/pdf_picker_screen.dart`, `lib/utils/saf_picker.dart`
- **Description** : des chemins absolus de fichiers utilisateurs peuvent être loggués dans logcat en release.
- **Impact** : fuite de métadonnées (noms de fichiers, paths).
- **Remédiation** : entourer chaque `debugPrint` par `if (kDebugMode)` ou supprimer les logs non essentiels.

### 6 — Utilisation d’APIs de stockage externe dépréciées (Moyenne)
- **Fichier** : `MainActivity.kt:214`, `pdf_picker_screen.dart`, `home_tab.dart`
- **Description** : `Environment.getExternalStorageDirectory()` / `getExternalStorageDirectory()` (deprecated API 29).
- **Impact** : fragilité face au Scoped Storage, dépendance accrue à `MANAGE_EXTERNAL_STORAGE`.
- **Remédiation** : migrer vers `StorageManager` / `StorageStatsManager` ou utiliser exclusivement SAF / `getExternalFilesDirectory()`.

### 7 — Messages d’erreur bruts dans Google Drive (Basse)
- **Fichier** : `lib/screens/cloud/google_drive_screen.dart`
- **Description** : les exceptions sont affichées telles quelles dans les Snackbars.
- **Impact** : fuite possible d’URLs, messages internes ou détails de configuration.
- **Remédiation** : afficher un message générique à l’utilisateur et logguer l’erreur uniquement en `kDebugMode`.

### 8 — Métadonnées de fichiers en clair dans `SharedPreferences` (Basse)
- **Fichier** : `last_page_service.dart`, `main.dart`, `files_tech_core/lib/src/recents/recent_files_service.dart`
- **Description** : chemins, noms, tailles et dates des fichiers récents sont stockés dans `SharedPreferences` non chiffré.
- **Impact** : sur un appareil rooté ou backup, un nom de fichier révélateur peut être lu.
- **Remédiation** : évaluer la sensibilité des paths ; si besoin, migrer vers `flutter_secure_storage` ou chiffrer la liste localement.

### 9 — Erreurs silencieuses sur le check de mise à jour (Basse)
- **Fichier** : `files_tech_core/lib/src/update/update_service.dart`
- **Description** : toutes les erreurs du check de mise à jour sont absorbées.
- **Impact** : difficulté à détecter un MITM ou un compte GitHub compromis publiant un payload inattendu.
- **Remédiation** : ajouter un log conditionnel en `kDebugMode` ou un callback `onError` optionnel.

### 10 — `minSdk` non pinné explicitement (Info)
- **Fichier** : `android/app/build.gradle.kts:61`
- **Description** : `minSdk = flutter.minSdkVersion` dépend du SDK Flutter.
- **Remédiation** : pinner explicitement `minSdk = 24`.

### 11 — Absence de pinning de certificat pour GitHub (Info)
- **Fichier** : `files_tech_core/lib/src/update/update_service.dart`
- **Description** : le check de mise à jour utilise HTTPS classique sans pinning.
- **Remédiation** : envisager du pinning de clé publique pour `api.github.com` et `objects.githubusercontent.com` si le threat model le justifie.

### 12 — Composants standard AndroidX / Google (Info)
- **Description** : `ProfileInstallReceiver`, `RevocationBoundService`, `ShareFileProvider` sont présents mais `exported="false"` ou protégés par permission système.
- **Remédiation** : aucune — conforme.

---

## Points conformes notables

| Domaine | Preuve dans le code |
|---|---|
| Backup / Cloud extraction | `allowBackup="false"`, `fullBackupContent="false"`, `data_extraction_rules.xml` |
| Trafic réseau | `usesCleartextTraffic="false"`, `network_security_config.xml` sans cleartext |
| Obfuscation build release | `isMinifyEnabled = true`, `isShrinkResources = true`, `proguard-rules.pro` |
| FileProvider | `exported="false"`, authority basée sur `applicationId`, `file_paths.xml` restreint |
| Validation des intents entrants | `isAllowedPath()`, canonicalisation, whitelist packages cloud |
| Partage de fichiers | `content://` via `FileProvider`, `FLAG_GRANT_READ_URI_PERMISSION` |
| `FLAG_SECURE` | `secure_window.dart` + `MainActivity.kt` |
| Mots de passe PDF | `PdfEncryptionAlgorithm.aesx256Bit`, owner password aléatoire 32 caractères |
| Lecture PDF | `safeReadPdf()` : cap 200 Mo, validation magic bytes `%PDF-` |
| Écriture atomique | `atomicWriteBytes()` : tmp + rename + flush |
| OAuth Google Drive | Scope restreint `drive.file`, `disconnect()` révoque le refresh token |
| Anti path-traversal | `resolveSafePdfName()` côté natif, `_sanitizeFileName()` côté Dart |
| Secrets dans le code source | Aucune clé API, token, mot de passe applicatif ou clé privée trouvée |
| Dépendances | Versions récentes, `osv-scanner` en CI hebdomadaire |

---

## Fichiers produits

| Rapport | Chemin |
|---|---|
| Rapport exécutif consolidé | `J:/applications/pdf_tech/_audit_results/audit-executive-summary.md` |
| Audit de code source complet | `J:/applications/pdf_tech/_audit_results/code-audit-report.md` |
| Évaluation OWASP Mobile Top 10 | `J:/applications/pdf_tech/_audit_results/owasp-report.md` |
| Tests de pénétration | `J:/applications/pdf_tech/_audit_results/pentest-report.md` |
| Rapport HTML consolidé (généré automatiquement, score non dédupliqué) | `J:/applications/pdf_tech/_audit_results/audit-final.html` |
| Rapport Markdown consolidé (généré automatiquement, score non dédupliqué) | `J:/applications/pdf_tech/_audit_results/audit-final.md` |

---

## Recommandation finale

Avant de considérer PDF Tech comme **suffisamment durci pour une distribution de confiance**, il faut corriger les 5 actions prioritaires ci-dessus. Les deux premières (secrets de signature + fallback debug) sont **bloquantes** et doivent être traitées immédiatement. Les autres sont des durcissements progressifs.

L’application est déjà **fiable fonctionnellement** (tests OK, OCR stable, picker robuste), mais elle n’est pas encore **sûre opérationnellement** tant que les secrets de signature sont sur le poste de développement.
