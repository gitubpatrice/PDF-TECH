# Audit de Code Source — PDF Tech v1.13.3

**Date** : 2026-08-01  
**Scope** : `J:/applications/pdf_tech` + dépendance path `J:/applications/files_tech_core`  
**Plateforme** : Flutter (Dart) + Android natif (Kotlin)  
**APK release auditée** : `build/app/outputs/flutter-apk/pdf-tech-universel-1.13.3.apk`  
**Fichiers analysés** : 271 fichiers suivis par git + code source natif et dépendance partagée  
**Auditeur** : Agent Code Audit (analyse statique)

---

## Résumé

| Indicateur | Valeur |
|---|---|
| **Fichiers analysés** | ~271 (git) + sources natifs + `files_tech_core` |
| **Vulnérabilités trouvées** | 1 Critique, 2 Hautes, 4 Moyennes, 3 Basses, 4 Info |
| **Score de sécurité du code** | **68/100** |

**Verdict global** : Le code est globalement bien durci pour une application PDF offline : validation des intents entrants, FileProvider restreint, anti-path-traversal, FLAG_SECURE, pas de cleartext traffic, pas de backup, pas de secrets hardcodés dans le code source, et une bonne hygiène de gestion des mots de passe PDF. Les points bloquants concernent presque exclusivement la **gestion des secrets de signature** et la **permission d'accès universel au stockage**. Ce sont des problèmes opérationnels / configurationnels, pas des failles de logique applicative.

---

## Configuration & Manifeste

| Paramètre | Valeur actuelle | Valeur recommandée / Évaluation | Sévérité |
|---|---|---|---|
| `android:allowBackup` | `false` | `false` — conforme | ✅ Info |
| `android:fullBackupContent` | `false` | `false` — conforme | ✅ Info |
| `dataExtractionRules` | Exclut tous les domaines | Conforme | ✅ Info |
| `android:usesCleartextTraffic` | `false` | `false` — conforme | ✅ Info |
| `networkSecurityConfig` | `@xml/network_security_config` | Présent, cleartext interdit, ancrages système — conforme | ✅ Info |
| `android:debuggable` | Non présent (défaut `false`) | `false` — conforme | ✅ Info |
| `MainActivity android:exported` | `true` | Obligatoire pour `LAUNCHER`, `ACTION_VIEW` et `ACTION_SEND` PDF — acceptable avec validation côté natif | ✅ Info |
| `FileProvider android:exported` | `false` | `false` — conforme | ✅ Info |
| `FileProvider android:grantUriPermissions` | `true` | Nécessaire pour le partage de PDF — acceptable avec `file_paths.xml` restreint | ✅ Info |
| `minSdk` | `flutter.minSdkVersion` (actuellement 24) | Pinner explicitement la valeur | ℹ️ Info |
| `targetSdk` | `35` | À jour — conforme | ✅ Info |
| `compileSdk` | `36` | À jour — conforme | ✅ Info |
| `isMinifyEnabled` / `isShrinkResources` | `true` / `true` | Conforme | ✅ Info |
| `enableV1Signing` | `true` | Désactiver si compatibilité v1 non requise | Moyenne |
| `enableV2Signing` / `enableV3Signing` | `true` / `true` | Conforme | ✅ Info |
| Fallback signing debug en release | Activé | Interdire le fallback debug | Haute |

---

## Permissions

| Permission | Utilisée dans | Nécessaire ? | Recommandation |
|---|---|---|---|
| `INTERNET` | `AndroidManifest.xml:5` | Oui (mise à jour GitHub, Google Drive) | OK |
| `MANAGE_EXTERNAL_STORAGE` | `AndroidManifest.xml:11`, `storage_permission_service.dart` | Partiellement justifiée pour un gestionnaire/lecteur de PDFs hors Play Store | Haute — réduire la surface ou documenter pour F-Droid |

