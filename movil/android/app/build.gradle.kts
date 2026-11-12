8
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // El plugin de Flutter debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "mx.veracruz.agua_lluvia"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requerido por flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "mx.veracruz.agua_lluvia"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Configuración moderna de Kotlin DSL para Java 17
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Firebase (FCM): el plugin solo se aplica si existe google-services.json
// (no se versiona; ver movil/README.md). Sin el archivo el build sigue
// compilando y la app corre sin notificaciones push.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

flutter {
    source = "../.."
}