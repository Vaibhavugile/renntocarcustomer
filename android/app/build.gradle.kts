plugins {
    id("com.android.application")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration

    id("kotlin-android")

    // The Flutter Gradle Plugin must be applied after
    // the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.customer_app_car_rental"

    compileSdk = flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion

    // ============================================================
    // JAVA / CORE LIBRARY DESUGARING
    // ============================================================

    compileOptions {
        // Required by flutter_local_notifications
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
        applicationId = "com.example.customer_app_car_rental"

        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode

        versionName = flutter.versionName
    }

    // ============================================================
    // BUILD TYPES
    // ============================================================

    buildTypes {
        release {
            // TODO: Add your own signing config for release.
            // Using debug signing for now.
            signingConfig =
                signingConfigs.getByName("debug")
        }
    }
}

// ================================================================
// CORE LIBRARY DESUGARING DEPENDENCY
// ================================================================
//
// Required by flutter_local_notifications.
//

dependencies {
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