// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.renderer

import org.jetbrains.skia.*
import java.io.File
import java.nio.file.Files
import java.nio.file.Paths

/**
 * Captures the current Skia Surface content to a PNG file.
 *
 * This is a generic extension function that works with any Skia Surface, regardless of
 * the underlying backend (Metal, OpenGL, Raster, IOSurface-backed, etc.). It takes a
 * snapshot of the surface and encodes it as a PNG image file.
 *
 * @param outputPath The file path where the PNG should be saved
 * @return true if the capture was successful, false otherwise
 *
 * Example usage:
 * ```kotlin
 * // Works with any Surface type
 * val success = surface.captureFrameToPNG("/path/to/output.png")
 * ```
 */
fun Surface.captureFrameToPNG(outputPath: String): Boolean {
    return try {
        val width = this.width
        val height = this.height

        // Create an offscreen CPU raster surface
        val rasterSurface = Surface.makeRasterN32Premul(width, height)

        // Draw the GPU surface content to the CPU surface
        val canvas = rasterSurface.canvas
        val image = this.makeImageSnapshot()

        if (image != null) {
            canvas.drawImage(image, 0f, 0f)
            image.close()
        }

        // Now take a snapshot of the CPU surface - this will work!
        val rasterImage = rasterSurface.makeImageSnapshot()
        rasterSurface.close()

        if (rasterImage == null) {
            System.err.println("[SurfaceFrameCapture] Failed to create raster snapshot")
            return false
        }

        // Encode the CPU-backed image as PNG
        val encodedData = rasterImage.encodeToData(EncodedImageFormat.PNG)
        rasterImage.close()

        if (encodedData == null) {
            System.err.println("[SurfaceFrameCapture] Failed to encode image as PNG")
            return false
        }

        // Ensure the parent directory exists
        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()

        // Write the PNG data to file
        val bytes = encodedData.bytes
        Files.write(Paths.get(outputPath), bytes)
        encodedData.close()

        println("[SurfaceFrameCapture] Frame captured to: $outputPath (${bytes.size} bytes)")
        true
    } catch (e: Exception) {
        System.err.println("[SurfaceFrameCapture] Error capturing frame: ${e.message}")
        e.printStackTrace()
        false
    }
}

/**
 * Creates a frame callback that captures the first rendered frame to a PNG file,
 * then automatically deregisters itself.
 *
 * This is a convenience function for use with IOSurfaceRenderer's onFrameRendered callback.
 * The returned callback will capture frame 0 and then become a no-op for subsequent frames.
 *
 * @param outputPath The file path where the PNG should be saved
 * @return A callback suitable for passing to runIOSurfaceRenderer's onFrameRendered parameter
 *
 * Example usage:
 * ```kotlin
 * runIOSurfaceRenderer(
 *     surfaceID = surfaceID,
 *     scaleFactor = 2.0f,
 *     onFrameRendered = captureFirstFrame("/tmp/first_frame.png")
 * ) {
 *     MyComposeContent()
 * }
 * ```
 */
fun captureFirstFrame(outputPath: String): (frameNumber: Long, surface: Surface) -> Unit {
    var captured = false

    return { frameNumber, surface ->
        if (!captured && frameNumber == 0L) {
            captured = true
            surface.captureFrameToPNG(outputPath)
        }
    }
}
