import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun getSigningProperty(propertyKey: String, envKey: String): String? {
    val fromFile = keystoreProperties.getProperty(propertyKey)
    val fromEnv = System.getenv(envKey)
    return (fromFile ?: fromEnv)?.takeIf { it.isNotBlank() }
}

val releaseStoreFilePath = getSigningProperty("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = getSigningProperty("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = getSigningProperty("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = getSigningProperty("keyPassword", "ANDROID_KEY_PASSWORD")

val releaseStoreFile = releaseStoreFilePath
    ?.takeIf { it.isNotBlank() }
    ?.let { configuredPath ->
        val configuredFile = File(configuredPath)
        if (configuredFile.isAbsolute) configuredFile else rootProject.file(configuredPath)
    }

val isReleaseSigningConfigured = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { property ->
    when (property) {
        is String -> property.isNotBlank()
        is File -> property.exists()
        else -> false
    }
}

android {
    namespace = "com.antroph.aura"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.antroph.aura"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

signingConfigs {
    create("release") {
        val storePath = System.getenv("CM_KEYSTORE_PATH")
            ?: throw GradleException("CM_KEYSTORE_PATH not set")

        val storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
            ?: throw GradleException("CM_KEYSTORE_PASSWORD not set")

        val keyAlias = System.getenv("CM_KEY_ALIAS")
            ?: throw GradleException("CM_KEY_ALIAS not set")

        val keyPassword = System.getenv("CM_KEY_PASSWORD")
            ?: throw GradleException("CM_KEY_PASSWORD not set")

        storeFile = file(storePath)
        this.storePassword = storePassword
        this.keyAlias = keyAlias
        this.keyPassword = keyPassword

        println("✅ Using Codemagic keystore at: $storePath")
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}

flutter {
    source = "../.."
}
