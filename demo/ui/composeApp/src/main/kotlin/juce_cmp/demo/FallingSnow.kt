// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.demo

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlin.random.Random

@Composable
fun FallingSnow() {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        repeat(50) {
            val size = remember { 20.dp + 10.dp * Random.nextFloat() }
            val alpha = remember { 0.10f + 0.15f * Random.nextFloat() }
            val sizePx = with(LocalDensity.current) { size.toPx() }
            val x = remember { (constraints.maxWidth * Random.nextFloat()).toInt() }

            val infiniteTransition = rememberInfiniteTransition()
            val t by infiniteTransition.animateFloat(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(16000 + (16000 * Random.nextFloat()).toInt(), easing = LinearEasing),
                    repeatMode = RepeatMode.Restart
                )
            )
            // All balls start from top (initialT = 0) so first frame is clean
            val y = (-sizePx + (constraints.maxHeight + sizePx) * t).toInt()

            Box(
                Modifier
                    .offset { IntOffset(x, y) }
                    .clip(CircleShape)
                    .alpha(alpha)
                    .background(Color.White)
                    .size(size)
            )
        }
    }
}
