// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.demo

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun Title() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 24.dp),
        contentAlignment = Alignment.TopCenter
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "JUCE",
                color = Color(52, 67, 235),
                fontWeight = FontWeight.Bold,
                fontSize = (16 * 6 * 0.25f).sp,
                modifier = Modifier.alpha(0.4f)
            )
            Text(
                text = "+",
                color = Color(52, 67, 235),
                fontWeight = FontWeight.Bold,
                fontSize = (16 * 6 * 0.25f).sp,
                modifier = Modifier.alpha(0.4f)
            )
            Text(
                text = "Compose",
                color = Color(52, 67, 235),
                fontWeight = FontWeight.Bold,
                fontSize = (16 * 6 * 0.25f).sp,
                modifier = Modifier.alpha(0.4f)
            )
            Text(
                text = "Multiplatform",
                color = Color(52, 67, 235),
                fontWeight = FontWeight.Bold,
                fontSize = (16 * 6 * 0.25f).sp,
                modifier = Modifier.alpha(0.4f)
            )
        }
    }
}
