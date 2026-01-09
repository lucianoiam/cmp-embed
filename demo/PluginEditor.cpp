// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

/**
 * PluginEditor - JUCE editor that hosts the Compose UI via IOSurfaceComponent.
 *
 * The editor displays a loading message until the IOSurfaceComponent's native
 * view covers it with the child process rendering.
 */
#include "PluginEditor.h"

PluginEditor::PluginEditor(PluginProcessor& p)
    : AudioProcessorEditor(&p), processorRef(p)
{
    setSize(768, 480);
    setResizable(true, true);  // Keep native corner for AU plugin compatibility
    setResizeLimits(400, 300, 2048, 2048);
    
    // Load the preview image from embedded data
    loadingPreviewImage = juce::ImageFileFormat::loadFrom(loading_preview_png, loading_preview_png_len);
    
    // Wire up UI→Host custom events (interpret ValueTree as parameter changes)
    surfaceComponent.onCustomEvent([&p](const juce::ValueTree& tree) {
        if (tree.getType() == juce::Identifier("param"))
        {
            auto paramId = static_cast<int>(tree.getProperty("id", -1));
            auto value = static_cast<float>(static_cast<double>(tree.getProperty("value", 0.0)));
            
            switch (paramId) {
                case 0:
                    if (p.shapeParameter != nullptr)
                        p.shapeParameter->setValueNotifyingHost(value);
                    break;
                // Add more parameters here as needed
            }
        }
    });
    
    // Wire up Host→UI parameter changes (automation from Live, etc.)
    p.setParameterChangedCallback([this](int paramIndex, float value) {
        // Forward to Compose UI as ValueTree custom event
        juce::ValueTree tree("param");
        tree.setProperty("id", paramIndex, nullptr);
        tree.setProperty("value", static_cast<double>(value), nullptr);
        surfaceComponent.sendCustomEvent(tree);
    });
    
    // Send initial parameter values when child process is ready
    surfaceComponent.onReady([this, &p]() {
        if (p.shapeParameter != nullptr) {
            juce::ValueTree tree("param");
            tree.setProperty("id", 0, nullptr);
            tree.setProperty("value", static_cast<double>(p.shapeParameter->get()), nullptr);
            surfaceComponent.sendCustomEvent(tree);
        }
        // Add more parameters here as needed
    });

    addAndMakeVisible(surfaceComponent);

    // Hide the native resize corner visually while keeping it functional for AU compatibility
    // The corner component is added by setResizable() - find it and make it transparent
    for (int i = 0; i < getNumChildComponents(); ++i)
    {
        if (auto* corner = dynamic_cast<juce::ResizableCornerComponent*>(getChildComponent(i)))
        {
            corner->setAlpha(0.0f);
            break;
        }
    }
}

PluginEditor::~PluginEditor()
{
    // Clear the callback to avoid dangling reference
    processorRef.setParameterChangedCallback(nullptr);
}

void PluginEditor::paint(juce::Graphics& g)
{
    // Background color for loading screen
    // NOTE: This should match the Compose UI background color in UserInterface.kt (Color(0xFF6F97FF))
    g.fillAll(juce::Colour(0xFF6F97FF));
    
    // Draw the loading preview image scaled to fit
    if (loadingPreviewImage.isValid())
    {
        // Scale image to fit while maintaining aspect ratio
        float imageAspect = (float)loadingPreviewImage.getWidth() / loadingPreviewImage.getHeight();
        float boundsAspect = (float)getWidth() / getHeight();
        
        int drawWidth, drawHeight, drawX, drawY;
        if (imageAspect > boundsAspect)
        {
            // Image is wider - fit to width
            drawWidth = getWidth();
            drawHeight = (int)(getWidth() / imageAspect);
            drawX = 0;
            drawY = (getHeight() - drawHeight) / 2;
        }
        else
        {
            // Image is taller - fit to height
            drawHeight = getHeight();
            drawWidth = (int)(getHeight() * imageAspect);
            drawX = (getWidth() - drawWidth) / 2;
            drawY = 0;
        }
        
        g.drawImage(loadingPreviewImage, drawX, drawY, drawWidth, drawHeight,
                    0, 0, loadingPreviewImage.getWidth(), loadingPreviewImage.getHeight());
    }
    
    // Draw loading text centered on top of the image
    g.setColour(juce::Colours::black);
    g.setFont(juce::FontOptions(15.0f));
    g.drawFittedText("Starting UI...", getLocalBounds(), juce::Justification::centred, 1);
}

void PluginEditor::resized()
{
    surfaceComponent.setBounds(getLocalBounds());
}
