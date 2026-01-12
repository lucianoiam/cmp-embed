// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#include "ChildProcess.h"

#if __APPLE__ || __linux__
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/stat.h>
#endif

namespace juce_cmp
{

ChildProcess::ChildProcess() = default;

ChildProcess::~ChildProcess()
{
    stop();
}

bool ChildProcess::launch(const std::string& executable,
                          uint32_t surfaceID,
                          float scale,
                          const std::string& workingDir)
{
#if __APPLE__ || __linux__
    // Verify executable exists
    struct stat st;
    if (stat(executable.c_str(), &st) != 0)
        return false;

    std::string surfaceArg = "--iosurface-id=" + std::to_string(surfaceID);
    std::string scaleArg = "--scale=" + std::to_string(scale);

    // Create pipe for stdin (host -> child)
    int stdinPipes[2];
    if (pipe(stdinPipes) != 0)
        return false;

    // Create pipe for stdout (child -> host)
    int stdoutPipes[2];
    if (pipe(stdoutPipes) != 0)
    {
        close(stdinPipes[0]);
        close(stdinPipes[1]);
        return false;
    }

    childPid_ = fork();

    if (childPid_ == 0)
    {
        // Child process
        close(stdinPipes[1]);   // Close write end of stdin pipe
        close(stdoutPipes[0]);  // Close read end of stdout pipe

        dup2(stdinPipes[0], STDIN_FILENO);   // Redirect stdin
        dup2(stdoutPipes[1], STDOUT_FILENO); // Redirect stdout
        close(stdinPipes[0]);
        close(stdoutPipes[1]);

        if (!workingDir.empty())
            chdir(workingDir.c_str());

        execl(executable.c_str(),
              executable.c_str(),
              surfaceArg.c_str(),
              scaleArg.c_str(),
              nullptr);

        // If exec fails, exit child
        _exit(1);
    }
    else if (childPid_ > 0)
    {
        // Parent process
        close(stdinPipes[0]);   // Close read end of stdin pipe
        close(stdoutPipes[1]);  // Close write end of stdout pipe

        stdinPipeFD_ = stdinPipes[1];
        stdoutPipeFD_ = stdoutPipes[0];

        return true;
    }
    else
    {
        // Fork failed
        close(stdinPipes[0]);
        close(stdinPipes[1]);
        close(stdoutPipes[0]);
        close(stdoutPipes[1]);
        return false;
    }
#else
    (void)executable;
    (void)surfaceID;
    (void)scale;
    (void)workingDir;
    return false;
#endif
}

void ChildProcess::stop()
{
#if __APPLE__ || __linux__
    // Close stdin pipe first - signals EOF to child
    if (stdinPipeFD_ >= 0)
    {
        close(stdinPipeFD_);
        stdinPipeFD_ = -1;
    }

    // Wait for child to exit with timeout, then force kill
    if (childPid_ > 0)
    {
        int status;
        // Give child 200ms to exit gracefully
        for (int i = 0; i < 20; ++i)
        {
            pid_t result = waitpid(childPid_, &status, WNOHANG);
            if (result != 0)
            {
                childPid_ = 0;
                break;
            }
            usleep(10000);  // 10ms
        }

        // If still alive, force kill
        if (childPid_ > 0)
        {
            kill(childPid_, SIGKILL);
            waitpid(childPid_, &status, 0);
            childPid_ = 0;
        }
    }

    // Close stdout pipe after child has exited
    if (stdoutPipeFD_ >= 0)
    {
        close(stdoutPipeFD_);
        stdoutPipeFD_ = -1;
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

int ChildProcess::getStdinPipeFD() const
{
    return stdinPipeFD_;
}

int ChildProcess::getStdoutPipeFD() const
{
    return stdoutPipeFD_;
}

}  // namespace juce_cmp
