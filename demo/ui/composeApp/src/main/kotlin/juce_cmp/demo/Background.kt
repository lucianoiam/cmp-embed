// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.demo

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

@Composable
fun Background() = Box(
    Modifier
        .fillMaxSize()
        // NOTE: This should match the loading screen background in PluginEditor.cpp (juce::Colour(0xFF6F97FF))
        .background(Color(0xFF6F97FF))
)
