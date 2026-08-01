plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Credentials keystore : UNIQUEMENT via variables d'environnement (CI / poste
// sécurisé). Le fichier key.properties et le keystore ne doivent JAMAIS être
// versionnés. Ils sont stockés hors dépôt, par exemple dans
// J:/applications/_backups/pdf_tech_keystore/.
fun env(name: String): String? = System.getenv(name)

android {
    // v1.12.5 (S1) — `com.pdftech.pdf_tech` est le package HISTORIQUE pré-
    // FilesTech (publié sous cet identifiant sur F-Droid + GitHub Release
    // depuis 2024). Cert SHA-256 stable `7d2c1199…dd2a4f4` y est lié.
    // Migrer vers `com.filestech.pdftech` serait destructive (perte
    // historique installations utilisateurs F-Droid). On conserve.
    namespace = "com.pdftech.pdf_tech"
    // Pinné explicitement pour cohérence cross-app Files Tech et
    // reproductibilité des builds CI. 36 requis par androidx.core 1.17+.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            val alias  = env("PDFTECH_KEY_ALIAS")
            val kPass  = env("PDFTECH_KEY_PASSWORD")
            val sFile  = env("PDFTECH_STORE_FILE")
            val sPass  = env("PDFTECH_STORE_PASSWORD")
            if (alias == null || kPass == null || sFile == null || sPass == null) {
                throw GradleException(
                    "Release signing credentials missing. " +
                    "Set PDFTECH_KEY_ALIAS, PDFTECH_KEY_PASSWORD, " +
                    "PDFTECH_STORE_FILE and PDFTECH_STORE_PASSWORD " +
                    "environment variables (or use a secure CI secret store)."
                )
            }
            keyAlias      = alias
            keyPassword   = kPass
            storeFile     = file(sFile)
            storePassword = sPass
            // v1 désactivée (audit OWASP M5/M8 — attaque Janus).
            enableV1Signing = false
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    defaultConfig {
        applicationId = "com.pdftech.pdf_tech"
        // Pinné explicitement (coherence cross-app, reproductibilité CI).
        minSdk = 24
        // Pinné explicitement à 35 (cohérence avec compileSdk = 36) au lieu
        // de suivre `flutter.targetSdkVersion` qui peut diverger selon le SDK.
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // FR + EN seulement (économie ressources Material/AndroidX strings).
        // PDF Tech n'a pas d'i18n applicative mais Material/MLKit packagent
        // les locales par défaut → réduit l'APK livré.
        resourceConfigurations += listOf("fr", "en")
    }

    // Splits ABI : bloc retiré v1.12.5.1 hotfix CI.
    //
    // Cause : depuis Flutter 3.41+, le SDK pose `ndk.abiFilters` auto.
    // Avoir aussi `splits.abi { include(...) }` déclenche au build :
    //   "Conflicting configuration : '...' in ndk abiFilters cannot be
    //    present when splits abi filters are set"
    //
    // Le workflow GH Actions Release utilise `flutter build apk --release`
    // (sans `--split-per-abi`) → besoin d'un APK universal → conflit.
    //
    // Pattern : passer par `flutter build apk --release --split-per-abi`
    // (flag explicite) pour obtenir 3 APKs splits côté local. Sans flag :
    // `flutter build apk --release` génère 1 APK universal (CI Release).
    //
    // Aligné RFT v2.13.1 hotfix CI et Pass / Notes Tech (qui n'ont jamais
    // eu ce bloc).

    bundle {
        abi {
            enableSplit = true
        }
        language {
            // Pas d'i18n applicative → split langue inutile (économie nulle).
            enableSplit = false
        }
    }

    buildTypes {
        release {
            // Pas de fallback debug : un build release sans credentials valides
            // doit échouer explicitement (audit — empêche une signature debug
            // de fuiter en production).
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
