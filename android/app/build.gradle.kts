plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.cbt_drktv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // ✅ Enable Java 11 and desugaring (required for flutter_local_notifications)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // <-- Add this line
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.cbt_drktv"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Using debug keys for now so `flutter run --release` works
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ✅ Add this dependencies block (below flutter block)
dependencies {
    // Required for desugaring modern Java APIs (java.time, etc.)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")


    // Kotlin standard library (ensures compatibility with AGP 8+)
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
}
