// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.widgets

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Draws a resize handle indicator in the bottom-right corner.
 *
 * Use this in conjunction with juce_cmp::helpers::hideResizeHandle() on the
 * C++ side, which hides the native JUCE resize corner while keeping it
 * functional. This avoids unnecessary IPC for resize handle functionality.
 */
@Composable
fun ResizeHandle(
    modifier: Modifier = Modifier,
    color: Color = Color.DarkGray.copy(alpha = 0.7f)
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .padding(bottom = 3.dp, end = 3.dp),
        contentAlignment = Alignment.BottomEnd
    ) {
        Canvas(modifier = Modifier.size(16.dp)) {
            val strokeWidth = 2f

            // Draw three diagonal lines like JUCE resize handle
            // Bottom line (longest)
            drawLine(
                color = color,
                start = Offset(size.width - 4.dp.toPx(), size.height),
                end = Offset(size.width, size.height - 4.dp.toPx()),
                strokeWidth = strokeWidth
            )

            // Middle line
            drawLine(
                color = color,
                start = Offset(size.width - 8.dp.toPx(), size.height),
                end = Offset(size.width, size.height - 8.dp.toPx()),
                strokeWidth = strokeWidth
            )

            // Top line (shortest)
            drawLine(
                color = color,
                start = Offset(size.width - 12.dp.toPx(), size.height),
                end = Offset(size.width, size.height - 12.dp.toPx()),
                strokeWidth = strokeWidth
            )
        }
    }
}
