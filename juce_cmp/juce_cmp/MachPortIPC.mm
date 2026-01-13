// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#include "MachPortIPC.h"

#if __APPLE__
#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <unistd.h>
#include <cstdio>
#endif

namespace juce_cmp
{

MachPortIPC::MachPortIPC() = default;

MachPortIPC::~MachPortIPC()
{
    destroyServer();
}

std::string MachPortIPC::createServer()
{
#if __APPLE__
    // Generate unique service name using PID
    char name[64];
    snprintf(name, sizeof(name), "com.juce-cmp.surface.%d", getpid());
    serviceName_ = name;

    // Check in with bootstrap server - creates the service and gives us a receive port
    mach_port_t port;
    kern_return_t kr = bootstrap_check_in(bootstrap_port, const_cast<char*>(serviceName_.c_str()), &port);
    if (kr != KERN_SUCCESS)
    {
        fprintf(stderr, "bootstrap_check_in failed: %d (%s)\n", kr, mach_error_string(kr));
        serviceName_.clear();
        return "";
    }

    serverPort_ = (uint32_t)port;
    fprintf(stderr, "Registered Mach service: %s\n", serviceName_.c_str());
    return serviceName_;
#else
    return "";
#endif
}

bool MachPortIPC::sendPort(uint32_t machPort)
{
#if __APPLE__
    if (serverPort_ == 0)
        return false;

    // Wait for a message from the client (a request for the port)
    // The client sends us a send-once right to reply to
    struct {
        mach_msg_header_t header;
        mach_msg_trailer_t trailer;
    } requestMsg = {};

    kern_return_t kr = mach_msg(
        &requestMsg.header,
        MACH_RCV_MSG,
        0,
        sizeof(requestMsg),
        (mach_port_t)serverPort_,
        MACH_MSG_TIMEOUT_NONE,
        MACH_PORT_NULL
    );

    if (kr != KERN_SUCCESS)
    {
        fprintf(stderr, "mach_msg receive failed: %d\n", kr);
        return false;
    }

    fprintf(stderr, "Received request from client, sending port %u\n", machPort);

    // Reply with the IOSurface Mach port
    // Use complex message with port descriptor
    struct {
        mach_msg_header_t header;
        mach_msg_body_t body;
        mach_msg_port_descriptor_t portDescriptor;
    } replyMsg = {};

    replyMsg.header.msgh_bits = MACH_MSGH_BITS_COMPLEX | MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND_ONCE, 0);
    replyMsg.header.msgh_size = sizeof(replyMsg);
    replyMsg.header.msgh_remote_port = requestMsg.header.msgh_remote_port;
    replyMsg.header.msgh_local_port = MACH_PORT_NULL;
    replyMsg.header.msgh_id = requestMsg.header.msgh_id + 100;  // Convention: reply ID = request ID + 100

    replyMsg.body.msgh_descriptor_count = 1;

    replyMsg.portDescriptor.name = (mach_port_t)machPort;
    replyMsg.portDescriptor.disposition = MACH_MSG_TYPE_COPY_SEND;  // Copy send right to receiver
    replyMsg.portDescriptor.type = MACH_MSG_PORT_DESCRIPTOR;

    kr = mach_msg(
        &replyMsg.header,
        MACH_SEND_MSG,
        sizeof(replyMsg),
        0,
        MACH_PORT_NULL,
        MACH_MSG_TIMEOUT_NONE,
        MACH_PORT_NULL
    );

    if (kr != KERN_SUCCESS)
    {
        fprintf(stderr, "mach_msg send failed: %d\n", kr);
        return false;
    }

    fprintf(stderr, "Sent IOSurface port to client\n");
    return true;
#else
    (void)machPort;
    return false;
#endif
}

void MachPortIPC::destroyServer()
{
#if __APPLE__
    if (serverPort_ != 0)
    {
        mach_port_deallocate(mach_task_self(), (mach_port_t)serverPort_);
        serverPort_ = 0;
    }
    serviceName_.clear();
#endif
}

}  // namespace juce_cmp
