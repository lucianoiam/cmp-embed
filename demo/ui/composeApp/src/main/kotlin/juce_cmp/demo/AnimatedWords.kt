// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.demo

import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.sp

@Composable
fun AnimatedWords() {
    val duration = 5000

    val infiniteTransition = rememberInfiniteTransition()
    // Start at initial angle (-50f) so first frame is predictable
    val angle by infiniteTransition.animateFloat(
        initialValue = -50f,
        targetValue = 30f,
        animationSpec = infiniteRepeatable(
            animation = tween(duration, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    // Start at initial scale (1f) so first frame is predictable
    val scale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 7f,
        animationSpec = infiniteRepeatable(
            animation = tween(duration, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    val color1 = Color(0x6B, 0x57, 0xFF)
    val color2 = Color(0xFE, 0x28, 0x57)
    val color3 = Color(0xFD, 0xB6, 0x0D)
    val color4 = Color(0xFC, 0xF8, 0x4A)

    BoxWithConstraints(
        modifier = Modifier.fillMaxSize()
    ) {
        val centerX = maxWidth / 2
        val centerY = maxHeight / 2

        // Position rotating words closer to center (reduced margin)
        val marginH = maxWidth * 0.2f
        val marginV = maxHeight * 0.2f
        Word(position = DpOffset(marginH, marginV), angle = angle, scale = scale, text = "Hello", color = color1)
        Word(position = DpOffset(marginH, maxHeight - marginV), angle = angle, scale = scale, text = "こんにちは", color = color2)
        Word(position = DpOffset(maxWidth - marginH, marginV), angle = angle, scale = scale, text = "你好", color = color3)
        Word(position = DpOffset(maxWidth - marginH, maxHeight - marginV), angle = angle, scale = scale, text = "Привет", color = color4)
    }
}

@Composable
fun Word(
    position: DpOffset,
    angle: Float,
    scale: Float,
    text: String,
    color: Color,
    alpha: Float = 0.8f,
    fontSize: androidx.compose.ui.unit.TextUnit = 16.sp,
    textAlign: androidx.compose.ui.text.style.TextAlign? = null
) {
    Text(
        modifier = Modifier
            .offset(position.x, position.y)
            .rotate(angle)
            .scale(scale)
            .alpha(alpha),
        color = color,
        fontWeight = FontWeight.Bold,
        text = text,
        fontSize = fontSize,
        textAlign = textAlign
    )
}
