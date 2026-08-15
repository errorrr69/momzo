plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (FCM) — applied only when the credentials file is actually present.
//
// google-services.json is git-ignored (it identifies the Firebase project), so
// applying this unconditionally means the app CANNOT be built by anyone who does
// not have it: a fresh clone, CI, or — as happened in August 2026 — a machine
// where the file was lost with the Google account behind it. The build failed on
// a missing credential rather than on anything to do with the code.
//
// Present  -> Firebase is wired exactly as before.
// Absent   -> the app builds and runs; push is inert. PushService.init() already
//             try/catches its whole body, so there is nothing further to guard.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "google-services.json not found — building WITHOUT Firebase. Push notifications will be inert."
    )
}

android {
    namespace = "app.momzo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.momzo"
        // Firebase Cloud Messaging needs minSdk 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    // On-device GenAI (Gemini Nano via AICore) — experimental, allowlisted devices
    // only. Guarded at runtime by an availability probe + API-level checks; the app
    // keeps its low minSdk and falls back to cloud everywhere this can't run.
    implementation("com.google.ai.edge.aicore:aicore:0.0.1-exp01")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
