# Évaluation OWASP Mobile Top 10 — PDF Tech v1.13.3

**Application** : PDF Tech v1.13.3  
**Plateforme** : Flutter (Dart) + Android natif (Kotlin)  
**Scope** : `J:/applications/pdf_tech` + dépendance `J:/applications/files_tech_core`  
**APK audité** : `build/app/outputs/flutter-apk/pdf-tech-universel-1.13.3.apk`  
**Date** : 2026-08-01  
**Référentiel** : OWASP Mobile Top 10 (2024) / MASVS v2  

---

## Score Global : 66/100

**Méthode** : moyenne pondérée des 10 catégories. La catégorie M1 est classée **Critique** (score 3/10) et compte donc double.

| Catégorie | Score | Statut | Findings |
|---|---|---|---|
| M1 - Improper Credential Usage | 3/10 | Critique | 1 |
| M2 - Inadequate Supply Chain Security | 8/10 | Partiellement conforme | 0 (observations) |
| M3 - Insecure Authentication/Authorization | 9/10 | Conforme | 0 |
| M4 - Insufficient Input/Output Validation | 9/10 | Conforme | 0 |
| M5 - Insecure Communication | 8/10 | Partiellement conforme | 1 (info) |
| M6 - Inadequate Privacy Controls | 7/10 | Partiellement conforme | 2 |
| M7 - Insufficient Binary Protections | 6/10 | Partiellement conforme | 1 |
| M8 - Security Misconfiguration | 5/10 | Non conforme | 3 |
| M9 - Insecure Data Storage | 6/10 | Non conforme | 2 |
| M10 - Insufficient Cryptography | 9/10 | Conforme | 0 |

**Formule** : `(3×2 + 8 + 9 + 9 + 8 + 7 + 6 + 5 + 6 + 9) / 11 = 66/100`

---

## Résumé par Catégorie

| Catégorie | Score | Statut | Findings |
|---|---|---|---|
| M1 - Improper Credential Usage | 3/10 | Critique | 1 |
| M2 - Inadequate Supply Chain Security | 8/10 | Partiellement conforme | 0 |
| M3 - Insecure Authentication/Authorization | 9/10 | Conforme | 0 |
| M4 - Insufficient Input/Output Validation | 9/10 | Conforme | 0 |
| M5 - Insecure Communication | 8/10 | Partiellement conforme | 1 |
| M6 - Inadequate Privacy Controls | 7/10 | Partiellement conforme | 2 |
| M7 - Insufficient Binary Protections | 6/10 | Partiellement conforme | 1 |
| M8 - Security Misconfiguration | 5/10 | Non conforme | 3 |
| M9 - Insecure Data Storage | 6/10 | Non conforme | 2 |
| M10 - Insufficient Cryptography | 9/10 | Conforme | 0 |

---

## Détail des Findings

### [M1] - Finding #1 : Secrets de signature de l'application en clair dans le working tree

