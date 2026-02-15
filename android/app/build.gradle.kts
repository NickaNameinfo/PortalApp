plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "nickname.shopping.portalportal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "nickname.shopping.portalportal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Razorpay requires minSdkVersion 19 or higher
        minSdk = maxOf(flutter.minSdkVersion, 19)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Support for 16KB page size devices
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Enable ProGuard/R8
            // Note: If minifyEnabled is true, ProGuard rules are MANDATORY for Razorpay
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // Support for 16KB page size devices
    // In AGP 8.1+, 16KB page size support is enabled by default
    // Native libraries are automatically aligned for 16KB page sizes
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
        // Ensure all native libraries support 16KB page sizes
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
    
    // Bundle configuration for proper app bundle generation
    // This ensures all users can upgrade to the new release
    // IMPORTANT: Disable all splits to ensure backward compatibility with existing users
    bundle {
        language {
            // Disable language splitting to ensure all users can upgrade
            enableSplit = false
        }
        density {
            // Disable density splitting to ensure all users can upgrade
            enableSplit = false
        }
        abi {
            // Disable ABI splitting to ensure all existing users can upgrade
            // This prevents the "doesn't allow any existing users to upgrade" error
            enableSplit = false
        }
    }
}

flutter {
    source = "../.."
}