**Observations** :
- Seule `INTERNET` et `MANAGE_EXTERNAL_STORAGE` sont déclarées explicitement.
- Les plugins ajoutent des composants standards (receiver `ProfileInstallReceiver`, service `RevocationBoundService`, provider `ShareFileProvider`) qui sont tous `exported="false"` ou protégés par des permissions système. Ce ne sont pas des vulnérabilités.

---

## Secrets Détectés

| # | Type | Fichier:Ligne | Extrait | Sévérité |
|---|---|---|---|---|
| 1 | Mot de passe keystore en clair | `android/key.properties:1` | `storePassword=***REDACTED*** | Critique |
| 2 | Mot de passe de clé en clair | `android/key.properties:2` | `keyPassword=***REDACTED*** | Critique |
| 3 | Fichier keystore JKS présent | `android/app/keystore.jks` | Fichier binaire de 2 752 octets | Critique |

**Précision importante** : `key.properties` et `keystore.jks` sont bien listés dans `.gitignore` et ne sont **pas** suivis par git. Cependant, ils sont présents dans le working tree local. Toute archive, backup, snapshot ou exfiltration du répertoire de travail emporterait les secrets de signature.

**Aucun autre secret** (clé API, token, mot de passe applicatif, URL avec credentials, clé privée) n'a été trouvé dans le code source Dart/Kotlin/XML/YAML/JSON.

---

## Dépendances à Risque

| Dépendance | Version lockée | Dernière version connue | Risque | CVE |
|---|---|---|---|---|
| `syncfusion_flutter_pdf` | 33.2.13 | 33.2.13 | Faible | Aucune identifiée |
| `syncfusion_flutter_pdfviewer` | 33.2.13 | 33.2.13 | Faible | Aucune identifiée |
| `syncfusion_flutter_signaturepad` | 33.2.13 | 33.2.13 | Faible | Aucune identifiée |
| `pdfrx` | 2.4.7 | 2.4.7 | Faible | Aucune identifiée |
| `pdfrx_engine` | 0.4.6 | 0.4.6 | Faible | Aucune identifiée |
| `flutter_tesseract_ocr` | 0.4.31 | 0.4.31 | Faible | Aucune identifiée |
| `google_sign_in` | 6.3.0 | 6.3.0 | Faible | Aucune identifiée |
| `googleapis` | 13.2.0 | 13.2.0 | Faible | Aucune identifiée |
| `http` | 1.6.0 | 1.6.0 | Faible | Aucune identifiée |
| `permission_handler` | 12.0.3 | 12.0.3 | Faible | Aucune identifiée |
| `file_picker` | 11.0.2 | 11.0.2 | Faible | Aucune identifiée |
| `share_plus` | 10.1.4 | 10.1.4 | Faible | Aucune identifiée |
| `shared_preferences` | 2.5.5 | 2.5.5 | Faible | Aucune identifiée |
| `url_launcher` | 6.3.2 | 6.3.2 | Faible | Aucune identifiée |
| `intl` | 0.20.0 | 0.20.0 | Faible | Aucune identifiée |
| `files_tech_core` | 0.3.4 (path) | — | Dépendance maîtrisée | Aucune |

**Note** : Les dépendances sont globalement à jour. Le workflow `.github/workflows/security.yml` exécute `osv-scanner` hebdomadairement pour détecter les CVE dans les dépendances pub. C'est une bonne pratique.

---

## Vulnérabilités dans le Code

### Finding #1 — Secrets de signature en clair dans le working tree
- **Type** : Secret exposé
- **Sévérité** : Critique
- **Fichier** : `android/key.properties:1-2` et `android/app/keystore.jks`
- **Description** : Les mots de passe du keystore et de la clé sont stockés en clair dans `key.properties`, et le fichier binaire `keystore.jks` est présent dans le répertoire Android. Même si ces fichiers sont dans `.gitignore`, leur présence dans le working tree expose la clé de signature de l'éditeur.
- **Impact** : Toute personne ayant accès au poste de développement peut signer des APK frauduleux avec la clé de PDF Tech. Cela invalide complètement la chaîne de confiance des releases GitHub/F-Droid.
- **Code actuel** :
  ```properties
  # android/key.properties
  storePassword=***REDACTED***
  keyPassword=***REDACTED***
  keyAlias=pdf_studio
  storeFile=keystore.jks
  ```
