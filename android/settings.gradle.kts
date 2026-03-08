pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

// Fix namespace for legacy plugins (e.g. isar_flutter_libs) that don't declare one
gradle.beforeProject {
    if (project.name != "app" && project.name != rootProject.name) {
        project.afterEvaluate {
            try {
                val androidExt = extensions.findByName("android")
                if (androidExt is com.android.build.gradle.LibraryExtension) {
                    if (androidExt.namespace.isNullOrEmpty()) {
                        androidExt.namespace = project.group.toString().ifEmpty {
                            "dev.${project.name.replace("-", "_")}"
                        }
                    }
                }
            } catch (_: Exception) {
                // Not an Android library project, skip
            }
        }
    }
}
