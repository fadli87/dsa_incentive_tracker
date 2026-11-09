import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val resolvedKeyAlias: String? =
    keystoreProperties.getProperty("keyAlias") ?: System.getenv("ANDROID_KEY_ALIAS")
val resolvedKeyPassword: String? =
    keystoreProperties.getProperty("keyPassword") ?: System.getenv("ANDROID_KEY_PASSWORD")
val resolvedStorePassword: String? =
    keystoreProperties.getProperty("storePassword") ?: System.getenv("ANDROID_STORE_PASSWORD")
val resolvedStoreFilePath: String? =
    keystoreProperties.getProperty("storeFile") ?: System.getenv("ANDROID_KEYSTORE_PATH")
val resolvedStoreFile = resolvedStoreFilePath?.let { path ->
    val f = file(path)
    if (f.exists()) f else rootProject.file(path)
}
val hasReleaseSigning = !resolvedKeyAlias.isNullOrBlank() &&
    !resolvedKeyPassword.isNullOrBlank() &&
    !resolvedStorePassword.isNullOrBlank() &&
    resolvedStoreFile != null &&
    resolvedStoreFile.exists()

android {
    namespace = "com.xlsmart.dsa_incentive_tracker"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.xlsmart.dsa_incentive_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = resolvedKeyAlias
                keyPassword = resolvedKeyPassword
                storeFile = resolvedStoreFile
                storePassword = resolvedStorePassword
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
