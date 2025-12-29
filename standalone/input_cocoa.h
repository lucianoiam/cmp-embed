/**
 * Input Sender - Cocoa header for pipe management.
 */
#ifndef INPUT_COCOA_H
#define INPUT_COCOA_H

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#else
typedef struct objc_object NSFileHandle;
#endif

#include "../common/input_protocol.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Pipe management */
void input_set_pipe(NSFileHandle *pipe);
NSFileHandle *input_get_pipe(void);
void input_close_pipe(void);

/* Mouse events */
void input_send_mouse_move(float x, float y, int modifiers);
void input_send_mouse_button(float x, float y, int button, int pressed, int modifiers);
void input_send_mouse_scroll(float x, float y, float deltaX, float deltaY, int modifiers);

/* Keyboard events */
void input_send_key(int keyCode, uint32_t codepoint, int pressed, int modifiers);

/* Window events */
void input_send_focus(int focused);
void input_send_resize(int width, int height);

#ifdef __cplusplus
}
#endif

#endif /* INPUT_COCOA_H */
