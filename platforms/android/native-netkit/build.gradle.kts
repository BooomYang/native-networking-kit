plugins {
    alias(libs.plugins.native.netkit.android.library)
    id("maven-publish")
}

android {
    namespace = "com.aifirst.nativenetkit"

    defaultConfig {
        consumerProguardFiles("consumer-rules.pro")
    }

    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
    }
}

dependencies {
    api(libs.okhttp)
    implementation(libs.coroutines.core)

    testImplementation(kotlin("test"))
    testImplementation(libs.coroutines.test)
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])
                groupId = "com.aifirst"
                artifactId = "native-netkit"
                version = "0.1.0-SNAPSHOT"

                pom {
                    name.set("NativeNetKit")
                    description.set("Phase 1 thin Android engine adapter for NativeNetKit.")
                }
            }
        }
    }
}