- **Code corrigé** : Le fichier `key.properties` et le keystore ne doivent jamais être présents localement en clair. Utiliser uniquement des variables d'environnement en CI (déjà partiellement fait dans `build.gradle.kts`) et un coffre-fort chiffré (GitHub Actions secrets, Azure Key Vault, etc.).
  ```properties
  # android/key.properties — SUPPRIMER ce fichier du working tree
  # Ne jamais stocker les credentials localement.
  ```
  ```kotlin
  // android/app/build.gradle.kts
  // La logique actuelle lit déjà les env vars PDFTECH_* en priorité.
  // S'assurer que le build release ÉCHOUE si elles sont absentes.
  ```
- **Effort** : Rapide (< 1h) — supprimer les fichiers et documenter la procédure CI.

---

### Finding #2 — Fallback signing debug en build release
- **Type** : Config vulnérable
- **Sévérité** : Haute
- **Fichier** : `android/app/build.gradle.kts:100-108`
- **Description** : Si les credentials release ne sont pas disponibles, le build release est signé avec la clé debug Android.
- **Code actuel** :
  ```kotlin
  buildTypes {
      release {
          signingConfig = if (keyPropertiesFile.exists() ||
              System.getenv("PDFTECH_STORE_PASSWORD") != null) {
              signingConfigs.getByName("release")
          } else {
              signingConfigs.getByName("debug")
          }
          ...
      }
  }
  ```
- **Impact** : Un APK release signé debug peut être remplacé/écrasé par n'importe quel autre APK debug sur un appareil. Si ce type d'artefact est publié par erreur, il constitue un incident de sécurité majeur.
- **Code corrigé** :
  ```kotlin
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("release")
          ...
      }
  }
  ```
  Et dans la configuration de la config release, faire échouer le build si les credentials manquent :
  ```kotlin
  create("release") {
      val alias = keyProp("PDFTECH_KEY_ALIAS", "keyAlias")
      val kPass = keyProp("PDFTECH_KEY_PASSWORD", "keyPassword")
      val sFile = keyProp("PDFTECH_STORE_FILE", "storeFile")
      val sPass = keyProp("PDFTECH_STORE_PASSWORD", "storePassword")
      require(alias != null && kPass != null && sFile != null && sPass != null) {
          "Credentials release manquants. Le build release ne peut pas être signé."
      }
      ...
  }
  ```
- **Effort** : Rapide (< 1h).

---

### Finding #3 — Permission `MANAGE_EXTERNAL_STORAGE` (all-files access)
- **Type** : Config vulnérable
- **Sévérité** : Haute
- **Fichier** : `android/app/src/main/AndroidManifest.xml:11-12`
- **Description** : L'application déclare `MANAGE_EXTERNAL_STORAGE`, qui donne accès à l'ensemble du stockage partagé. Le commentaire indique que c'est volontaire pour un gestionnaire de PDFs et que l'app n'est pas destinée au Play Store.
- **Code actuel** :
  ```xml
  <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
      tools:ignore="ScopedStorage" />
  ```
- **Impact** : Si une partie du code Dart est compromise (via une injection de path, une mauvaise validation, ou un plugin tiers), cette permission permet de lire/écrire n'importe où sur le stockage externe. C'est un privilège très élevé. Le code natif restreint ensuite les chemins partagés via `isAllowedPath()`, mais la permission elle-même reste dangereuse.
- **Code corrigé / mitigation** : La permission est partiellement justifiée par la nature de l'application. Pour réduire le risque :
  1. Privilégier le Storage Access Framework (SAF) comme chemin par défaut (`file_picker` / `file_selector`).
  2. Documenter la justification pour F-Droid.
  3. S'assurer qu'aucune méthode Dart ne peut utiliser cette permission pour accéder à des zones hors scope PDF (le code actuel est déjà orienté SAF, mais le scan direct de `Download` reste actif).
