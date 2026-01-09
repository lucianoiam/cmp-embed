// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#pragma once

#include <juce_core/juce_core.h>
#include <juce_data_structures/juce_data_structures.h>
#include <functional>
#include <thread>
#include <atomic>
#include <unistd.h>

namespace juce_cmp
{

/**
 * UIReceiver - Reads ValueTree messages from UI process via stdout pipe.
 *
 * Protocol (little-endian):
 * - 4 bytes: message size
 * - N bytes: ValueTree binary data
 *
 * The UI process redirects System.out to stderr, then uses the raw stdout fd
 * for binary IPC. This prevents JVM library noise from corrupting the protocol.
 *
 * Runs a background thread that reads messages and dispatches to registered handler.
 */
class UIReceiver
{
public:
    using CustomEventHandler = std::function<void(const juce::ValueTree& tree)>;

    UIReceiver() = default;
    ~UIReceiver() { stop(); }

    void setCustomEventHandler(CustomEventHandler handler) { onCustomEvent = std::move(handler); }

    void start(int stdoutPipeFD)
    {
        if (running.load()) return;
        if (stdoutPipeFD < 0) return;
        
        fd = stdoutPipeFD;
        running.store(true);
        
        readerThread = std::thread([this]() {
            while (running.load())
            {
                // Read message size (4 bytes, little-endian)
                uint32_t size = 0;
                ssize_t bytesRead = readFully(&size, sizeof(size));
                if (bytesRead != sizeof(size))
                    break;
                
                // Sanity check
                if (size == 0 || size > 1024 * 1024)  // Max 1MB
                    break;
                
                // Read message data
                juce::MemoryBlock data(size);
                bytesRead = readFully(data.getData(), size);
                if (bytesRead != static_cast<ssize_t>(size))
                    break;
                
                // Parse as ValueTree
                auto tree = juce::ValueTree::readFromData(data.getData(), size);
                if (tree.isValid())
                    dispatch(tree);
            }
        });
    }

    void stop()
    {
        running.store(false);
        // Note: We don't close fd here - it's owned by IOSurfaceProvider
        if (readerThread.joinable())
            readerThread.join();
    }

private:
    ssize_t readFully(void* buffer, size_t size)
    {
        size_t totalRead = 0;
        auto* ptr = static_cast<uint8_t*>(buffer);
        
        while (totalRead < size && running.load())
        {
            ssize_t n = ::read(fd, ptr + totalRead, size - totalRead);
            if (n <= 0) return totalRead > 0 ? static_cast<ssize_t>(totalRead) : n;
            totalRead += static_cast<size_t>(n);
        }
        return static_cast<ssize_t>(totalRead);
    }

    void dispatch(const juce::ValueTree& tree)
    {
        if (onCustomEvent)
        {
            juce::MessageManager::callAsync([this, tree]() {
                if (onCustomEvent)
                    onCustomEvent(tree);
            });
        }
    }

    int fd = -1;
    std::atomic<bool> running { false };
    std::thread readerThread;
    CustomEventHandler onCustomEvent;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UIReceiver)
};

}  // namespace juce_cmp
