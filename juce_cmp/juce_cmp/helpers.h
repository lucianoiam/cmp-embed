// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

namespace juce_cmp
{
namespace helpers
{

/**
 * Hides the native resize corner while keeping it functional.
 *
 * Call this after setResizable(true, true) on your editor. The corner remains
 * active but is invisible (alpha 0). This avoids unnecessary IPC for resize
 * handle functionality. Optionally, use juce_cmp.widgets.ResizeHandle() on the
 * Kotlin side to draw a visual indicator.
 */
inline void hideResizeHandle(juce::AudioProcessorEditor& editor)
{
    for (int i = 0; i < editor.getNumChildComponents(); ++i)
    {
        if (auto* corner = dynamic_cast<juce::ResizableCornerComponent*>(editor.getChildComponent(i)))
        {
            corner->setAlpha(0.0f);
            break;
        }
    }
}

}  // namespace helpers
}  // namespace juce_cmp