- **Effort** : Moyen (< 1 jour) — nécessite une revue UX et une possible migration complète vers SAF.

---

### Finding #4 — Signature APK v1 activée (attaque Janus)
- **Type** : Config vulnérable
- **Sévérité** : Moyenne
- **Fichier** : `android/app/build.gradle.kts:52-54`
- **Description** : La signature v1 (JAR) est activée en parallèle de v2 et v3.
- **Code actuel** :
  ```kotlin
  enableV1Signing = true
  enableV2Signing = true
  enableV3Signing = true
  ```
- **Impact** : La signature v1 est vulnérable à l'attaque Janus (CVE-2017-13156) et permet de modifier certaines parties du ZIP sans invalider la v1. Bien que v2/v3 soient présentes, certains outils ou scénarios pourraient ne valider que v1.
- **Code corrigé** :
  ```kotlin
  enableV1Signing = false
  enableV2Signing = true
  enableV3Signing = true
  ```
  Si la compatibilité avec des appareils très anciens (API < 24) est indispensable, conserver v1 et documenter le risque accepté.
- **Effort** : Rapide (< 1h).

---

### Finding #5 — `debugPrint` non protégés en release (fuite de paths utilisateur)
- **Type** : Code vulnérable
- **Sévérité** : Moyenne
- **Fichier** : `lib/widgets/pdf_picker_screen.dart:124-311` et `lib/utils/saf_picker.dart:63-81`
- **Description** : Plusieurs `debugPrint` loguent des chemins de fichiers, des noms de fichiers et des stacktraces sans être protégés par `if (kDebugMode)`. En release, ces logs peuvent atterrir dans logcat et exposer des paths absolus de fichiers utilisateurs (`/storage/emulated/0/...`).
- **Code actuel** :
  ```dart
  debugPrint('[PdfPickerScreen] download dir: $downloadDir');
  debugPrint('[SafPicker] copied SAF file to: $destPath (${bytes.length} bytes)');
  debugPrint('[SafPicker] failed to persist ${file.path}: $e\n$st');
  ```
- **Impact** : Fuite d'informations sur la structure de stockage de l'utilisateur, potentiellement des noms de fichiers sensibles.
- **Code corrigé** :
  ```dart
  if (kDebugMode) {
    debugPrint('[PdfPickerScreen] download dir: $downloadDir');
  }
  ```
  Ou simplement supprimer les logs non essentiels en release.
- **Effort** : Rapide (< 1h).

---

### Finding #6 — Utilisation d'API de stockage externe dépréciées
- **Type** : Code vulnérable / Dette technique
- **Sévérité** : Moyenne
- **Fichier** : `android/app/src/main/kotlin/com/pdftech/pdf_tech/MainActivity.kt:214`, `lib/widgets/pdf_picker_screen.dart:284-311`, `lib/screens/home/home_tab.dart:190`
- **Description** : Utilisation de `Environment.getExternalStorageDirectory()` (deprecated API 29) et `getExternalStorageDirectory()` via `path_provider` pour construire des chemins absolus sur le stockage externe.
- **Impact** : Comportement incohérent selon les versions Android, fragilité face au Scoped Storage, et dépendance à `MANAGE_EXTERNAL_STORAGE` pour fonctionner. Peut masquer des bugs de permission.
- **Code corrigé** : Migrer vers `StorageManager` / `StorageStatsManager` pour les statistiques de stockage, et utiliser exclusivement le Storage Access Framework ou `getExternalFilesDirectory()` pour les chemins de fichiers.
- **Effort** : Moyen (< 1 jour).

---

### Finding #7 — Messages d'erreur utilisateur avec exceptions brutes
- **Type** : Code vulnérable / Info leak mineur
- **Sévérité** : Basse
- **Fichier** : `lib/screens/cloud/google_drive_screen.dart:89, 113, 135, 164`
- **Description** : Les erreurs Google Drive sont affichées telles quelles dans les Snackbars (`'connexion : $e'`, `'chargement : $e'`, etc.).
- **Code actuel** :
  ```dart
  showErrorSnack(context, 'connexion : $e');
  showErrorSnack(context, 'chargement : $e');
  showErrorSnack(context, 'upload : $e');
  showErrorSnack(context, 'téléchargement : $e');
  ```
