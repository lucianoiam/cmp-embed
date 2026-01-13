# macOS Implementation Notes

## IOSurface Sharing

IOSurface is used for zero-copy GPU texture sharing between the host (JUCE plugin) and child (Compose UI) processes.

### Current Implementation

Uses `kIOSurfaceIsGlobal` flag with `IOSurfaceLookup()`:

```objc
// Host creates surface with global flag
NSDictionary* props = @{
    (id)kIOSurfaceWidth: @(width),
    (id)kIOSurfaceHeight: @(height),
    (id)kIOSurfaceBytesPerElement: @4,
    (id)kIOSurfacePixelFormat: @((uint32_t)'BGRA'),
    (id)kIOSurfaceIsGlobal: @YES  // Deprecated but required
};
IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)props);

// Host sends 4-byte surface ID via socket
uint32_t surfaceID = IOSurfaceGetID(surface);
write(socketFD, &surfaceID, sizeof(surfaceID));

// Child looks up by ID
IOSurfaceRef surface = IOSurfaceLookup(surfaceID);
```

**Note**: `kIOSurfaceIsGlobal` is deprecated but still functional. The deprecation warning is suppressed with `#pragma clang diagnostic ignored "-Wdeprecated-declarations"`.

### Failed Alternatives

Several approaches were investigated to eliminate the deprecated `kIOSurfaceIsGlobal` flag:

#### 1. SCM_RIGHTS with fileport (Failed)

**Goal**: Convert Mach port to FD, pass via `SCM_RIGHTS`, convert back.

```cpp
// Host side
mach_port_t machPort = IOSurfaceCreateMachPort(surface);
int fd = fileport_makefd(machPort);  // Private API
// Send fd via SCM_RIGHTS using sendmsg()

// Child side
mach_port_t machPort = fileport_makeport(fd);  // Private API
IOSurfaceRef surface = IOSurfaceLookupFromMachPort(machPort);
```

**Result**: `fileport_makefd()` returned `-1`.

**Root cause**: `fileport_makefd/makeport` wrap Unix FDs as Mach ports (for XPC), not vice versa. SCM_RIGHTS only passes Unix file descriptors.

#### 2. task_set_special_port / task_get_special_port (Failed)

**Goal**: Parent sets IOSurface Mach port in child's task, child retrieves it.

```cpp
// Host side (after fork)
mach_port_t childTask;
task_for_pid(mach_task_self(), childPid, &childTask);
mach_port_t surfacePort = IOSurfaceCreateMachPort(surface);
task_set_special_port(childTask, TASK_BOOTSTRAP_PORT, surfacePort);

// Child side
mach_port_t surfacePort;
task_get_special_port(mach_task_self(), TASK_BOOTSTRAP_PORT, &surfacePort);
IOSurfaceRef surface = IOSurfaceLookupFromMachPort(surfacePort);
```

**Result**: `task_for_pid()` failed with `KERN_FAILURE` (kr=5).

**Root cause**: `task_for_pid()` requires the `com.apple.security.cs.debugger` entitlement on modern macOS. Despite the name, this entitlement controls access to another process's task port (used by debuggers but also needed for Mach port manipulation). Even parent→child access after fork requires this entitlement, which must be code-signed by Apple or with SIP disabled.

#### 3. XPC (Not implemented - overkill)

- Use `IOSurfaceCreateXPCObject()` to wrap surface
- Requires XPC service with launchd plist
- Significant architecture change for cross-platform project

#### 4. Direct Mach IPC via mach_msg() (Not implemented)

- Send port rights directly with `mach_msg()`
- Requires bootstrap server registration
- Complex low-level API

### Conclusion

None of the Mach port-based alternatives were ever viable for this use case:

- **SCM_RIGHTS**: Only passes Unix FDs, not Mach ports
- **task_for_pid()**: Requires restricted entitlements that regular apps cannot obtain
- **XPC**: Requires launchd infrastructure, impractical for cross-platform project
- **mach_msg()**: Requires bootstrap server registration, excessive complexity

The `kIOSurfaceIsGlobal` + `IOSurfaceLookup()` approach is the only practical solution. Apple deprecated it but hasn't removed it because there's no simple replacement for cross-process IOSurface sharing outside of XPC. The deprecation is cosmetic - it works reliably.

## IPC Channel

Uses `socketpair(AF_UNIX, SOCK_STREAM, 0, sockets)` for bidirectional communication:

- Single socket pair replaces previous stdin/stdout pipes
- Bidirectional: host and child can send/receive on same FD
- Simpler than managing two separate pipes
- Child receives socket FD via `--socket-fd=N` argument

## References

- [IOSurface Programming Guide](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/IOSurface/)
- [Cross-process Rendering (Russ Bishop)](http://www.russbishop.net/cross-process-rendering)
- [Mach Ports (fdiv.net)](https://fdiv.net/category/apple/mach-ports)
