pluginManagement {
    val flutterSdkPath = run {
        // On CI (GitHub Actions with subosito/flutter-action), FLUTTER_ROOT env var is set.
        // Locally, flutter.sdk is read from local.properties.
        val envFlutterRoot = System.getenv("FLUTTER_ROOT")
        if (envFlutterRoot != null) {
            envFlutterRoot
        } else {
            val properties = java.util.Properties()
            val localPropsFile = file("local.properties")
            if (localPropsFile.exists()) {
                localPropsFile.inputStream().use { properties.load(it) }
            }
            val sdkPath = properties.getProperty("flutter.sdk")
            requireNotNull(sdkPath) {
                "flutter.sdk not set in local.properties and FLUTTER_ROOT env var not found"
            }
            sdkPath
        }
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
    id("com.android.application") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

include(":app")