- **Impact** : Les exceptions de Google Sign-In / HTTP ne contiennent généralement pas de tokens, mais elles peuvent contenir des URLs, des messages internes ou des détails de configuration en cas d'exception personnalisée ou de proxy.
- **Code corrigé** :
  ```dart
  } catch (e) {
    if (kDebugMode) debugPrint('[GoogleDriveScreen._signIn] $e');
    if (mounted) showErrorSnack(context, 'Échec de la connexion. Vérifiez votre connexion et réessayez.');
  }
  ```
- **Effort** : Rapide (< 1h).

---

### Finding #8 — Stockage de métadonnées de fichiers en clair dans `SharedPreferences`
- **Type** : Bonne pratique manquante
- **Sévérité** : Basse
- **Fichier** : `lib/features/pdf_viewer/services/last_page_service.dart`, `lib/main.dart:226-287`, `files_tech_core/lib/src/recents/recent_files_service.dart`
- **Description** : Les chemins, noms, tailles et dates d'accès des fichiers récents sont persistés dans `SharedPreferences` via JSON. `SharedPreferences` n'est pas chiffré.
- **Impact** : Sur un appareil rooté ou avec accès au backup, un nom de fichier comme `fiche_paie_2026.pdf` ou un path révélateur peut être lu en clair. Ce ne sont pas des secrets, mais des métadonnées potentiellement sensibles.
- **Code corrigé** : Évaluer la sensibilité des paths. Si certains sont sensibles, migrer les données récentes vers `flutter_secure_storage` ou chiffrer la liste localement. Pour les fichiers publics/documents, c'est acceptable.
- **Effort** : Moyen (< 1 jour).

---

