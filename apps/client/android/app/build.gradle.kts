import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Isolated package for the explicit emulator-only verification entrypoint.
val dartDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(",")?.map { String(Base64.getDecoder().decode(it)) }.orEmpty()
val runtimeCheck = "PILLXAI_RUNTIME_CHECK=true" in dartDefines

// Release identity is provided by the publishing environment, never committed.
val signingPath = providers.environmentVariable("PILLXAI_SIGNING_STORE").orNull
val allowDebugRelease = providers.environmentVariable("PILLXAI_ALLOW_DEBUG_SIGNING").orNull == "true"
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
if (releaseRequested && !runtimeCheck && (allowDebugRelease || "PILLXAI_DEMO=true" in dartDefines)) {
    throw GradleException("The production package cannot use debug signing or demo mode. Use the isolated runtimecheck package for tests.")
}
if (releaseRequested && signingPath == null && !(runtimeCheck && allowDebugRelease)) {
    throw GradleException("Release signing is required. Set PILLXAI_SIGNING_STORE, PILLXAI_SIGNING_STORE_PASSWORD, PILLXAI_SIGNING_KEY_ALIAS and PILLXAI_SIGNING_KEY_PASSWORD.")
}

android {
    namespace = "com.pillxai.pillxai_client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = if (runtimeCheck) "com.pillxai.pillxai_client.runtimecheck" else "com.pillxai.pillxai_client"
        manifestPlaceholders["pillxaiLabel"] = if (runtimeCheck) "Pillxai 测试" else "Pillxai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "com.pillxai.pillxai_client.OtaInstrumentation"
    }

    signingConfigs {
        if (signingPath != null) {
            create("production") {
                storeFile = file(signingPath)
                storePassword = providers.environmentVariable("PILLXAI_SIGNING_STORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("PILLXAI_SIGNING_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("PILLXAI_SIGNING_KEY_PASSWORD").get()
            }
        }
    }
    sourceSets.getByName("androidTest").assets.srcDir(rootProject.file("../../../.var/ota-fixtures"))
    buildTypes {
        configureEach {
            if (name == "debug" || name == "profile") {
                if (!runtimeCheck) applicationIdSuffix = ".development"
                manifestPlaceholders["pillxaiLabel"] = if (runtimeCheck) "Pillxai 测试" else "Pillxai 开发"
            }
        }
        release {
            signingConfig = when {
                signingPath != null -> signingConfigs.getByName("production")
                runtimeCheck && allowDebugRelease -> signingConfigs.getByName("debug")
                else -> null
            }
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
