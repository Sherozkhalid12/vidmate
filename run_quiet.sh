#!/bin/bash
# Bash script to run Flutter with minimal logging
# Usage: ./run_quiet.sh

echo "Starting Flutter app with quiet logging..."

# Filter out verbose Android logs
export ANDROID_LOG_TAGS="*:E"  # Only show errors

# Run Flutter and filter output
flutter run \
  2>&1 | grep -E "(ERROR|WARNING|Exception|FATAL|flutter:|DEBUG:|Running Gradle)" \
  | grep -v "BLASTBufferQueue" \
  | grep -v "acquireNextBuffer" \
  | grep -v "SurfaceView" \
  | grep -v "I/flutter" \
  | grep -v "D/EGL" \
  | grep -v "D/libEGL" \
  | grep -v "I/Choreographer"

