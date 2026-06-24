import org.gradle.api.tasks.testing.Test
import org.gradle.language.base.plugins.LifecycleBasePlugin

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

tasks.withType<Test>().configureEach {
    if (name != "networkHarnessTest") {
        exclude("**/OkHttpNativeHttpEngineLoopbackTest.class")
    }
}

afterEvaluate {
    val debugUnitTest = tasks.named<Test>("testDebugUnitTest")

    tasks.register<Test>("networkHarnessTest") {
        description = "Runs Android host loopback tests against the shared NativeNetKit mock server."
        group = LifecycleBasePlugin.VERIFICATION_GROUP
        dependsOn(
            "compileDebugUnitTestKotlin",
            "compileDebugUnitTestJavaWithJavac",
            "processDebugUnitTestJavaRes",
        )
        testClassesDirs = debugUnitTest.get().testClassesDirs
        classpath = debugUnitTest.get().classpath
        include("**/OkHttpNativeHttpEngineLoopbackTest.class")
        shouldRunAfter(debugUnitTest)
    }

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
