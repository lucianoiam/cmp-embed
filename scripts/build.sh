#!/bin/bash
# Build script for juce-cmp
# CMake orchestrates: Native renderer → UI (Compose) → Standalone → JUCE Host
set -e
cd "$(dirname "$0")/.."

echo "=== Building juce-cmp ==="

# Configure
cmake -B build

# Build all targets
echo "=== Building native renderer ==="
cmake --build build --target native_renderer

echo "=== Building Compose UI ==="
cmake --build build --target ui

echo "=== Building Standalone app ==="
cmake --build build --target standalone

echo "=== Building JUCE host ==="
cmake --build build --target juce-cmp_Standalone

echo "=== Building AU plugin ==="
cmake --build build --target juce-cmp_AU

echo "=== Build complete ==="
