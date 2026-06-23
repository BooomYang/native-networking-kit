plugins {
    alias(libs.plugins.native.netkit.android.application)
}

android {
    namespace = "com.aifirst.nativenetkit.example"

    defaultConfig {
        applicationId = "com.aifirst.nativenetkit.example"
        versionCode = 1
        versionName = "0.1.0"
    }
}

dependencies {
    implementation(project(":native-netkit"))
    implementation(libs.coroutines.android)
}
