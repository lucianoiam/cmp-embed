// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <mach/mach.h>
#import <servers/bootstrap.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>

/**
 * Zero-copy Metal renderer for Compose IOSurface integration.
 *
 * This library provides the Metal device, command queue, and IOSurface-backed
 * texture that Skia can render to directly via DirectContext.makeMetal() and
 * BackendRenderTarget.makeMetal().
 *
 * Architecture:
 * - Kotlin creates a Metal context via createMetalContext()
 * - Kotlin creates an IOSurface-backed texture via createIOSurfaceTexture()
 * - Skia's DirectContext and BackendRenderTarget use these Metal resources
 * - Compose renders directly to the IOSurface - zero CPU pixel copies!
 */

// Metal context holding device and queue
typedef struct {
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
} MetalContext;

// Create Metal context for GPU operations
void* createMetalContext(void) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            return NULL;
        }

        id<MTLCommandQueue> commandQueue = [device newCommandQueue];
        if (commandQueue == nil) {
            return NULL;
        }

        MetalContext* ctx = (MetalContext*)malloc(sizeof(MetalContext));
        ctx->device = device;
        ctx->commandQueue = commandQueue;

        // Prevent ARC from releasing these
        CFRetain((__bridge CFTypeRef)device);
        CFRetain((__bridge CFTypeRef)commandQueue);

        return ctx;
    }
}

// Destroy Metal context
void destroyMetalContext(void* context) {
    if (context == NULL) return;

    @autoreleasepool {
        MetalContext* ctx = (MetalContext*)context;

        CFRelease((__bridge CFTypeRef)ctx->commandQueue);
        CFRelease((__bridge CFTypeRef)ctx->device);

        free(ctx);
    }
}

// Get the MTLDevice pointer for Skia's DirectContext.makeMetal()
void* getMetalDevice(void* context) {
    if (context == NULL) return NULL;
    MetalContext* ctx = (MetalContext*)context;
    return (__bridge void*)ctx->device;
}

// Get the MTLCommandQueue pointer for Skia's DirectContext.makeMetal()
void* getMetalQueue(void* context) {
    if (context == NULL) return NULL;
    MetalContext* ctx = (MetalContext*)context;
    return (__bridge void*)ctx->commandQueue;
}

// Create an IOSurface-backed Metal texture for Skia's BackendRenderTarget.makeMetal()
// Returns the MTLTexture pointer that can be used with BackendRenderTarget.makeMetal()
void* createIOSurfaceTexture(void* context, int surfaceID, int* outWidth, int* outHeight) {
    if (context == NULL) return NULL;

    @autoreleasepool {
        MetalContext* ctx = (MetalContext*)context;

        // Lookup IOSurface by global ID
        IOSurfaceRef surface = IOSurfaceLookup((IOSurfaceID)surfaceID);
        if (surface == NULL) {
            return NULL;
        }

        size_t width = IOSurfaceGetWidth(surface);
        size_t height = IOSurfaceGetHeight(surface);

        if (outWidth) *outWidth = (int)width;
        if (outHeight) *outHeight = (int)height;

        // Create texture descriptor for IOSurface-backed texture
        MTLTextureDescriptor* textureDescriptor = [[MTLTextureDescriptor alloc] init];
        textureDescriptor.width = width;
        textureDescriptor.height = height;
        textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
        textureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        textureDescriptor.storageMode = MTLStorageModeShared;

        // Create texture backed by the IOSurface - this is the zero-copy magic!
        id<MTLTexture> texture = [ctx->device newTextureWithDescriptor:textureDescriptor
                                                             iosurface:surface
                                                                 plane:0];
        CFRelease(surface);

        if (texture == nil) {
            return NULL;
        }

        // Retain the texture so it survives autorelease
        CFRetain((__bridge CFTypeRef)texture);

        return (__bridge void*)texture;
    }
}

// Release an IOSurface-backed texture
void releaseIOSurfaceTexture(void* texturePtr) {
    if (texturePtr == NULL) return;

    @autoreleasepool {
        id<MTLTexture> texture = (__bridge id<MTLTexture>)texturePtr;
        CFRelease((__bridge CFTypeRef)texture);
    }
}

// Flush pending GPU work (call after Skia renders)
void flushAndSync(void* context) {
    if (context == NULL) return;

    @autoreleasepool {
        MetalContext* ctx = (MetalContext*)context;

        // Create a command buffer just to synchronize
        id<MTLCommandBuffer> commandBuffer = [ctx->commandQueue commandBuffer];
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
    }
}

// Read data from a socket file descriptor
// Returns number of bytes read, or -1 on error
ssize_t socketRead(int socketFD, void* buffer, size_t length) {
    return read(socketFD, buffer, length);
}

// Write data to a socket file descriptor
// Returns number of bytes written, or -1 on error
ssize_t socketWrite(int socketFD, const void* buffer, size_t length) {
    return write(socketFD, buffer, length);
}

