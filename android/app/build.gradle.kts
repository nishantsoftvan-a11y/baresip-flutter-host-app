plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    jvmToolchain(17)
}

android {
    namespace = "com.sip.sip_sdk_flutter_example"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sip.sip_sdk_flutter_example"
        minSdk = 29
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += setOf(
                "armeabi-v7a",
                "arm64-v8a"
            )
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

repositories {
    flatDir { dirs("libs") }
}

dependencies {

    // Sip SDK AAR
    // implementation(files("libs/SipSdk-release.aar"))
    implementation(fileTree("libs") {
        include("*.aar")
    })

    // Coroutines
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.coroutines.android)

    // AndroidX
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)

    // Material
    implementation(libs.google.material)

    // DataStore
    implementation(libs.androidx.datastore.preferences)

    // WorkManager
    implementation(libs.androidx.work.runtime.ktx)

    // BouncyCastle
    implementation(libs.bouncycastle.bcprov)
    implementation(libs.bouncycastle.bcpkix)
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        force("androidx.test.espresso:espresso-core:3.6.1")
        force("androidx.test.espresso:espresso-idling-resource:3.6.1")
    }
}

