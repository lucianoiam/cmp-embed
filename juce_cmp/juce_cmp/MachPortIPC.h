// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#pragma once

#include <cstdint>
#include <string>

namespace juce_cmp
{

/**
 * MachPortIPC - Mach port-based IPC for passing port rights between processes.
 *
 * Uses bootstrap server registration to establish a connection, then sends
 * Mach port rights (e.g., IOSurface ports) via mach_msg().
 *
 * This avoids task_for_pid() which requires restricted entitlements.
 */
class MachPortIPC
{
public:
    MachPortIPC();
    ~MachPortIPC();

    // Non-copyable
    MachPortIPC(const MachPortIPC&) = delete;
    MachPortIPC& operator=(const MachPortIPC&) = delete;

    /**
     * Server side: Create a receive port and register with bootstrap server.
     * Returns the service name to pass to the client.
     */
    std::string createServer();

    /**
     * Server side: Wait for client to connect and send a Mach port right.
     * Returns true on success. Blocks until port is received.
     */
    bool sendPort(uint32_t machPort);

    /**
     * Cleanup server resources.
     */
    void destroyServer();

    /**
     * Get the registered service name (for passing to child process).
     */
    const std::string& getServiceName() const { return serviceName_; }

private:
#if __APPLE__
    uint32_t serverPort_ = 0;  // mach_port_t
#endif
    std::string serviceName_;
};

}  // namespace juce_cmp