// Request IOSurface Mach port from parent via bootstrap server
// serviceName: The service name registered by the parent (passed as command line arg)
// Returns: IOSurfaceRef (caller must CFRelease) or NULL on failure
IOSurfaceRef requestIOSurfaceFromMachService(const char* serviceName) {
    if (serviceName == NULL || serviceName[0] == '\0') {
        fprintf(stderr, "No Mach service name provided\n");
        return NULL;
    }

    // Look up the parent's service port
    mach_port_t serverPort;
    kern_return_t kr = bootstrap_look_up(bootstrap_port, (char*)serviceName, &serverPort);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "bootstrap_look_up failed for '%s': %d (%s)\n",
                serviceName, kr, mach_error_string(kr));
        return NULL;
    }

    fprintf(stderr, "Connected to Mach service: %s\n", serviceName);

    // Create a reply port for receiving the IOSurface port
    mach_port_t replyPort;
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &replyPort);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "mach_port_allocate failed: %d\n", kr);
        mach_port_deallocate(mach_task_self(), serverPort);
        return NULL;
    }

    // Send request to server
    struct {
        mach_msg_header_t header;
    } requestMsg = {};

    requestMsg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    requestMsg.header.msgh_size = sizeof(requestMsg);
    requestMsg.header.msgh_remote_port = serverPort;
    requestMsg.header.msgh_local_port = replyPort;
    requestMsg.header.msgh_id = 1;  // Request ID

    kr = mach_msg(
        &requestMsg.header,
        MACH_SEND_MSG,
        sizeof(requestMsg),
        0,
        MACH_PORT_NULL,
        MACH_MSG_TIMEOUT_NONE,
        MACH_PORT_NULL
    );

    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "mach_msg send request failed: %d\n", kr);
        mach_port_deallocate(mach_task_self(), replyPort);
        mach_port_deallocate(mach_task_self(), serverPort);
        return NULL;
    }

    // Receive reply with IOSurface port
    struct {
        mach_msg_header_t header;
        mach_msg_body_t body;
        mach_msg_port_descriptor_t portDescriptor;
        mach_msg_trailer_t trailer;
    } replyMsg = {};

    kr = mach_msg(
        &replyMsg.header,
        MACH_RCV_MSG,
        0,
        sizeof(replyMsg),
        replyPort,
        MACH_MSG_TIMEOUT_NONE,
        MACH_PORT_NULL
    );

    mach_port_deallocate(mach_task_self(), replyPort);
    mach_port_deallocate(mach_task_self(), serverPort);

    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "mach_msg receive reply failed: %d\n", kr);
        return NULL;
    }

    // Extract the IOSurface port from the reply
    mach_port_t surfacePort = replyMsg.portDescriptor.name;
    fprintf(stderr, "Received IOSurface Mach port: %u\n", surfacePort);

    // Look up IOSurface from Mach port
    IOSurfaceRef surface = IOSurfaceLookupFromMachPort(surfacePort);
    if (surface == NULL) {
        fprintf(stderr, "IOSurfaceLookupFromMachPort failed\n");
        mach_port_deallocate(mach_task_self(), surfacePort);
        return NULL;
    }

    // Deallocate our copy of the port (IOSurface retains what it needs)
    mach_port_deallocate(mach_task_self(), surfacePort);

    fprintf(stderr, "Successfully obtained IOSurface from Mach port\n");
    return surface;  // Caller must CFRelease
}

// Create an IOSurface-backed Metal texture from Mach service
// serviceName: The Mach service name (passed from parent)
// Returns: MTLTexture pointer or NULL on failure
void* createIOSurfaceTextureFromMachService(void* context, const char* serviceName, int* outWidth, int* outHeight) {
    if (context == NULL) return NULL;

    @autoreleasepool {
        MetalContext* ctx = (MetalContext*)context;

        // Get IOSurface via Mach IPC
        IOSurfaceRef surface = requestIOSurfaceFromMachService(serviceName);
        if (surface == NULL) {
            return NULL;
        }

        size_t width = IOSurfaceGetWidth(surface);
        size_t height = IOSurfaceGetHeight(surface);

        if (outWidth) *outWidth = (int)width;
        if (outHeight) *outHeight = (int)height;

        // Create texture descriptor for IOSurface-backed texture
        MTLTextureDescriptor* textureDescriptor = [[MTLTextureDescriptor alloc] init];
        textureDescriptor.width = width;
        textureDescriptor.height = height;
        textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
        textureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        textureDescriptor.storageMode = MTLStorageModeShared;

        // Create texture backed by the IOSurface
        id<MTLTexture> texture = [ctx->device newTextureWithDescriptor:textureDescriptor
                                                             iosurface:surface
                                                                 plane:0];
        CFRelease(surface);

        if (texture == nil) {
            return NULL;
        }

        CFRetain((__bridge CFTypeRef)texture);
        return (__bridge void*)texture;
    }
}
