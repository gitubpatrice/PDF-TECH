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
