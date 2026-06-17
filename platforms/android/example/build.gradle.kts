plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.aifirst.nativenetkit.example"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.aifirst.nativenetkit.example"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":native-netkit"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
