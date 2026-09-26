import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ---------------------------------------------------------------------------
// Kunci rilis untuk Google Play.
//
// Berkas `android/key.properties` berisi sandi keystore dan TIDAK ikut di-commit
// (lihat .gitignore). Kalau berkasnya tidak ada — misalnya di komputer orang
// lain — build release kembali memakai kunci debug supaya `flutter run --release`
// tetap bisa dipakai untuk mencoba-coba.
// ---------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val punyaKunciRilis = keystorePropertiesFile.exists()
if (punyaKunciRilis) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "id.insyira.muslimapp"
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
        // Nama paket permanen aplikasi. Google Play MENOLAK nama paket yang
        // berawalan `com.example`, jadi jangan pernah dikembalikan ke nilai itu.
        // Setelah aplikasi terbit di Play, nilai ini TIDAK bisa diubah lagi.
        applicationId = "id.insyira.muslimapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (punyaKunciRilis) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (punyaKunciRilis) {
                    signingConfigs.getByName("release")
                } else {
                    // Tanpa key.properties, build release ditandatangani kunci debug.
                    // Build seperti ini DITOLAK Google Play.
                    logger.warn(
                        "PERINGATAN: android/key.properties tidak ada — " +
                            "build release memakai kunci DEBUG dan tidak bisa diunggah ke Google Play.",
                    )
                    signingConfigs.getByName("debug")
                }

            // ⚠️ JANGAN DIHAPUS.
            //
            // Tanpa aturan di `proguard-rules.pro`, R8 membuang atribut
            // `Signature` yang dibutuhkan Gson di dalam
            // `flutter_local_notifications`. Akibatnya di build RILIS setiap
            // penjadwalan & pembatalan notifikasi gagal dengan
            // "Missing type parameter" — adzan tidak pernah berbunyi, padahal
            // di build debug normal. Penjelasan lengkap ada di berkas itu.
            proguardFiles("proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}