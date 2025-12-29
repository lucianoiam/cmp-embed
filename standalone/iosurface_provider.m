/**
 * IOSurface Provider - Creates shared GPU memory for cross-process rendering.
 *
 * The standalone app creates an IOSurface and launches the UI process, passing the surface ID.
 * The UI process looks up the surface by ID and renders directly to it.
 *
 * Note: kIOSurfaceIsGlobal is deprecated but required for IOSurfaceLookup() to work
 * across processes without XPC/Mach port passing. Works fine for parent-child IPC.
 */
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#import "input_cocoa.h"

static IOSurfaceRef g_surface = NULL;
static NSTask *g_child_task = nil;

#pragma mark - Standalone (Parent) API

/// Create a shared IOSurface with the given dimensions.
void iosurface_ipc_create_surface(int width, int height) {
    NSDictionary *props = @{
        (id)kIOSurfaceWidth: @(width),
        (id)kIOSurfaceHeight: @(height),
        (id)kIOSurfaceBytesPerElement: @4,
        (id)kIOSurfacePixelFormat: @((uint32_t)'BGRA'),
        // Required for cross-process lookup without XPC - deprecated but still works
        (id)kIOSurfaceIsGlobal: @YES
    };
    g_surface = IOSurfaceCreate((__bridge CFDictionaryRef)props);
    NSLog(@"IPC: Created surface %p, ID=%u", g_surface, IOSurfaceGetID(g_surface));
}

/// Get the current IOSurface reference.
IOSurfaceRef iosurface_ipc_get_surface(void) {
    return g_surface;
}

/// Get the surface ID (passed to child process via command line).
uint32_t iosurface_ipc_get_surface_id(void) {
    return g_surface ? IOSurfaceGetID(g_surface) : 0;
}

/**
 * Create a new IOSurface at the given dimensions.
 *
 * This is used during resize for double-buffering. The caller (SurfaceView)
 * manages the transition from old to new surface:
 * 1. Call this to create new surface
 * 2. Tell child to render to new surface
 * 3. Wait for child to render
 * 4. Swap display to new surface
 * 5. Release old surface
 *
 * Note: This does NOT release the old surface - caller must manage that
 * for proper double-buffering.
 *
 * @param width  New width in pixels
 * @param height New height in pixels
 */
void iosurface_ipc_resize_surface(int width, int height) {
    // Create new surface at new size (old surface is managed by SurfaceView)
    NSDictionary *props = @{
        (id)kIOSurfaceWidth: @(width),
        (id)kIOSurfaceHeight: @(height),
        (id)kIOSurfaceBytesPerElement: @4,
        (id)kIOSurfacePixelFormat: @((uint32_t)'BGRA'),
        (id)kIOSurfaceIsGlobal: @YES
    };
    g_surface = IOSurfaceCreate((__bridge CFDictionaryRef)props);
    
    NSLog(@"IPC: Created new surface %dx%d, ID=%u", width, height, IOSurfaceGetID(g_surface));
}

/// Launch child process with --embed and --iosurface-id=<id> arguments.
/// Sets up stdin pipe for input forwarding.
void iosurface_ipc_launch_child(const char *executable, const char *const *args, const char *workingDir) {
    if (!g_surface) {
        NSLog(@"IPC: No surface created, cannot launch child");
        return;
    }
    
    g_child_task = [[NSTask alloc] init];
    g_child_task.executableURL = [NSURL fileURLWithPath:@(executable)];
    
    // Build arguments array
    NSMutableArray *argsArray = [NSMutableArray array];
    if (args) {
        for (int i = 0; args[i] != NULL; i++) {
            [argsArray addObject:@(args[i])];
        }
    }
    // Pass surface ID as argument
    [argsArray addObject:[NSString stringWithFormat:@"--iosurface-id=%u", IOSurfaceGetID(g_surface)]];
    g_child_task.arguments = argsArray;
    
    if (workingDir) {
        g_child_task.currentDirectoryURL = [NSURL fileURLWithPath:@(workingDir)];
    }
    
    // Set up stdin pipe for input forwarding
    NSPipe *stdinPipe = [NSPipe pipe];
    g_child_task.standardInput = stdinPipe;
    input_set_pipe([stdinPipe fileHandleForWriting]);
    
    NSError *error = nil;
    [g_child_task launchAndReturnError:&error];
    if (error) {
        NSLog(@"IPC: Failed to launch child: %@", error);
        input_close_pipe();
    } else {
        NSLog(@"IPC: Launched child with IOSurface ID %u", IOSurfaceGetID(g_surface));
    }
}

/// Terminate child process and release the IOSurface.
void iosurface_ipc_stop(void) {
    input_close_pipe();
    if (g_child_task && g_child_task.isRunning) {
        [g_child_task terminate];
    }
    g_child_task = nil;
    if (g_surface) {
        CFRelease(g_surface);
        g_surface = NULL;
    }
}

#pragma mark - Client (Child) API

/// Look up an IOSurface by ID (called from child process).
IOSurfaceRef iosurface_ipc_lookup(uint32_t surfaceID) {
    IOSurfaceRef surface = IOSurfaceLookup(surfaceID);
    NSLog(@"IPC: Lookup ID %u -> %p", surfaceID, surface);
    return surface;
}
