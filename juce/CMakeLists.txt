cmake_minimum_required(VERSION 3.22)
project(cmp-embed-juce VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fetch JUCE from GitHub
include(FetchContent)
FetchContent_Declare(
    JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG        8.0.4
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(JUCE)

# Define plugin/standalone target
juce_add_plugin(CMPEmbedHost
    COMPANY_NAME "CMPEmbed"
    BUNDLE_ID "com.cmpembed.host"
    PLUGIN_MANUFACTURER_CODE CMPe
    PLUGIN_CODE CMPh
    FORMATS Standalone AU
    PRODUCT_NAME "CMP Embed"
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_SYNTH TRUE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
)

target_sources(CMPEmbedHost
    PRIVATE
        PluginProcessor.cpp
        PluginProcessor.h
        PluginEditor.cpp
        PluginEditor.h
        bridge/IOSurfaceComponent.mm
        bridge/IOSurfaceComponent.h
        bridge/IOSurfaceProvider.mm
        bridge/IOSurfaceProvider.h
        bridge/InputSender.cpp
        bridge/InputSender.h
        bridge/UIReceiver.h
)

target_include_directories(CMPEmbedHost
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/../common
)

target_compile_definitions(CMPEmbedHost
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
)

target_link_libraries(CMPEmbedHost
    PRIVATE
        juce::juce_audio_utils
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)

# Platform-specific frameworks
if(APPLE)
    target_link_libraries(CMPEmbedHost PRIVATE 
        "-framework IOSurface"
        "-framework CoreVideo"
    )
    
    # Paths to Compose Desktop build outputs
    set(CMP_UI_APP "${CMAKE_SOURCE_DIR}/ui/composeApp/build/compose/binaries/main/app/cmpui.app")
    set(CMP_UI_CONTENTS "${CMP_UI_APP}/Contents")
    set(NATIVE_RENDERER "${CMAKE_SOURCE_DIR}/ui/composeApp/src/jvmMain/resources/libiosurface_renderer.dylib")
    
    # Standalone - merge Compose runtime into bundle
    add_custom_command(TARGET CMPEmbedHost_Standalone POST_BUILD
        # Copy Compose launcher to MacOS/
        COMMAND ${CMAKE_COMMAND} -E copy
            "${CMP_UI_CONTENTS}/MacOS/cmpui"
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_Standalone>/Contents/MacOS/cmpui"
        # Copy JARs + Skiko dylib to app/
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMP_UI_CONTENTS}/app"
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_Standalone>/Contents/app"
        # Copy jlink'd JVM to runtime/
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMP_UI_CONTENTS}/runtime"
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_Standalone>/Contents/runtime"
        # Copy native renderer to Frameworks/
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_Standalone>/Contents/Frameworks"
        COMMAND ${CMAKE_COMMAND} -E copy
            "${NATIVE_RENDERER}"
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_Standalone>/Contents/Frameworks/libiosurface_renderer.dylib"
        COMMENT "Merging Compose runtime into Standalone bundle"
    )
    
    # AU - merge Compose runtime into bundle
    add_custom_command(TARGET CMPEmbedHost_AU POST_BUILD
        # Copy Compose launcher to MacOS/
        COMMAND ${CMAKE_COMMAND} -E copy
            "${CMP_UI_CONTENTS}/MacOS/cmpui"
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_AU>/Contents/MacOS/cmpui"
        # Copy JARs + Skiko dylib to app/
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMP_UI_CONTENTS}/app"
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_AU>/Contents/app"
        # Copy jlink'd JVM to runtime/
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMP_UI_CONTENTS}/runtime"
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_AU>/Contents/runtime"
        # Copy native renderer to Frameworks/
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_AU>/Contents/Frameworks"
        COMMAND ${CMAKE_COMMAND} -E copy
            "${NATIVE_RENDERER}"
            "$<TARGET_BUNDLE_DIR:CMPEmbedHost_AU>/Contents/Frameworks/libiosurface_renderer.dylib"
        COMMENT "Merging Compose runtime into AU bundle"
    )
endif()