- **Sévérité** : Critique
- **Localisation** : `android/key.properties:1-2`, `android/app/keystore.jks`
- **Description** : Le fichier `key.properties` contient le mot de passe du keystore et le mot de passe de la clé de signature en clair (`storePassword=***REDACTED*** `keyPassword=***REDACTED*** Le fichier binaire `keystore.jks` (2 752 octets) est également présent dans le répertoire de travail. Ces deux fichiers sont bien listés dans `.gitignore`, mais leur présence locale expose les secrets de signature de l'éditeur.
- **Impact** : Toute personne ayant accès au poste de développement (ou à une archive/backup/snapshot du répertoire) peut signer des APK frauduleux avec la clé de PDF Tech. Cela invalide la chaîne de confiance des releases GitHub/F-Droid et permettrait de publier des mises à jour malveillantes sous l'identité de l'application.
- **Recommandation** : Supprimer immédiatement `android/key.properties` et `android/app/keystore.jks` du working tree. Ne conserver les secrets de signature que dans un coffre-fort CI (GitHub Actions secrets, Azure Key Vault, etc.). Le build `release` doit échouer si les variables d'environnement `PDFTECH_*` ne sont pas fournies, plutôt que de fallback sur la clé debug.
- **Code vulnérable** :
  ```properties
  # android/key.properties
  storePassword=***REDACTED***
  keyPassword=***REDACTED***
  keyAlias=pdf_studio
  storeFile=keystore.jks
  ```
- **Code corrigé** :
  ```properties
  # android/key.properties — SUPPRIMER ce fichier du working tree
  # Ne jamais stocker les credentials localement.
  ```
  ```kotlin
  // android/app/build.gradle.kts
  // La logique actuelle lit déjà les env vars PDFTECH_* en priorité.
  // S'assurer que le build release ÉCHOUE si elles sont absentes.
  create("release") {
      val alias = keyProp("PDFTECH_KEY_ALIAS", "keyAlias")
      val kPass = keyProp("PDFTECH_KEY_PASSWORD", "keyPassword")
      val sFile = keyProp("PDFTECH_STORE_FILE", "storeFile")
      val sPass = keyProp("PDFTECH_STORE_PASSWORD", "storePassword")
      require(alias != null && kPass != null && sFile != null && sPass != null) {
          "Credentials release manquants. Le build release ne peut pas être signé."
      }
      // ...
  }
  ```

### [M2] - Aucun finding actif (observation)

- **Sévérité** : Info
- **Localisation** : `pubspec.yaml`, `pubspec.lock`, `.github/workflows/security.yml`
- **Description** : Les dépendances sont globalement à jour et le workflow CI exécute `osv-scanner` hebdomadairement. Aucune CVE connue n'a été identifiée dans les dépendances principales. Le fichier `android/app/proguard-rules.pro` contient des règles `-keep` pour `com.it_nomads.fluttersecurestorage.**` et `dev.fluttercommunity.plus.device_info.**`, alors que ces plugins ne sont pas déclarés dans `pubspec.yaml` ; ce sont des vestiges sans impact direct mais qui augmentent la surface de confiance du fichier ProGuard.
- **Impact** : Négligeable en l'état, mais les règles fantômes peuvent masquer l'absence d'une dépendance réelle ou induire en erreur lors d'une revue.
- **Recommandation** : Nettoyer `proguard-rules.pro` pour ne conserver que les plugins réellement utilisés. Maintenir `osv-scanner` en CI et surveiller les mises à jour de `syncfusion_flutter_pdf`, `pdfrx` et `googleapis`.

### [M3] - Aucun finding

- **Statut** : Conforme
- **Justification** : L'application n'implémente pas de mécanisme d'authentification propre (pas de login/password, pas de rôles). L'unique mécanisme d'identité est l'OAuth Google Drive via `google_sign_in` avec le scope restreint `https://www.googleapis.com/auth/drive.file` et une révocation correcte du refresh token (`disconnect()`). La `MainActivity` est `exported="true"` mais justifiée par les filtres `LAUNCHER`, `ACTION_VIEW` et `ACTION_SEND` PDF, avec validation des intents entrants et whitelist des packages de partage. Aucun bypass d'authentification ni IDOR n'est applicable ici.

### [M4] - Aucun finding

- **Statut** : Conforme
- **Justification** : Aucune WebView n'est utilisée directement dans l'application. `url_launcher` expose une `WebViewActivity` interne `exported="false"`. Les intents entrants (PDF partagés ou ouverts) sont validés, copiés dans un sous-répertoire isolé du cache, avec limitation de taille (200 Mo), vérification des magic bytes `%PDF-`, et anti path-traversal via `resolveSafePdfName()`. Les noms de fichiers Drive et les chemins locaux sont sanitisés. Les bases de données et le stockage local ne sont pas exposés à des injections SQL.

### [M5] - Finding #1 : Absence de certificate pinning pour les endpoints réseau

- **Sévérité** : Basse (Info / défense en profondeur)
- **Localisation** : `files_tech_core/lib/src/update/update_service.dart:87-92`, `android/app/src/main/res/xml/network_security_config.xml`
- **Description** : Les communications utilisent exclusivement HTTPS (`api.github.com`, `googleapis.com`, `objects.githubusercontent.com`). Le `network_security_config.xml` interdit le trafic en clair (`cleartextTrafficPermitted="false"`) et n'accepte que les ancres système. Cependant, aucun pinning de certificat (ou de clé publique) n'est implémenté pour l'endpoint de mise à jour GitHub ni pour Google Drive.
- **Impact** : Dans un scénario où un attaquant peut installer un certificat racine malveillant sur l'appareil de la victime, le trafic HTTPS pourrait être intercepté sans que l'application ne le détecte. Le risque est atténué par la validation stricte de la réponse GitHub (semver, whitelist d'hôtes, pas d'auto-download) et le scope restreint de Google Drive.
- **Recommandation** : Envisager le pinning de clé publique pour `api.github.com` et `objects.githubusercontent.com` si le mécanisme de mise à jour devient critique. Pour Google Drive, le SDK officiel gère la confiance ; ne pas implémenter de TrustManager custom.
- **Code vulnérable** :
  ```xml
  <!-- network_security_config.xml -->
  <base-config cleartextTrafficPermitted="false">
      <trust-anchors>
          <certificates src="system" />
      </trust-anchors>
  </base-config>
  ```
- **Code corrigé** :
  ```xml
  <!-- Exemple de pinning pour les endpoints de mise à jour -->
  <domain-config>
      <domain includeSubdomains="false">api.github.com</domain>
      <domain includeSubdomains="true">objects.githubusercontent.com</domain>
      <pin-set expiration="2027-01-01">
          <pin digest="SHA-256">BASE64_HASH_PRIMARY</pin>
          <pin digest="SHA-256">BASE64_HASH_BACKUP</pin>
      </pin-set>
  </domain-config>
  ```

### [M6] - Finding #1 : Permission `MANAGE_EXTERNAL_STORAGE` à haut privilège

- **Sévérité** : Haute
- **Localisation** : `android/app/src/main/AndroidManifest.xml:11-12`, `lib/widgets/pdf_picker_screen.dart:124-312`, `lib/screens/home/home_tab.dart:190`
- **Description** : L'application déclare `android.permission.MANAGE_EXTERNAL_STORAGE`, qui accorde un accès universel à l'ensemble du stockage partagé. Le commentaire du manifeste indique que c'est volontaire pour un gestionnaire/lecteur de PDFs et que l'application n'est pas destinée au Play Store. Le code natif restreint les chemins partagés via `isAllowedPath()` et une whitelist de packages cibles, mais la permission elle-même reste très élevée.
- **Impact** : Si une partie du code Dart est compromise (via une injection de path, une mauvaise validation, ou un plugin tiers), cette permission permet de lire/écrire n'importe où sur le stockage externe. Cela augmente considérablement la surface d'attaque et peut être mal perçue par les utilisateurs et les stores alternatifs (F-Droid).
- **Recommandation** : Privilégier le Storage Access Framework (SAF) comme chemin par défaut (`file_picker` / `file_selector`). Documenter la justification pour F-Droid. Évaluer si le scan direct de `Download` et l'accès à la racine externe via `getExternalStorageDirectory()` sont encore nécessaires, et migrer vers `getExternalFilesDirectory()` / SAF dès que possible.
- **Code vulnérable** :
  ```xml
  <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
      tools:ignore="ScopedStorage" />
  ```
- **Code corrigé** :
  ```xml
  <!-- Supprimer MANAGE_EXTERNAL_STORAGE si SAF couvre tous les cas d'usage -->
  <!-- <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" /> -->
  ```

### [M6] - Finding #2 : Métadonnées de fichiers persistées en clair dans `SharedPreferences`

- **Sévérité** : Basse
- **Localisation** : `lib/features/pdf_viewer/services/last_page_service.dart`, `lib/main.dart:226-287`, `files_tech_core/lib/src/recents/recent_files_service.dart:26-101`
- **Description** : Les chemins, noms, tailles et dates d'accès des fichiers récents sont persistés dans `SharedPreferences` via JSON. `SharedPreferences` n'est pas chiffré sur Android. Le même mécanisme est utilisé pour le cache du check de mise à jour (`update_last_check_ms_<repo>`).
- **Impact** : Sur un appareil rooté ou avec accès au backup, un nom de fichier comme `fiche_paie_2026.pdf` ou un path révélateur peut être lu en clair. Ce ne sont pas des secrets, mais des métadonnées potentiellement sensibles. Le risque est atténué par `android:allowBackup="false"` et l'absence de cloud backup.
- **Recommandation** : Évaluer la sensibilité des paths. Si certains fichiers peuvent être sensibles, migrer les données récentes vers `flutter_secure_storage` (ou un chiffrement local avec clé Keystore) et/ou anonymiser les noms de fichiers. Pour les fichiers publics/documents, le stockage actuel reste acceptable.
- **Code vulnérable** :
  ```dart
  // files_tech_core/lib/src/recents/recent_files_service.dart
  Future<void> _save(List<RecentFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, files.map((f) => f.toJsonString()).toList());
  }
  ```
- **Code corrigé** :
  ```dart
  // Si les paths sont sensibles : chiffrer la liste avant persistence
  Future<void> _save(List<RecentFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = await _encryptJson(files.map((f) => f.toJsonString()).toList());
    await prefs.setStringList(key, encrypted);
  }
  ```

### [M7] - Finding #1 : Protections binaires partielles (absence de root detection et anti-tampering)

- **Sévérité** : Moyenne
- **Localisation** : `android/app/build.gradle.kts`, `android/app/proguard-rules.pro`
- **Description** : Le build release est obfusqué avec R8 (`isMinifyEnabled = true`, `isShrinkResources = true`) et les règles ProGuard sont présentes. L'application est compilée en mode release Flutter (AOT). Cependant, il n'existe aucune détection de root, d'émulateur, de Frida/Xposed, ni de vérification anti-tampering (signature de l'APK) ou d'intégrité du binaire.
- **Impact** : Pour une application PDF offline sans données financières ou médicales sensibles, le risque est limité. Néanmoins, un attaquant peut facilement reverser l'application, modifier la logique de partage ou les permissions, et repackager un APK. Cela est surtout préoccupant en lien avec M1 (secrets de signature) : si la clé de signature fuite, l'attaquant peut signer son APK modifié avec l'identité légitime.
- **Recommandation** : Évaluer le threat model. Si la distribution F-Droid/GitHub nécessite une confiance renforcée, envisager l'intégration de Play Integrity API (pour les builds Play) ou d'une bibliothèque de détection de root de base (RootBeer) avec vérification de signature côté natif. Ne pas bloquer totalement les appareils rootés pour F-Droid, mais avertir l'utilisateur.