### Finding #9 — `catch (_) { return null; }` silencieux sur le check de mise à jour
- **Type** : Bonne pratique manquante
- **Sévérité** : Basse
- **Fichier** : `files_tech_core/lib/src/update/update_service.dart:141-143`
- **Description** : Toutes les erreurs du check de mise à jour sont absorbées.
- **Impact** : Acceptable pour l'UX, mais cela complique le diagnostic et la détection d'attaques réseau (MITM, compte GitHub compromis publiant un payload inattendu). Le reste du code est robuste (validation type-safe, whitelist d'hôtes), donc le risque reste limité.
- **Code corrigé** : Ajouter un log conditionnel en `kDebugMode` ou un callback `onError` optionnel pour les apps consommatrices, sans changer le comportement par défaut.
- **Effort** : Rapide (< 1h).

---

### Finding #10 — `minSdk` hérité de `flutter.minSdkVersion`
- **Type** : Bonne pratique manquante
- **Sévérité** : Info
- **Fichier** : `android/app/build.gradle.kts:61`
- **Description** : `minSdk = flutter.minSdkVersion` rend la valeur dépendante du SDK Flutter.
- **Impact** : Très faible. Une mise à jour Flutter pourrait changer le `minSdk` sans que l'équipe ne s'en aperçoive.
- **Code corrigé** : Pinner explicitement la valeur, comme c'est fait pour `targetSdk` et `compileSdk`.
  ```kotlin
  minSdk = 24
  ```
- **Effort** : Rapide (< 1h).

---

### Finding #11 — Absence de pinning de certificat pour GitHub
- **Type** : Bonne pratique manquante
- **Sévérité** : Info
- **Fichier** : `files_tech_core/lib/src/update/update_service.dart:87-92`
- **Description** : Le check de mise à jour utilise `https://api.github.com` via le package `http` sans pinning de certificat.
- **Impact** : Le package `http` s'appuie sur les certificats système. Cela ne protège pas contre un adversaire capable d'installer un certificat racine malveillant sur l'appareil. Cependant, l'URL est contrôlée par les paramètres `owner`/`repo`, et l'APK n'est pas auto-téléchargé.
- **Code corrigé** : Pour une défense en profondeur, envisager du pinning de clé publique pour `api.github.com` et `objects.githubusercontent.com` si le mécanisme de mise à jour devient critique.
- **Effort** : Long (> 1 jour) — maintenance du pinning.

---

### Finding #12 — Logging dans un helper cryptographique
- **Type** : Info / Bonne pratique
- **Fichier** : `files_tech_core/lib/src/security/secret_bytes.dart:84-91`
- **Description** : Un `debugPrint` est présent dans `SecretBytes.wipe`, mais il est encapsulé dans un `assert` et ne loggue que la taille du buffer, jamais son contenu.
- **Impact** : Négligeable. Le message ne s'exécute qu'en mode debug et sert de "fil-piège" pour les développeurs.
- **Code corrigé** : Aucun changement nécessaire, mais s'assurer que le contenu du buffer ne soit jamais loggué.
- **Effort** : Aucun.

---

## Points conformes notables

| Domaine | Évaluation | Preuve dans le code |
|---|---|---|
| **Backup / Cloud extraction** | ✅ Conforme | `allowBackup="false"`, `fullBackupContent="false"`, `data_extraction_rules.xml` exclut tous les domaines. |
| **Trafic réseau** | ✅ Conforme | `usesCleartextTraffic="false"`, `network_security_config.xml` sans cleartext, ancrages système uniquement. |
| **Obfuscation build release** | ✅ Conforme | `isMinifyEnabled = true`, `isShrinkResources = true`, fichier `proguard-rules.pro` présent. |
| **FileProvider** | ✅ Conforme | `exported="false"`, authority basée sur `applicationId`, `file_paths.xml` sans `root-path` ni `files-path="."`. |
| **Validation des intents entrants** | ✅ Conforme | `MainActivity.kt` : `isAllowedPath()`, canonicalisation, blacklist `/Android/data/<autre-pkg>`, whitelist des packages cloud. |
| **Partage de fichiers** | ✅ Conforme | Utilisation de `content://` via `FileProvider`, `FLAG_GRANT_READ_URI_PERMISSION`, `clipData` lié. |
| **FLAG_SECURE** | ✅ Conforme | `secure_window.dart` + `MainActivity.kt` : pose/retrait de `FLAG_SECURE` sur la fenêtre principale. |
| **Gestion des mots de passe PDF** | ✅ Conforme | `PdfEncryptionAlgorithm.aesx256Bit`, owner password aléatoire de 32 caractères via `Random.secure()`, SecureWindow sur les écrans sensibles. |
| **Lecture PDF sécurisée** | ✅ Conforme | `safeReadPdf()` : cap 200 Mo, validation magic bytes `%PDF-`. |
| **Écriture atomique** | ✅ Conforme | `atomicWriteBytes()` : write tmp + rename + flush. |
| **OAuth Google Drive** | ✅ Conforme | Scope restreint `https://www.googleapis.com/auth/drive.file`, `disconnect()` révoque le refresh token, client HTTP dédié fermé après chaque requête. |
| **Mise à jour** | ✅ Conforme | Whitelist `github.com` / `objects.githubusercontent.com`, pas d'auto-download, SHA-256 attendu dans le body, cache 12h. |
| **Anti path-traversal** | ✅ Conforme | `resolveSafePdfName()` côté natif, `_sanitizeFileName()` côté Dart, sanitisation des noms Drive. |
| **Logging** | ✅ Partiellement conforme | La majorité des `debugPrint` sont protégés par `if (kDebugMode)`. Seuls 2 fichiers ont des oublis. |
| **Secrets dans le code** | ✅ Conforme | Aucune clé API, token, mot de passe applicatif ou clé privée n'a été trouvé dans le code source. |
| **WebView** | ✅ Conforme | Aucune WebView directe dans le code applicatif. `url_launcher` expose une `WebViewActivity` interne `exported="false"`. |

---

## Checklist Appliquée

### Checklist rapide (15 min)
- [x] Pas de secrets dans le code source (sauf keystore/properties local non git-tracké)
- [ ] `debuggable=false` et `allowBackup=false` — `allowBackup=false` OK, debuggable non explicit mais défaut false
- [x] HTTPS partout, pas de cleartext traffic
- [x] Données sensibles chiffrées au repos (mots de passe PDF via AES-256)
- [ ] Permissions minimales justifiées — `MANAGE_EXTERNAL_STORAGE` est un privilège élevé
- [ ] Pas de `Log.d` avec des données sensibles — `debugPrint` non protégés dans 2 fichiers
- [x] Dépendances à jour sans CVE connues identifiées

### Checklist standard (1h)
- [x] Composants Android exported justifiés et protégés
- [x] WebViews sécurisées (pas de WebView applicative)
- [x] Validation des entrées sur tous les points d'entrée
- [ ] Gestion correcte des sessions — OAuth OK, mais pas de pinning TLS
- [ ] Certificate pinning sur les endpoints critiques — non implémenté
- [ ] Pas de données sensibles dans les logs, le cache, le clipboard — logs paths à corriger
- [x] Algorithmes crypto modernes (AES-256, pas de MD5/DES/ECB)
- [x] ProGuard/R8 configuré correctement
- [x] Deep links / intents validés et sanitisés

### Checklist approfondie (demi-journée)
- [x] Revue des flux d'authentification/autorisation (Google Drive scope restreint)
- [x] Test de tous les endpoints API depuis le code mobile (GitHub Releases, Google Drive)
- [x] Analyse des flux de données sensibles (mot de passe PDF en RAM, purge decrypted/)
- [ ] Revue de la gestion d'erreurs — erreurs silencieuses dans update, messages bruts Drive
- [x] Analyse des mécanismes de mise à jour de l'app (pas d'auto-download, SHA-256 affiché)
- [ ] Vérification des mécanismes anti-tampering — non implémentés (pas de demande dans le scope)
- [ ] Revue des mécanismes de détection root/jailbreak — non implémentés (pas de demande dans le scope)
- [x] Audit complet des dépendances transitives (pubspec.lock + osv-scanner en CI)

