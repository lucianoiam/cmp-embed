// IOSurface IPC - Cross-process sharing via parent-child IOSurface ID
#ifndef IOSURFACE_IPC_H
#define IOSURFACE_IPC_H

#include <IOSurface/IOSurface.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Host (parent) side
void iosurface_ipc_create_surface(int width, int height);
IOSurfaceRef iosurface_ipc_get_surface(void);
uint32_t iosurface_ipc_get_surface_id(void);
void iosurface_ipc_resize_surface(int width, int height);  // Recreates surface at new size
void iosurface_ipc_launch_child(const char *executable, const char *const *args, const char *workingDir);
void iosurface_ipc_stop(void);

// Renderer (child) side - uses IOSurfaceLookup directly
IOSurfaceRef iosurface_ipc_lookup(uint32_t surfaceID);

#ifdef __cplusplus
}
#endif

#endif
