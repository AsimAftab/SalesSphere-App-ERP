plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Reads a key out of `env/<flavor>.json` (the same files Dart consumes via
// `--dart-define-from-file`). Returns "" when the file or key is missing
// so a clean checkout still builds — the LocationPicker falls back to its
// placeholder when the key is empty.
fun envValue(flavor: String, key: String): String {
    val file = File(rootProject.projectDir.parentFile, "env/$flavor.json")
    if (!file.exists()) return ""
    val regex = Regex("\"${Regex.escape(key)}\"\\s*:\\s*\"([^\"]*)\"")
    return regex.find(file.readText())?.groupValues?.get(1).orEmpty()
}

android {
    namespace = "com.salessphere.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.salessphere.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "SalesSphere Dev")
            manifestPlaceholders["MAPS_API_KEY"] =
                envValue("dev", "GOOGLE_MAPS_ANDROID_KEY")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "SalesSphere Staging")
            manifestPlaceholders["MAPS_API_KEY"] =
                envValue("staging", "GOOGLE_MAPS_ANDROID_KEY")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "SalesSphere")
            manifestPlaceholders["MAPS_API_KEY"] =
                envValue("prod", "GOOGLE_MAPS_ANDROID_KEY")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
