/**
 * Input Sender - macOS/Cocoa implementation.
 *
 * Provides functions to send input events to the child Compose process.
 * Uses the binary protocol defined in common/input_protocol.h.
 *
 * The stdin pipe handle must be set via input_set_pipe() after launching
 * the child process.
 */
#import <Foundation/Foundation.h>
#import <mach/mach_time.h>
#include "../common/input_protocol.h"

static NSFileHandle *g_input_pipe = nil;
static uint64_t g_start_time = 0;
static mach_timebase_info_data_t g_timebase = {0};

#pragma mark - Pipe Management

void input_set_pipe(NSFileHandle *pipe) {
    g_input_pipe = pipe;
    g_start_time = mach_absolute_time();
    if (g_timebase.denom == 0) {
        mach_timebase_info(&g_timebase);
    }
}

NSFileHandle *input_get_pipe(void) {
    return g_input_pipe;
}

void input_close_pipe(void) {
    if (g_input_pipe) {
        [g_input_pipe closeFile];
        g_input_pipe = nil;
    }
}

#pragma mark - Internal

static uint32_t get_timestamp_ms(void) {
    uint64_t elapsed = mach_absolute_time() - g_start_time;
    uint64_t nanos = elapsed * g_timebase.numer / g_timebase.denom;
    return (uint32_t)(nanos / 1000000);
}

static void send_event(InputEvent *event) {
    if (!g_input_pipe) return;
    
    event->timestamp = get_timestamp_ms();
    NSData *data = [NSData dataWithBytes:event length:sizeof(InputEvent)];
    
    @try {
        [g_input_pipe writeData:data];
    } @catch (NSException *e) {
        // Child may have exited - close pipe to prevent further errors
        g_input_pipe = nil;
    }
}

#pragma mark - Mouse Events

void input_send_mouse_move(float x, float y, int modifiers) {
    InputEvent event = {
        .type = INPUT_EVENT_MOUSE,
        .action = INPUT_ACTION_MOVE,
        .button = INPUT_BUTTON_NONE,
        .modifiers = (uint8_t)modifiers,
        .x = (int16_t)x,
        .y = (int16_t)y,
        .data1 = 0,
        .data2 = 0
    };
    send_event(&event);
}

void input_send_mouse_button(float x, float y, int button, int pressed, int modifiers) {
    InputEvent event = {
        .type = INPUT_EVENT_MOUSE,
        .action = pressed ? INPUT_ACTION_PRESS : INPUT_ACTION_RELEASE,
        .button = (uint8_t)button,
        .modifiers = (uint8_t)modifiers,
        .x = (int16_t)x,
        .y = (int16_t)y,
        .data1 = 0,
        .data2 = 0
    };
    send_event(&event);
}

void input_send_mouse_scroll(float x, float y, float deltaX, float deltaY, int modifiers) {
    InputEvent event = {
        .type = INPUT_EVENT_MOUSE,
        .action = INPUT_ACTION_SCROLL,
        .button = INPUT_BUTTON_NONE,
        .modifiers = (uint8_t)modifiers,
        .x = (int16_t)x,
        .y = (int16_t)y,
        .data1 = (int16_t)(deltaX * 100),  /* Fixed point: 0.01 precision */
        .data2 = (int16_t)(deltaY * 100)
    };
    send_event(&event);
}

#pragma mark - Keyboard Events

void input_send_key(int keyCode, uint32_t codepoint, int pressed, int modifiers) {
    InputEvent event = {
        .type = INPUT_EVENT_KEY,
        .action = pressed ? INPUT_ACTION_PRESS : INPUT_ACTION_RELEASE,
        .button = 0,
        .modifiers = (uint8_t)modifiers,
        .x = (int16_t)keyCode,
        .y = 0,
        .data1 = (int16_t)(codepoint & 0xFFFF),
        .data2 = (int16_t)((codepoint >> 16) & 0xFFFF)
    };
    send_event(&event);
}

#pragma mark - Window Events

void input_send_focus(int focused) {
    InputEvent event = {
        .type = INPUT_EVENT_FOCUS,
        .action = 0,
        .button = 0,
        .modifiers = 0,
        .x = 0,
        .y = 0,
        .data1 = (int16_t)focused,
        .data2 = 0
    };
    send_event(&event);
}

void input_send_resize(int width, int height, float scale, uint32_t newSurfaceID) {
    // Note: For resize events, we manually set timestamp to the new surface ID
    // and skip send_event() since it would overwrite timestamp with current time
    if (!g_input_pipe) return;
    
    InputEvent event = {
        .type = INPUT_EVENT_RESIZE,
        .action = 0,
        .button = 0,
        .modifiers = 0,
        .x = (int16_t)width,
        .y = (int16_t)height,
        .data1 = (int16_t)(scale * 100),  // Scale factor as fixed-point (200 = 2.0x)
        .data2 = 0,
        .timestamp = newSurfaceID  // This holds the new surface ID for resize events
    };
    
    NSData *data = [NSData dataWithBytes:&event length:sizeof(InputEvent)];
    @try {
        [g_input_pipe writeData:data];
        NSLog(@"Input: Sent resize event %dx%d with surface ID %u", width, height, newSurfaceID);
    } @catch (NSException *e) {
        g_input_pipe = nil;
    }
}
