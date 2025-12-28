/**
 * Host Application - Native macOS app that displays Compose UI via IOSurface.
 *
 * Architecture:
 * 1. Creates an IOSurface (shared GPU memory)
 * 2. Displays it via CALayer.contents
 * 3. Launches the Compose UI as a child process
 * 4. UI renders to IOSurface, host sees it immediately (zero-copy)
 *
 * CVDisplayLink drives the refresh to match display vsync.
 */
#import <Cocoa/Cocoa.h>
#import <IOSurface/IOSurface.h>
#import <CoreVideo/CoreVideo.h>
#import "iosurface_provider.h"

/// NSView that displays an IOSurface via its backing CALayer.
/// Uses CVDisplayLink for vsync-synchronized updates.
@interface SurfaceView : NSView
@property (assign) IOSurfaceRef surface;
@property (assign) CVDisplayLinkRef displayLink;
@end

/// CVDisplayLink callback - triggers layer redraw on each vsync.
static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
                                    const CVTimeStamp *now,
                                    const CVTimeStamp *outputTime,
                                    CVOptionFlags flagsIn,
                                    CVOptionFlags *flagsOut,
                                    void *context) {
    SurfaceView *view = (__bridge SurfaceView *)context;
    // Trigger layer update on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [view.layer setNeedsDisplay];
    });
    return kCVReturnSuccess;
}

@implementation SurfaceView

// Enable layer-backing and start display link
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        
        // Create and start CVDisplayLink
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, (__bridge void *)self);
        CVDisplayLinkStart(_displayLink);
    }
    return self;
}

- (void)dealloc {
    if (_displayLink) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
    }
}

// Use updateLayer instead of drawRect
- (BOOL)wantsUpdateLayer {
    return YES;
}

// Set IOSurface as layer contents and mark as changed
- (void)updateLayer {
    self.layer.contents = (__bridge id)self.surface;
    [self.layer setContentsChanged];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (strong) NSWindow *window;
@property (assign) IOSurfaceRef surface;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Create menu with Cmd+W and Cmd+Q
    NSMenu *menuBar = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
    [appMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenuItem setSubmenu:appMenu];
    [NSApp setMainMenu:menuBar];
    
    // Create window
    NSRect frame = NSMakeRect(100, 100, 800, 600);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskTitled |
                                                        NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskResizable |
                                                        NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    // Create IOSurface and get mach port (for child inheritance)
    iosurface_ipc_create_surface(800, 600);
    self.surface = iosurface_ipc_get_surface();
    
    // Draw "Starting child process..." on dark background
    size_t width = IOSurfaceGetWidth(self.surface);
    size_t height = IOSurfaceGetHeight(self.surface);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    IOSurfaceLock(self.surface, 0, NULL);
    CGContextRef ctx = CGBitmapContextCreate(
        IOSurfaceGetBaseAddress(self.surface),
        width, height, 8, IOSurfaceGetBytesPerRow(self.surface),
        colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
    );
    // Dark gray background
    CGContextSetRGBFillColor(ctx, 0.2, 0.2, 0.2, 1.0);
    CGContextFillRect(ctx, CGRectMake(0, 0, width, height));
    // White text centered
    CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0);
    NSString *msg = @"Starting child process...";
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:24],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSSize textSize = [msg sizeWithAttributes:attrs];
    NSPoint point = NSMakePoint((width - textSize.width) / 2, (height - textSize.height) / 2);
    NSGraphicsContext *nsCtx = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsCtx];
    [msg drawAtPoint:point withAttributes:attrs];
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    IOSurfaceUnlock(self.surface, 0, NULL);
    
    // Create view backed by IOSurface
    SurfaceView *view = [[SurfaceView alloc] initWithFrame:[[self.window contentView] bounds]];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view.surface = self.surface;
    
    [self.window setContentView:view];
    [self.window setTitle:@"KMP Embed"];
    [self.window setDelegate:self];
    [self.window makeKeyAndOrderFront:nil];
    
    // Force initial display
    [view.layer setNeedsDisplay];
    [view.layer displayIfNeeded];
    
    // Activate app and bring window to front
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    // Launch renderer as child process (inherits mach port)
    // Use the native distributable for direct child process launch
    // Get path relative to host executable: host/build/kmp-host.app/Contents/MacOS/kmp-host
    // KMP UI is at: ui/composeApp/build/compose/binaries/main/app/kmpui.app/Contents/MacOS/kmpui
    NSString *execPath = [[NSBundle mainBundle] executablePath];
    NSString *projectRoot = [[[[[[execPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    NSString *rendererApp = [projectRoot stringByAppendingPathComponent:@"ui/composeApp/build/compose/binaries/main/app/kmpui.app/Contents/MacOS/kmpui"];
    const char *args[] = { "--embed", NULL };
    iosurface_ipc_launch_child([rendererApp UTF8String], args, NULL);
}

// Exit app when window closes
- (void)windowWillClose:(NSNotification *)notification {
    iosurface_ipc_stop();
    [NSApp terminate:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    iosurface_ipc_stop();
}

@end

// Signal handler for Ctrl+C - ensures child process is terminated
static void signalHandler(int sig) {
    iosurface_ipc_stop();
    exit(0);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Handle Ctrl+C to ensure child cleanup
        signal(SIGINT, signalHandler);
        signal(SIGTERM, signalHandler);
        
        NSApplication *app = [NSApplication sharedApplication];
        // Make app a regular app (shows in Dock, receives keyboard events)
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
