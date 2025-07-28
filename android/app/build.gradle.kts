import org.gradle.api.JavaVersion
import org.gradle.api.GradleException
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Gradle version check removed to allow compatibility with current Gradle version

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterCompileSdkVersion: String = localProperties.getProperty("flutter.compileSdkVersion") ?: "35" // Updated to support androidx.core 1.15.0
val flutterNdkVersion: String = localProperties.getProperty("flutter.ndkVersion") ?: "27.0.12077973" // Updated NDK version
val flutterMinSdkVersion: String = localProperties.getProperty("flutter.minSdkVersion") ?: "21" // Common default

android {
    namespace = "com.teacherdashboard.teacher_dashboard_flutter_firebase"
    compileSdk = flutterCompileSdkVersion.toInt()
    ndkVersion = flutterNdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "21"
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
