import java.util.Properties

repositories {
    google()
    mavenCentral()
    maven { url = uri("https://maven.google.com") }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { reader ->
        localProperties.load(reader)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")
    ?: "1"

val flutterVersionName = localProperties.getProperty("flutter.versionName")
    ?: "1.0"

android {
    namespace = "com.example.test_gemma3n_flutter"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    buildFeatures {
        buildConfig = true // ✅ this line enables BuildConfig fields
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.test_gemma3n_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName

        // Enable multidex for large dependencies
        multiDexEnabled = true

        // Ensure sufficient heap size for 4GB model
        javaCompileOptions {
            annotationProcessorOptions {
                arguments += mapOf("room.schemaLocation" to "$projectDir/schemas")
            }
        }
        
        buildConfigField("String", "HUGGINGFACE_TOKEN", "\"${project.findProperty("HUGGINGFACE_TOKEN")}\"")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Ensure model files aren't compressed (LiteRT-LM uses .task files)
            aaptOptions {
                noCompress("task", "litertlm")
            }
        }
        debug {
            // Disable minification in debug for easier debugging
            isMinifyEnabled = false
            isShrinkResources = false
        }

    }
    
    // Increase memory for Gradle build process
    dexOptions {
        javaMaxHeapSize = "4g"
    }
}

flutter {
    source = "../.."
}

dependencies {
            // Core Android/Flutter dependencies
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.10")
    implementation("androidx.multidex:multidex:2.0.1")

            // Kotlin Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")

            // ============ GOOGLE LITERT SDK (Official) ============
            // Core inference runtime (includes Interpreter and basic delegates)
    implementation("com.google.ai.edge.litert:litert:1.4.0")
    
            // Optional GPU acceleration support
    implementation("com.google.ai.edge.litert:litert-gpu:1.4.0")
    
            // Metadata util library
    implementation("com.google.ai.edge.litert:litert-metadata:1.4.0")
    
            // High-level support utilities (e.g., data converters)
    implementation("com.google.ai.edge.litert:litert-support:1.4.0")

            // ============ PERFORMANCE & MONITORING ============
            // For performance monitoring (optional)
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")

            // For file operations and storage
    implementation("androidx.preference:preference-ktx:1.2.1")

            // For HTTP downloads (if implementing model download)
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

            // JSON handling
    implementation("com.google.code.gson:gson:2.10.1")
}
