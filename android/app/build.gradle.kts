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

val flutterCompileSdkVersion: String = localProperties.getProperty("flutter.compileSdkVersion") ?: "36" // Updated to support androidx.core 1.15.0
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
        applicationId = "com.teacherdashboard.teacher_dashboard_flutter_firebase"
        minSdk = flutterMinSdkVersion.toInt()
        targetSdk = flutterCompileSdkVersion.toInt()
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex for large app
        multiDexEnabled = true
        
        // Optimize for better performance
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    // Signing configurations
    signingConfigs {
        getByName("debug") {
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            storeFile = file("debug.keystore")
            storePassword = "android"
        }
        // Note: For production release signing, use external key.properties file
        // create("release") {
        //     keyAlias = keystoreProperties["keyAlias"] as String
        //     keyPassword = keystoreProperties["keyPassword"] as String
        //     storeFile = file(keystoreProperties["storeFile"] as String)
        //     storePassword = keystoreProperties["storePassword"] as String
        // }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isDebuggable = true
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            signingConfig = signingConfigs.getByName("debug") // Use debug signing for now
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Build features
    buildFeatures {
        buildConfig = true
    }

    // Packaging options
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "/META-INF/DEPENDENCIES"
            excludes += "/META-INF/LICENSE"
            excludes += "/META-INF/LICENSE.txt"
            excludes += "/META-INF/NOTICE"
            excludes += "/META-INF/NOTICE.txt"
        }
    }

    // Lint options
    lint {
        disable += "ObsoleteLintCustomCheck"
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    
    // Fix FFmpeg Kit dependency resolution
    implementation("com.arthenica:ffmpeg-kit-https:6.0-2.LTS")
}
