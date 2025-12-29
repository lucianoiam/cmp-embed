#!/bin/bash
set -e
cd "$(dirname "$0")/.."

# Build first
./scripts/build.sh

# Run the standalone app
./build/standalone/standalone.app/Contents/MacOS/standalone
