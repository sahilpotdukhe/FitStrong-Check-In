import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // No `kotlin-android`: AGP 9 compiles Kotlin itself (`android.builtInKotlin=true`).
    // Applying the Kotlin Gradle Plugin here is unsupported on AGP 9+.
    // The Flutter Gradle Plugin must be applied after the Android Gradle Plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    // Local-only and gitignored. Absent on machines that only build debug -- the release
    // signing config below is then simply not registered.
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}
val hasUploadKeystore = keystoreProperties.getProperty("storeFile")?.let { file(it).exists() } == true

// Without a keystore a release build does not stop: it writes the APKs, Flutter prints its
// ticks, and they are unsigned and will not install on any phone. Refuse up front instead,
// based on what was actually asked for, so debug builds -- which need no key -- still work.
val buildingRelease = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("Release", ignoreCase = true)
}
if (buildingRelease && !hasUploadKeystore) {
    throw GradleException(
        "No signing key, so this release would be unsigned and could not be installed " +
            "on any device.\n\n" +
            "Create android/key.properties with storeFile, storePassword, keyAlias and " +
            "keyPassword. See \"One-time: signing key\" in the README for the keytool " +
            "command that generates one.",
    )
}

android {
    namespace = "com.fitstrong.checkin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.fitstrong.checkin"
        // mobile_scanner needs 23; stated here so a Flutter upgrade that
        // lowers the default cannot silently break the camera.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Deliberately no debug fallback. A debug-signed release installs, but it is
            // signed with a key every Android machine shares, which is exactly what makes
            // Play Protect treat a sideloaded build as coming from nobody in particular.
            // The guard at the top of this file is what stops an unsigned build instead.
            if (hasUploadKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
