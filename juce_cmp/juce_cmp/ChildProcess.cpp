// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#include "ChildProcess.h"

#include <vector>

#if __APPLE__ || __linux__
#include <unistd.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/socket.h>

extern char** environ;
#endif

namespace juce_cmp
{

ChildProcess::ChildProcess() = default;

ChildProcess::~ChildProcess()
{
    stop();
}

bool ChildProcess::launch(const std::string& executable,
                          float scale,
                          const std::string& machServiceName,
                          const std::string& workingDir)
{
#if __APPLE__ || __linux__
    // Verify executable exists
    struct stat st;
    if (stat(executable.c_str(), &st) != 0)
        return false;

    std::string scaleArg = "--scale=" + std::to_string(scale);
    std::string machServiceArg;
    if (!machServiceName.empty())
        machServiceArg = "--mach-service=" + machServiceName;

    // Create Unix socket pair for bidirectional IPC
    int sockets[2];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) != 0)
        return false;

    // Build argument list
    std::string socketArg = "--socket-fd=" + std::to_string(sockets[1]);

    std::vector<char*> argv;
    argv.push_back(const_cast<char*>(executable.c_str()));
    argv.push_back(const_cast<char*>(socketArg.c_str()));
    argv.push_back(const_cast<char*>(scaleArg.c_str()));
    if (!machServiceArg.empty())
        argv.push_back(const_cast<char*>(machServiceArg.c_str()));
    argv.push_back(nullptr);

    // Set up file actions to close parent's socket end in child
    posix_spawn_file_actions_t fileActions;
    posix_spawn_file_actions_init(&fileActions);
    posix_spawn_file_actions_addclose(&fileActions, sockets[0]);

    // Set working directory (macOS 10.15+, glibc 2.29+)
    if (!workingDir.empty())
        posix_spawn_file_actions_addchdir_np(&fileActions, workingDir.c_str());

    // Spawn the child process
    pid_t pid;
    int result = posix_spawn(&pid, executable.c_str(), &fileActions, nullptr, argv.data(), environ);

    posix_spawn_file_actions_destroy(&fileActions);

    if (result != 0)
    {
        close(sockets[0]);
        close(sockets[1]);
        return false;
    }

    // Parent: close child's socket end, keep ours
    close(sockets[1]);
    socketFD_ = sockets[0];
    childPid_ = pid;

    return true;
#else
    (void)executable;
    (void)scale;
    (void)machServiceName;
    (void)workingDir;
    return false;
#endif
}

void ChildProcess::stop()
{
#if __APPLE__ || __linux__
    // Close socket first - signals EOF to child
    if (socketFD_ >= 0)
    {
        close(socketFD_);
        socketFD_ = -1;
    }

    if (childPid_ > 0)
    {
        int status;

        // Check if already exited (non-blocking)
        pid_t result = waitpid(childPid_, &status, WNOHANG);
        if (result != 0)
        {
            childPid_ = 0;
            return;
        }

        // Send SIGTERM and check once more (non-blocking)
        kill(childPid_, SIGTERM);
        result = waitpid(childPid_, &status, WNOHANG);
        if (result != 0)
        {
            childPid_ = 0;
            return;
        }

        // Force kill - child will become zombie until reaped
        kill(childPid_, SIGKILL);
        // Non-blocking reap - zombie is harmless, OS cleans up on parent exit
        waitpid(childPid_, &status, WNOHANG);
        childPid_ = 0;
    }
#endif
}

bool ChildProcess::isRunning() const
{
#if __APPLE__ || __linux__
    if (childPid_ <= 0)
        return false;
    return kill(childPid_, 0) == 0;
#else
    return false;
#endif
}

int ChildProcess::getSocketFD() const
{
    return socketFD_;
}

}  // namespace juce_cmp
