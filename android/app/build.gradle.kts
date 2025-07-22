import org.gradle.api.JavaVersion
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// The version check that was causing issues should be placed here,
// right after the plugins block.

// By checking the Gradle version, we implicitly handle the requirement for a
// compatible Android Gradle Plugin (AGP) version, as they are tightly coupled.
// For example, AGP 8.+ requires Gradle 8.0+. This avoids complex and brittle
// logic to parse the specific AGP version.
if (project.gradle.gradleVersion < "8.0") {
    throw GradleException("Unsupported Gradle version. Please use Gradle 8.0 or higher to build this project.")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterCompileSdkVersion: String = localProperties.getProperty("flutter.compileSdkVersion") ?: "34" // Default to a reasonable value
val flutterNdkVersion: String = localProperties.getProperty("flutter.ndkVersion") ?: "25.1.8937393" // Default from Flutter
val flutterMinSdkVersion: String = localProperties.getProperty("flutter.minSdkVersion") ?: "21" // Common default

android {
    namespace = "com.example.app"
    compileSdk = flutterCompileSdkVersion.toInt()
    ndkVersion = flutterNdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        minSdk = flutterMinSdkVersion.toInt()
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    
}
