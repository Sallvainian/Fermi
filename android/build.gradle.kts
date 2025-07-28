import org.gradle.api.tasks.compile.JavaCompile

plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}


val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    plugins.withId("com.android.base") {
        extensions.configure<com.android.build.gradle.BaseExtension> {
            // Ensure compileSdkVersion is set for all Android projects
            compileSdkVersion(35)
            
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_21
                targetCompatibility = JavaVersion.VERSION_21
            }
            
            // Suppress lint warnings from dependencies
            lintOptions {
                isQuiet = true
                isAbortOnError = false
                isWarningsAsErrors = false
                disable("ObsoleteLintCustomCheck")
            }
        }
    }
    
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            jvmToolchain(21)
        }
    }
    
    plugins.withId("org.jetbrains.kotlin.jvm") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension> {
            jvmToolchain(21)
        }
    }
    
    // Configure Java compilation options for all subprojects
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(listOf(
            "-Xlint:-deprecation",
            "-Xlint:-unchecked",
            "-Xlint:-options"
        ))
    }
}

// Configure Flutter plugin projects only if they exist
subprojects.forEach { subproject ->
    when (subproject.name) {
        "file_picker", "flutter_callkit_incoming" -> {
            subproject.afterEvaluate {
                plugins.withId("com.android.library") {
                    extensions.configure<com.android.build.gradle.LibraryExtension> {
                        compileOptions {
                            sourceCompatibility = JavaVersion.VERSION_21
                            targetCompatibility = JavaVersion.VERSION_21
                        }
                    }
                }
                tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
                    kotlinOptions.jvmTarget = "21"
                }
            }
        }
        "flutter_local_notifications" -> {
            subproject.afterEvaluate {
                plugins.withId("com.android.library") {
                    extensions.configure<com.android.build.gradle.LibraryExtension> {
                        compileOptions {
                            sourceCompatibility = JavaVersion.VERSION_21
                            targetCompatibility = JavaVersion.VERSION_21
                        }
                    }
                }
                tasks.withType<JavaCompile>().configureEach {
                    options.compilerArgs.addAll(listOf(
                        "-Xlint:-options",
                        "-Xlint:-deprecation"
                    ))
                }
            }
        }
        "firebase_auth" -> {
            subproject.afterEvaluate {
                plugins.withId("com.android.library") {
                    extensions.configure<com.android.build.gradle.LibraryExtension> {
                        compileOptions {
                            sourceCompatibility = JavaVersion.VERSION_21
                            targetCompatibility = JavaVersion.VERSION_21
                        }
                    }
                }
                tasks.withType<JavaCompile>().configureEach {
                    options.compilerArgs.addAll(listOf(
                        "-Xlint:-deprecation"
                    ))
                }
            }
        }
        "flutter_webrtc" -> {
            subproject.afterEvaluate {
                plugins.withId("com.android.library") {
                    extensions.configure<com.android.build.gradle.LibraryExtension> {
                        compileOptions {
                            sourceCompatibility = JavaVersion.VERSION_21
                            targetCompatibility = JavaVersion.VERSION_21
                        }
                    }
                }
                tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
                    kotlinOptions.jvmTarget = "21"
                }
                tasks.withType<JavaCompile>().configureEach {
                    options.compilerArgs.addAll(listOf(
                        "-Xlint:-deprecation",
                        "-Xlint:-unchecked"
                    ))
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
