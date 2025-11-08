import java.util.Properties
import java.io.FileInputStream

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
    namespace = "com.drktv.cbt_drktv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // ---- Load keystore if present ----
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // required when using java.time etc.
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.drktv.cbt_drktv" // <- change if needed
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // If your app ever needs multidex (usually minSdk < 21)
        multiDexEnabled = true
    }

    // ---- Signing configs (debug + release) ----
    signingConfigs {
        // debug exists by default via Flutter
        create("release") {
            // Only set when key.properties exists
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // keep default debug signing
        }
        getByName("release") {
            // If key.properties is present, use release signing; else fall back to debug so local builds still work
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")

            // Optimize for Play release
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Avoid a few common duplicate resource issues
    packaging {
        resources {
            excludes += setOf("META-INF/AL2.0", "META-INF/LGPL2.1")
        }
    }

    // Generate BuildConfig if you ever need it
    buildFeatures {
        buildConfig = true
    }
}

flutter {
    source = "../.."
}

// ✅ Dependencies
dependencies {
    // Required for desugaring modern Java APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Kotlin stdlib (AGP usually adds this, but safe to keep)
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")

    // Multidex runtime (harmless if not needed)
    implementation("androidx.multidex:multidex:2.0.1")
    compileOnly("com.guardsquare:proguard-annotations:7.4.0")
}
