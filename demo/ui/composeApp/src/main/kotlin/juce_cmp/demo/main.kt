// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.demo

import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import juce_cmp.UISender
import juce_cmp.renderer.runIOSurfaceRenderer
import juce_cmp.renderer.captureFirstFrame

/**
 * Application entry point.
 *
 * Supports two modes:
 * - Standalone: Normal desktop window (default)
 * - Embedded: Renders to IOSurface for host integration (--embed flag)
 *
 * In embedded mode, the host passes --iosurface-id=<id> to specify
 * which IOSurface to render to.
 */
fun main(args: Array<String>) {
    // MUST be first - captures raw stdout fd before any library pollutes it
    // Redirects System.out to stderr, uses original stdout for binary IPC
    UISender.initialize()
    
    val embedMode = args.contains("--embed")
    
    if (embedMode) {
        // Hide from Dock - we're a background renderer for the host
        System.setProperty("apple.awt.UIElement", "true")
        
        // Parse --iosurface-id=<id> from host
        val surfaceID = args
            .firstOrNull { it.startsWith("--iosurface-id=") }
            ?.substringAfter("=")
            ?.toIntOrNull()
            ?: error("Missing --iosurface-id=<id> argument")
        
        // Parse --scale=<factor> for Retina support (e.g., 2.0)
        val scaleFactor = args
            .firstOrNull { it.startsWith("--scale=") }
            ?.substringAfter("=")
            ?.toFloatOrNull()
            ?: 1f

        // Start rendering to the shared IOSurface
        runIOSurfaceRenderer(
            surfaceID = surfaceID,
            scaleFactor = scaleFactor,
            onFrameRendered = captureFirstFrame("/tmp/loading_preview.png"),
            onCustomEvent = { tree ->
                // Interpret ValueTree as parameter event
                // Expected format: ValueTree("param") with properties "id" (int) and "value" (float/double)
                if (tree.type == "param") {
                    val idVar = tree["id"]
                    val valueVar = tree["value"]
                    val id = idVar.toInt()
                    val value = valueVar.toDouble().toFloat()
                    if (id >= 0) {
                        ParameterState.update(id, value)
                    }
                }
            }
        ) {
            UserInterface()
        }
    } else {
        // Standalone mode - regular desktop window
        application {
            Window(
                onCloseRequest = ::exitApplication,
                title = "CMP UI"
            ) {
                UserInterface()
            }
        }
    }
}