### [M8] - Finding #1 : Fallback signing debug en build release

- **Sévérité** : Haute
- **Localisation** : `android/app/build.gradle.kts:100-108`
- **Description** : Si les credentials release ne sont pas disponibles (absence de `key.properties` et absence de variables d'environnement `PDFTECH_STORE_PASSWORD`), le build release est signé avec la clé debug Android par défaut.
- **Impact** : Un APK release signé debug peut être remplacé/écrasé par n'importe quel autre APK debug sur un appareil. Si ce type d'artefact est publié par erreur, il constitue un incident de sécurité majeur et permet à un attaquant d'installer une version malveillante à la place de l'application.
- **Recommandation** : Interdire le fallback debug en build release. Le build release doit échouer si les credentials release manquent.
- **Code vulnérable** :
  ```kotlin
  buildTypes {
      release {
          signingConfig = if (keyPropertiesFile.exists() ||
              System.getenv("PDFTECH_STORE_PASSWORD") != null) {
              signingConfigs.getByName("release")
          } else {
              signingConfigs.getByName("debug")
          }
          // ...
      }
  }
  ```
- **Code corrigé** :
  ```kotlin
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("release")
          // ...
      }
  }
  ```
  Et dans la configuration de la signature release :
  ```kotlin
  create("release") {
      val alias = keyProp("PDFTECH_KEY_ALIAS", "keyAlias")
      val kPass = keyProp("PDFTECH_KEY_PASSWORD", "keyPassword")
      val sFile = keyProp("PDFTECH_STORE_FILE", "storeFile")
      val sPass = keyProp("PDFTECH_STORE_PASSWORD", "storePassword")
      require(alias != null && kPass != null && sFile != null && sPass != null) {
          "Credentials release manquants. Le build release ne peut pas être signé."
      }
      // ...
  }
  ```

### [M8] - Finding #2 : Signature APK v1 activée (attaque Janus)

- **Sévérité** : Moyenne
- **Localisation** : `android/app/build.gradle.kts:52-54`
- **Description** : La signature v1 (JAR) est activée en parallèle de v2 et v3.
- **Impact** : La signature v1 est vulnérable à l'attaque Janus (CVE-2017-13156) et permet de modifier certaines parties du ZIP sans invalider la v1. Bien que v2/v3 soient présentes, certains outils ou scénarios pourraient ne valider que v1. Le `minSdk` est 24+, ce qui limite l'exploitation sur les appareils modernes, mais la surface reste présente.
- **Recommandation** : Désactiver `enableV1Signing` si la compatibilité avec des appareils très anciens (API < 24) n'est pas indispensable. Si v1 doit être conservé, documenter le risque accepté dans `SECURITY.md`.
- **Code vulnérable** :
  ```kotlin
  enableV1Signing = true
  enableV2Signing = true
  enableV3Signing = true
  ```
- **Code corrigé** :
  ```kotlin
  enableV1Signing = false
  enableV2Signing = true
  enableV3Signing = true
  ```

### [M8] - Finding #3 : `minSdk` hérité du SDK Flutter et règles ProGuard fantômes

- **Sévérité** : Basse
- **Localisation** : `android/app/build.gradle.kts:61`, `android/app/proguard-rules.pro:14-17`
- **Description** : `minSdk = flutter.minSdkVersion` rend la valeur dépendante du SDK Flutter. Le fichier `proguard-rules.pro` contient des règles `-keep` pour `flutter_secure_storage` et `device_info_plus`, qui ne sont pas des dépendances de l'application.
- **Impact** : Très faible. Une mise à jour Flutter pourrait changer le `minSdk` sans que l'équipe ne s'en aperçoive. Les règles fantômes n'ont pas d'impact fonctionnel mais alourdissent la revue de sécurité.
- **Recommandation** : Pinner explicitement `minSdk = 24` et nettoyer les règles ProGuard inutiles.
- **Code vulnérable** :
  ```kotlin
  minSdk = flutter.minSdkVersion
  ```
- **Code corrigé** :
  ```kotlin
  minSdk = 24
  ```

### [M9] - Finding #1 : `debugPrint` non protégés en release fuite de paths utilisateur

- **Sévérité** : Moyenne
- **Localisation** : `lib/widgets/pdf_picker_screen.dart:124-311`, `lib/utils/saf_picker.dart:63-81`
- **Description** : Plusieurs `debugPrint` loguent des chemins de fichiers, des noms de fichiers et des stacktraces sans être protégés par `if (kDebugMode)`. En release, ces logs peuvent atterrir dans logcat et exposer des paths absolus de fichiers utilisateurs (`/storage/emulated/0/...`).
- **Impact** : Fuite d'informations sur la structure de stockage de l'utilisateur, potentiellement des noms de fichiers sensibles. Sur un appareil partagé ou avec une application malveillante disposant de la permission `READ_LOGS`, ces informations peuvent être collectées.
- **Recommandation** : Protéger tous les `debugPrint` par `if (kDebugMode)` ou les supprimer. Remplacer les logs en production par un système de logging conditionnel au mode debug.
- **Code vulnérable** :
  ```dart
  debugPrint('[PdfPickerScreen] download dir: $downloadDir');
  debugPrint('[SafPicker] copied SAF file to: $destPath (${bytes.length} bytes)');
  debugPrint('[SafPicker] failed to persist ${file.path}: $e\n$st');
  ```
- **Code corrigé** :
  ```dart
  if (kDebugMode) {
    debugPrint('[PdfPickerScreen] download dir: $downloadDir');
  }
  ```

### [M9] - Finding #2 : Messages d'erreur utilisateur avec exceptions brutes (Google Drive)

- **Sévérité** : Basse
- **Localisation** : `lib/screens/cloud/google_drive_screen.dart:89, 113, 135, 164`
- **Description** : Les erreurs Google Drive sont affichées telles quelles dans les Snackbars (`'connexion : $e'`, `'chargement : $e'`, etc.).
- **Impact** : Les exceptions de Google Sign-In / HTTP ne contiennent généralement pas de tokens, mais elles peuvent contenir des URLs, des messages internes ou des détails de configuration en cas d'exception personnalisée ou de proxy. C'est une fuite d'information mineure.
- **Recommandation** : Remplacer les messages d'erreur bruts par des messages génériques et loguer les détails uniquement en `kDebugMode`.
- **Code vulnérable** :
  ```dart
  showErrorSnack(context, 'connexion : $e');
  showErrorSnack(context, 'chargement : $e');
  showErrorSnack(context, 'upload : $e');
  showErrorSnack(context, 'téléchargement : $e');
  ```
- **Code corrigé** :
  ```dart
  } catch (e) {
    if (kDebugMode) debugPrint('[GoogleDriveScreen._signIn] $e');
    if (mounted) showErrorSnack(context, 'Échec de la connexion. Vérifiez votre connexion et réessayez.');
  }
  ```

### [M10] - Aucun finding

- **Statut** : Conforme
- **Justification** : La protection des PDFs par mot de passe utilise `PdfEncryptionAlgorithm.aesx256Bit` (AES-256). Le mot de passe owner est généré avec `Random.secure()` sur 32 caractères. Le helper `SecretBytes` utilise `Random.secure()` pour le CSPRNG, fournit des comparaisons en temps constant et un effacement de buffers. Aucun algorithme obsolète (DES, RC4, MD5, ECB, SHA-1 pour la sécurité) n'a été trouvé dans le code. La mise à jour utilise SHA-256 pour le hash de l'APK. Aucune implémentation cryptographique maison n'est utilisée pour le chiffrement des données ; la bibliothèque Syncfusion est utilisée pour les opérations PDF.

---

## Top 5 Actions Prioritaires

1. **Supprimer immédiatement les secrets de signature du working tree** (M1) — Critique, effort < 1h. Supprimer `android/key.properties` et `android/app/keystore.jks`, ne conserver les secrets que dans GitHub Actions secrets ou un coffre-fort CI.
2. **Interdire le fallback debug en build release** (M8) — Haute, effort < 1h. Faire échouer le build release si les credentials release sont absents.
3. **Réduire la dépendance à `MANAGE_EXTERNAL_STORAGE`** (M6) — Haute, effort ~1 jour. Privilégier SAF par défaut, documenter la justification pour F-Droid, et évaluer le scan direct de `Download`.
4. **Corriger les `debugPrint` non protégés** (M9) — Moyenne, effort < 1h. Protéger les logs de paths par `if (kDebugMode)` dans `pdf_picker_screen.dart` et `saf_picker.dart`.
5. **Désactiver `enableV1Signing`** si la compatibilité API < 24 n'est pas indispensable (M8) — Moyenne, effort < 1h.

---

## Points conformes notables

| Domaine | Évaluation | Preuve dans le code |
|---|---|---|
| Backup / Cloud extraction | ✅ Conforme | `allowBackup="false"`, `fullBackupContent="false"`, `data_extraction_rules.xml` exclut tous les domaines. |
| Trafic réseau | ✅ Conforme | `usesCleartextTraffic="false"`, `network_security_config.xml` sans cleartext, ancres système uniquement. |
| Obfuscation build release | ✅ Conforme | `isMinifyEnabled = true`, `isShrinkResources = true`, fichier `proguard-rules.pro` présent. |
| FileProvider | ✅ Conforme | `exported="false"`, authority basée sur `applicationId`, `file_paths.xml` sans `root-path` ni `files-path="."`. |
| Validation des intents entrants | ✅ Conforme | `MainActivity.kt` : `isAllowedPath()`, canonicalisation, blacklist `/Android/data/<autre-pkg>`, whitelist des packages cloud. |
| Partage de fichiers | ✅ Conforme | Utilisation de `content://` via `FileProvider`, `FLAG_GRANT_READ_URI_PERMISSION`, `clipData` lié. |
| FLAG_SECURE | ✅ Conforme | `secure_window.dart` + `MainActivity.kt` : pose/retrait de `FLAG_SECURE` sur la fenêtre principale. |
| Gestion des mots de passe PDF | ✅ Conforme | `PdfEncryptionAlgorithm.aesx256Bit`, owner password aléatoire de 32 caractères via `Random.secure()`. |
| Lecture PDF sécurisée | ✅ Conforme | `safeReadPdf()` : cap 200 Mo, validation magic bytes `%PDF-`. |
| Écriture atomique | ✅ Conforme | `atomicWriteBytes()` : write tmp + rename + flush. |
| OAuth Google Drive | ✅ Conforme | Scope restreint `drive.file`, `disconnect()` révoque le refresh token, client HTTP dédié fermé après chaque requête. |
| Mise à jour | ✅ Conforme | Whitelist `github.com` / `objects.githubusercontent.com`, pas d'auto-download, SHA-256 attendu dans le body, cache 12h. |
| Anti path-traversal | ✅ Conforme | `resolveSafePdfName()` côté natif, `_sanitizeFileName()` côté Dart, sanitisation des noms Drive. |

---

## Synthèse

PDF Tech v1.13.3 présente une posture défensive globalement satisfaisante pour une application PDF offline : validation des entrées, partage sécurisé via FileProvider, pas de cleartext traffic, pas de backup, obfuscation release, et utilisation de cryptographie moderne. Les points bloquants sont **configurationnels** et ne relèvent pas de failles de logique applicative.

Le score global de **66/100** est principalement pénalisé par :
- la présence de secrets de signature en clair dans le working tree (M1) ;
- le fallback signing debug en release (M8) ;
- la permission `MANAGE_EXTERNAL_STORAGE` à haut privilège (M6) ;
- les fuites de paths utilisateur via `debugPrint` en release (M9).

La correction des 5 actions prioritaires permettrait de remonter le score global autour de 80/100.
