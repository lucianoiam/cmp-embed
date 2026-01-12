// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

#include "ComposeProvider.h"

namespace juce_cmp
{

ComposeProvider::ComposeProvider() = default;

ComposeProvider::~ComposeProvider()
{
    stop();
}

bool ComposeProvider::launch(const std::string& executable, int width, int height, float scale)
{
    scale_ = scale;

    // Create surface at pixel dimensions
    int pixelW = (int)(width * scale);
    int pixelH = (int)(height * scale);

    if (!surface_.create(pixelW, pixelH))
        return false;

    // Launch child process
    if (!child_.launch(executable, surface_.getID(), scale))
    {
        surface_.release();
        return false;
    }

    // Set up IPC
    ipc_.setWriteFD(child_.getStdinPipeFD());
    ipc_.setReadFD(child_.getStdoutPipeFD());

    ipc_.setEventHandler([this](const juce::ValueTree& tree) {
        if (eventCallback_)
            eventCallback_(tree);
    });

    ipc_.setFirstFrameHandler([this]() {
        if (firstFrameCallback_)
            firstFrameCallback_();
    });

    ipc_.startReceiving();

    // Set up view
    view_.create();
    view_.setSurface(surface_.getNativeHandle());
    view_.setBackingScale(scale);

    return true;
}

void ComposeProvider::stop()
{
    child_.stop();
    ipc_.stop();
    view_.destroy();
    surface_.release();
}

bool ComposeProvider::isRunning() const
{
    return child_.isRunning();
}

void ComposeProvider::attachView(void* parentNativeHandle)
{
    if (parentNativeHandle)
        view_.attachToParent(parentNativeHandle);
}

void ComposeProvider::detachView()
{
    view_.detachFromParent();
}

void ComposeProvider::updateViewBounds(int x, int y, int width, int height)
{
    view_.setFrame(x, y, width, height);
}

void ComposeProvider::resize(int width, int height)
{
    if (width <= 0 || height <= 0)
        return;

    int pixelW = (int)(width * scale_);
    int pixelH = (int)(height * scale_);

    uint32_t newSurfaceID = surface_.resize(pixelW, pixelH);
    if (newSurfaceID != 0)
    {
        auto e = InputEventFactory::resize(pixelW, pixelH, scale_, newSurfaceID);
        ipc_.sendInput(e);
        view_.setPendingSurface(surface_.getNativeHandle());
    }
}

void ComposeProvider::sendInput(InputEvent& event)
{
    ipc_.sendInput(event);
}

void ComposeProvider::sendEvent(const juce::ValueTree& tree)
{
    ipc_.sendEvent(tree);
}

}  // namespace juce_cmp
