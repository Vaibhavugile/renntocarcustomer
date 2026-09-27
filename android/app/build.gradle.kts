
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")

    // Firebase / Google Services
    id("com.google.gms.google-services")

    id("kotlin-android")

    // Flutter Gradle Plugin must be applied after
    // Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ================================================================
// RELEASE KEYSTORE
// ================================================================

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (!keystorePropertiesFile.exists()) {
    throw GradleException(
        "Missing android/key.properties. " +
        "Please create the release signing configuration before building."
    )
}

keystoreProperties.load(
    FileInputStream(keystorePropertiesFile)
)

// ================================================================
// ANDROID
// ================================================================

android {

    namespace = "com.rentocar.apps"

    compileSdk = flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion

    // ============================================================
    // JAVA / CORE LIBRARY DESUGARING
    // ============================================================

    compileOptions {
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // ============================================================
    // KOTLIN
    // ============================================================

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ============================================================
    // DEFAULT CONFIG
    // ============================================================

    defaultConfig {

        applicationId = "com.rentocar.apps"

        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode

        versionName = flutter.versionName
    }

    // ============================================================
    // RELEASE SIGNING
    // ============================================================

    signingConfigs {

        create("release") {

            keyAlias =
                keystoreProperties["keyAlias"] as String

            keyPassword =
                keystoreProperties["keyPassword"] as String

            storeFile =
                file(
                    keystoreProperties["storeFile"] as String
                )

            storePassword =
                keystoreProperties["storePassword"] as String
        }
    }

    // ============================================================
    // BUILD TYPES
    // ============================================================

    buildTypes {

        release {

            // IMPORTANT:
            // Use the Rentocar upload keystore.
            signingConfig =
                signingConfigs.getByName("release")

            // Keep disabled for now to avoid
            // unnecessary release/R8 issues.
            isMinifyEnabled = false

            isShrinkResources = false
        }
    }
}

// ================================================================
// DEPENDENCIES
// ================================================================

dependencies {

    // Required by flutter_local_notifications
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.5"
    )
}

// ================================================================
// FLUTTER
// ================================================================

flutter {
    source = "../.."
}

