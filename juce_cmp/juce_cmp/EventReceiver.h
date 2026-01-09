// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#pragma once

#include <juce_core/juce_core.h>
#include <juce_data_structures/juce_data_structures.h>
#include <functional>
#include <thread>
#include <atomic>
#include <mutex>
#include <unistd.h>

namespace juce_cmp
{

/**
 * EventReceiver - Receives ValueTree messages from UI process (UI → host direction).
 *
 * Protocol (little-endian):
 * - 4 bytes: message size
 * - N bytes: ValueTree binary data (JUCE-compatible format)
 *
 * The UI process uses EventSender to write JuceValueTree data to stdout.
 * System.out is redirected to stderr so JVM library noise doesn't corrupt the protocol.
 *
 * Runs a background thread that reads messages and dispatches to registered handler.
 * Events are coalesced by type to prevent message queue flooding during rapid updates.
 *
 * Note: This is the C++ EventReceiver (UI → host direction).
 * The Kotlin EventReceiver in juce_cmp.events handles the opposite direction (host → UI).
 */
class EventReceiver
{
public:
    using CustomEventHandler = std::function<void(const juce::ValueTree& tree)>;

    EventReceiver() = default;
    ~EventReceiver() { stop(); }

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
                    enqueue(tree);
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

    /** 
     * Enqueue a tree for dispatch, coalescing by type+id to avoid flooding.
     * Only one pending dispatch per unique key is allowed.
     * For "param" type, coalesces by type+id property.
     */
    void enqueue(const juce::ValueTree& tree)
    {
        if (!onCustomEvent) return;
        
        // Build coalescing key: type + optional id for param events
        auto typeStr = tree.getType().toString();
        juce::String key = typeStr;
        if (typeStr == "param" && tree.hasProperty("id"))
            key += "_" + tree.getProperty("id").toString();
        
        {
            std::lock_guard<std::mutex> lock(pendingMutex);
            bool wasEmpty = pendingTrees.find(key) == pendingTrees.end();
            pendingTrees[key] = tree;
            
            // Only schedule dispatch if this is a new key (no pending dispatch for it)
            if (!wasEmpty) return;
        }
        
        juce::MessageManager::callAsync([this, key]() {
            juce::ValueTree treeToDispatch;
            {
                std::lock_guard<std::mutex> lock(pendingMutex);
                auto it = pendingTrees.find(key);
                if (it != pendingTrees.end())
                {
                    treeToDispatch = it->second;
                    pendingTrees.erase(it);
                }
            }
            
            if (treeToDispatch.isValid() && onCustomEvent)
                onCustomEvent(treeToDispatch);
        });
    }

    int fd = -1;
    std::atomic<bool> running { false };
    std::thread readerThread;
    CustomEventHandler onCustomEvent;
    
    // Coalescing: one pending tree per type
    std::mutex pendingMutex;
    std::map<juce::String, juce::ValueTree> pendingTrees;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EventReceiver)
};

}  // namespace juce_cmp
