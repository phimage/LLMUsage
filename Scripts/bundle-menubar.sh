#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Building llmusage-menubar..."
swift build -c release --product llmusage-menubar

APP_DIR=".build/LLMUsage.app/Contents"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

cp .build/release/llmusage-menubar "$APP_DIR/MacOS/llmusage-menubar"
cp Sources/llmusage-menubar/Resources/Info.plist "$APP_DIR/Info.plist"

echo "Built LLMUsage.app at .build/LLMUsage.app"
echo "Run with: open .build/LLMUsage.app"
