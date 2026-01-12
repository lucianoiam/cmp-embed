// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#pragma once

#include "ipc_protocol.h"

namespace juce_cmp
{

/**
 * InputEvent factory methods - mirrors Kotlin InputEvent data class.
 *
 * Creates properly initialized InputEvent structs for sending to UI.
 */
namespace InputEventFactory
{
    inline InputEvent mouseMove(int x, int y, int modifiers)
    {
        InputEvent e = {};
        e.type = INPUT_EVENT_MOUSE;
        e.action = INPUT_ACTION_MOVE;
        e.modifiers = static_cast<uint8_t>(modifiers);
        e.x = static_cast<int16_t>(x);
        e.y = static_cast<int16_t>(y);
        return e;
    }

    inline InputEvent mouseButton(int x, int y, int button, bool pressed, int modifiers)
    {
        InputEvent e = {};
        e.type = INPUT_EVENT_MOUSE;
        e.action = pressed ? INPUT_ACTION_PRESS : INPUT_ACTION_RELEASE;
        e.button = static_cast<uint8_t>(button);
        e.modifiers = static_cast<uint8_t>(modifiers);
        e.x = static_cast<int16_t>(x);
        e.y = static_cast<int16_t>(y);
        return e;
    }

    inline InputEvent mouseScroll(int x, int y, float deltaX, float deltaY, int modifiers)
    {
        InputEvent e = {};
        e.type = INPUT_EVENT_MOUSE;
        e.action = INPUT_ACTION_SCROLL;
        e.modifiers = static_cast<uint8_t>(modifiers);
        e.x = static_cast<int16_t>(x);
        e.y = static_cast<int16_t>(y);
        e.data1 = static_cast<int16_t>(deltaX * 10000.0f);
        e.data2 = static_cast<int16_t>(deltaY * 10000.0f);
        return e;
    }

    inline InputEvent key(int keyCode, uint32_t codepoint, bool pressed, int modifiers)
    {
        InputEvent e = {};
        e.type = INPUT_EVENT_KEY;
        e.action = pressed ? INPUT_ACTION_PRESS : INPUT_ACTION_RELEASE;
        e.modifiers = static_cast<uint8_t>(modifiers);
        e.x = static_cast<int16_t>(keyCode);
        e.data1 = static_cast<int16_t>(codepoint & 0xFFFF);
        e.data2 = static_cast<int16_t>((codepoint >> 16) & 0xFFFF);
        return e;
    }

    inline InputEvent focus(bool focused)
    {
        InputEvent e = {};
        e.type = INPUT_EVENT_FOCUS;
        e.data1 = focused ? 1 : 0;
        return e;
    }

    inline InputEvent resize(int width, int height, float scale, uint32_t surfaceID)
    {
        InputEvent e = {};
        e.type = INPUT_EVENT_RESIZE;
        e.x = static_cast<int16_t>(width);
        e.y = static_cast<int16_t>(height);
        e.data1 = static_cast<int16_t>(scale * 100);
        e.timestamp = surfaceID;
        return e;
    }
}

}  // namespace juce_cmp
