// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

/**
 * ComposeProvider - Creates shared surfaces and manages the child UI process.
 *
 * Uses JUCE APIs where possible:
 * - juce::File for path handling
 * - juce::String for string operations
 * - juce::Logger (DBG) for logging
 *
 * Platform-specific code (macOS):
 * - IOSurface creation (no JUCE equivalent)
 * - fork/exec with stdin pipe (juce::ChildProcess doesn't support stdin writing)
 */
#include "ComposeProvider.h"
#include <juce_core/juce_core.h>
#include <string>

#if JUCE_MAC
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#endif

namespace juce_cmp
{

class ComposeProvider::Impl
{
public:
    Impl() = default;

    ~Impl()
    {
        child.stop();
        releaseSurface();
    }

    bool createSurface(int w, int h)
    {
#if JUCE_MAC
        releaseSurface();
        
        surfaceWidth = w;
        surfaceHeight = h;

        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSDictionary* props = @{
            (id)kIOSurfaceWidth: @(w),
            (id)kIOSurfaceHeight: @(h),
            (id)kIOSurfaceBytesPerElement: @4,
            (id)kIOSurfacePixelFormat: @((uint32_t)'BGRA'),
            (id)kIOSurfaceIsGlobal: @YES  // Required for cross-process lookup
        };
        #pragma clang diagnostic pop
        
        surface = IOSurfaceCreate((__bridge CFDictionaryRef)props);
        
        if (surface != nullptr)
        {
            //DBG("ComposeProvider: Created surface " + juce::String(w) + "x" + juce::String(h)
            //    + ", ID=" + juce::String(IOSurfaceGetID(surface)));
            return true;
        }
        
        DBG("ComposeProvider: Failed to create surface");
        return false;
#else
        juce::ignoreUnused(w, h);
        DBG("ComposeProvider: Not implemented on this platform");
        return false;
#endif
    }

    uint32_t resizeSurface(int w, int h)
    {
#if JUCE_MAC
        surfaceWidth = w;
        surfaceHeight = h;

        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSDictionary* props = @{
            (id)kIOSurfaceWidth: @(w),
            (id)kIOSurfaceHeight: @(h),
            (id)kIOSurfaceBytesPerElement: @4,
            (id)kIOSurfacePixelFormat: @((uint32_t)'BGRA'),
            (id)kIOSurfaceIsGlobal: @YES
        };
        #pragma clang diagnostic pop

        IOSurfaceRef newSurface = IOSurfaceCreate((__bridge CFDictionaryRef)props);
        if (newSurface != nullptr)
        {
            // Keep previous surface alive - view may still be displaying it
            if (previousSurface != nullptr)
                CFRelease(previousSurface);
            previousSurface = surface;
            surface = newSurface;
            return IOSurfaceGetID(surface);
        }
        return 0;
#else
        juce::ignoreUnused(w, h);
        return 0;
#endif
    }

    uint32_t getSurfaceID() const
    {
#if JUCE_MAC
        return surface != nullptr ? IOSurfaceGetID(surface) : 0;
#else
        return 0;
#endif
    }

    void* getNativeSurface() const
    {
#if JUCE_MAC
        return surface;
#else
        return nullptr;
#endif
    }

    int getWidth() const { return surfaceWidth; }
    int getHeight() const { return surfaceHeight; }

    bool launchChild(const juce::String& executable, float scale, const juce::String& workingDir)
    {
#if JUCE_MAC
        if (surface == nullptr)
        {
            DBG("ComposeProvider: No surface, cannot launch child");
            return false;
        }

        uint32_t surfaceID = IOSurfaceGetID(surface);
        return child.launch(executable.toStdString(), surfaceID, scale, workingDir.toStdString());
#else
        juce::ignoreUnused(executable, scale, workingDir);
        return false;
#endif
    }

    void stopChild()
    {
        child.stop();
    }

    bool isChildRunning() const
    {
        return child.isRunning();
    }

    int getInputPipeFD() const
    {
        return child.getStdinPipeFD();
    }

    int getStdoutPipeFD() const
    {
        return child.getStdoutPipeFD();
    }

private:
    void releaseSurface()
    {
#if JUCE_MAC
        if (previousSurface != nullptr)
        {
            CFRelease(previousSurface);
            previousSurface = nullptr;
        }
        if (surface != nullptr)
        {
            CFRelease(surface);
            surface = nullptr;
        }
#endif
    }

#if JUCE_MAC
    IOSurfaceRef surface = nullptr;
    IOSurfaceRef previousSurface = nullptr;  // Keep alive during resize transition
#endif
    ChildProcess child;
    int surfaceWidth = 0;
    int surfaceHeight = 0;
};

// Public interface - delegates to Impl
ComposeProvider::ComposeProvider() : pImpl(std::make_unique<Impl>()) {}
ComposeProvider::~ComposeProvider() = default;

bool ComposeProvider::createSurface(int width, int height) 
{ 
    return pImpl->createSurface(width, height); 
}

uint32_t ComposeProvider::resizeSurface(int width, int height)
{
    return pImpl->resizeSurface(width, height);
}

uint32_t ComposeProvider::getSurfaceID() const 
{ 
    return pImpl->getSurfaceID(); 
}

void* ComposeProvider::getNativeSurface() const 
{ 
    return pImpl->getNativeSurface(); 
}

int ComposeProvider::getWidth() const 
{ 
    return pImpl->getWidth(); 
}

int ComposeProvider::getHeight() const 
{ 
    return pImpl->getHeight(); 
}

bool ComposeProvider::launchChild(const std::string& executable, float scale, const std::string& workingDir) 
{ 
    return pImpl->launchChild(juce::String(executable), scale, juce::String(workingDir)); 
}

void ComposeProvider::stopChild() 
{ 
    pImpl->stopChild(); 
}

bool ComposeProvider::isChildRunning() const 
{ 
    return pImpl->isChildRunning(); 
}

int ComposeProvider::getInputPipeFD() const 
{ 
    return pImpl->getInputPipeFD(); 
}

int ComposeProvider::getStdoutPipeFD() const 
{ 
    return pImpl->getStdoutPipeFD(); 
}

}  // namespace juce_cmp
