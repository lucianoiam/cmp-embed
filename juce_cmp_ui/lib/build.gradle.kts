plugins {
    kotlin("jvm")
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
}

group = "com.github.juce-cmp"
version = "1.0.0"

kotlin {
    jvmToolchain(21)
}

dependencies {
    api(compose.runtime)
    api(compose.foundation)
    api(compose.material3)
    api(compose.ui)
    api(compose.desktop.currentOs)
    implementation(compose.components.resources)
    implementation(compose.components.uiToolingPreview)
    implementation(libs.kotlinx.coroutinesSwing)
    api("net.java.dev.jna:jna:5.14.0")

    testImplementation(libs.kotlin.test)
}
