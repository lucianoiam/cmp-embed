plugins {
    kotlin("jvm")
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    alias(libs.plugins.composeHotReload)
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    implementation(compose.runtime)
    implementation(compose.foundation)
    implementation(compose.material3)
    implementation(compose.ui)
    implementation(compose.desktop.currentOs)
    implementation(compose.components.resources)
    implementation(compose.components.uiToolingPreview)
    implementation(libs.kotlinx.coroutinesSwing)
    implementation("net.java.dev.jna:jna:5.14.0")
    implementation("com.github.juce-cmp:lib")

    testImplementation(libs.kotlin.test)
}

compose.desktop {
    application {
        mainClass = "juce_cmp.demo.MainKt"

        jvmArgs += listOf(
            "--enable-native-access=ALL-UNNAMED"
        )

        nativeDistributions {
            packageName = "juce-cmp-demo"
            packageVersion = "1.0.0"

            jvmArgs += listOf(
                "--enable-native-access=ALL-UNNAMED"
            )
        }
    }
}

compose.resources {
    packageOfResClass = "juce_cmp.demo.resources"
}