---

## Conclusion et recommandations prioritaires

1. **Supprimer immédiatement** `android/key.properties` et `android/app/keystore.jks` du working tree local. Ne conserver les secrets de signature que dans le coffre-fort CI (GitHub Actions secrets). (Critique — < 1h)
2. **Interdire le fallback debug** en build release dans `android/app/build.gradle.kts`. (Haute — < 1h)
3. **Réduire la dépendance à `MANAGE_EXTERNAL_STORAGE`** : privilégier SAF par défaut, documenter la justification pour F-Droid, et évaluer si le scan direct de `Download` est encore nécessaire. (Haute — 1 jour)
4. **Désactiver `enableV1Signing`** si la compatibilité avec les appareils API < 24 n'est pas indispensable. (Moyenne — < 1h)
5. **Corriger les `debugPrint` non protégés** dans `pdf_picker_screen.dart` et `saf_picker.dart` pour éviter la fuite de paths en logcat release. (Moyenne — < 1h)
6. **Remplacer les messages d'erreur bruts** par des messages génériques dans `google_drive_screen.dart`. (Basse — < 1h)
7. **Migrer les statistiques de stockage** vers `StorageManager`/`StorageStatsManager` et réduire l'usage de `getExternalStorageDirectory()`. (Moyenne — 1 jour)
8. **Évaluer le chiffrement** des métadonnées de fichiers récents si les paths peuvent être sensibles. (Basse — 1 jour)
9. **Pinner `minSdk`** explicitement dans `build.gradle.kts`. (Info — < 1h)
10. **Envisager le certificate pinning** pour les endpoints de mise à jour si le threat model le justifie. (Info — > 1 jour)

**Score final : 68/100** — bonne posture défensive globale, mais des failles de configuration et de logging doivent être corrigées avant de considérer l'app comme suffisamment durcie pour une distribution de confiance.
