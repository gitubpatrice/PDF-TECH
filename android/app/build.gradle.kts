import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Credentials keystore : variables d'environnement (CI / poste sécurisé)
// avec fallback sur android/key.properties (gitignoré).
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}
fun keyProp(envName: String, propName: String): String? =
    System.getenv(envName) ?: keyProperties[propName] as String?

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
            val alias  = keyProp("PDFTECH_KEY_ALIAS",     "keyAlias")
            val kPass  = keyProp("PDFTECH_KEY_PASSWORD",  "keyPassword")
            val sFile  = keyProp("PDFTECH_STORE_FILE",    "storeFile")
            val sPass  = keyProp("PDFTECH_STORE_PASSWORD","storePassword")
            if (alias != null && kPass != null && sFile != null && sPass != null) {
                keyAlias      = alias
                keyPassword   = kPass
                storeFile     = file(sFile)
                storePassword = sPass
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    defaultConfig {
        applicationId = "com.pdftech.pdf_tech"
        minSdk = flutter.minSdkVersion
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
            // Fallback debug si pas de credentials release dispo (CI sans secrets)
            signingConfig = if (keyPropertiesFile.exists() ||
                System.getenv("PDFTECH_STORE_PASSWORD") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
