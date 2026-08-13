pluginManagement {
    val flutterSdkPath = run {
        // CI: FLUTTER_ROOT is set by subosito/flutter-action
        // Local: read from local.properties
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
    id("com.android.application") version "8.4.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

include(":app")
