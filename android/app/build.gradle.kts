import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé de release, si elle existe: `android/key.properties`, jamais versionné.
// Modèle et procédure dans DEPLOY.md. Absent, on retombe sur la clé de debug,
// ce qui garde `flutter build apk --release` utilisable sans rien configurer.
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "dev.safe.safe"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.safe.safe"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sans `android/key.properties`, la clé de debug — publique et
            // partagée par toutes les installations Flutter. N'importe qui peut
            // alors fabriquer un APK substituable à celui-ci lors d'une mise à
            // jour, et hériter du répertoire privé existant, coffre compris.
            //
            // Le passage à une vraie clé n'est pas anodin: une signature
            // différente fait échouer `adb install -r`, et la réinstallation
            // qu'elle impose efface le coffre. Exporter d'abord
            // (Réglages -> Exporter le coffre), et exporter les pièces jointes
            // une par une, l'export ne les contenant pas. Procédure complète
            // dans DEPLOY.md.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
