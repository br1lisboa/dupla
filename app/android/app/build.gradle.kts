plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dupla.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Production identity. Immutable once published to Play Store.
        // The local and staging flavors derive from it via applicationIdSuffix.
        applicationId = "com.dupla.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 8.0. Raised from the Flutter default to drop version-conditional code paths.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Single dimension: the three flavors are environments, never combined.
    flavorDimensions += "env"

    // Visible name and launcher icon per flavor live in each flavor's source set,
    // under src/<flavor>/res/.
    productFlavors {
        create("local") {
            dimension = "env"
            applicationIdSuffix = ".local"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
        }
        create("prod") {
            dimension = "env"
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
