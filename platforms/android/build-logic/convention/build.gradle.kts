plugins {
    `kotlin-dsl`
}

group = "com.aifirst.nativenetkit.buildlogic"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

dependencies {
    compileOnly(libs.android.gradle.plugin)
    compileOnly(libs.kotlin.gradle.plugin)
}

gradlePlugin {
    plugins {
        register("androidApplication") {
            id = "native-netkit.android.application"
            implementationClass = "NativeNetkitAndroidApplicationConventionPlugin"
        }
        register("androidLibrary") {
            id = "native-netkit.android.library"
            implementationClass = "NativeNetkitAndroidLibraryConventionPlugin"
        }
    }
}
