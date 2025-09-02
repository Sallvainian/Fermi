allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Define shared SDK versions for plugins expecting rootProject extra properties
extra["compileSdkVersion"] = 36
extra["targetSdkVersion"] = 36
extra["minSdkVersion"] = 21

// Configure common Android settings for all subprojects (including plugins)
subprojects {
    // Configure Android Library modules
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
            compileSdk = (rootProject.extra["compileSdkVersion"] as Int)

            defaultConfig {
                minSdk = (rootProject.extra["minSdkVersion"] as Int)
            }

            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_21
                targetCompatibility = JavaVersion.VERSION_21
            }
        }
    }

    // Configure Android Application modules (if any among subprojects)
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension>("android") {
            compileSdk = (rootProject.extra["compileSdkVersion"] as Int)

            defaultConfig {
                minSdk = (rootProject.extra["minSdkVersion"] as Int)
                targetSdk = (rootProject.extra["targetSdkVersion"] as Int)
            }

            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_21
                targetCompatibility = JavaVersion.VERSION_21
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
