# PowerShell script to run Flutter with minimal logging
# Usage: powershell -ExecutionPolicy Bypass -File .\run_quiet.ps1
# Or: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser (one time)

Write-Host "Starting Flutter app with quiet logging..." -ForegroundColor Green

# Filter out verbose Android logs
$env:ANDROID_LOG_TAGS = "*:E"  # Only show errors

# Run Flutter and filter output
flutter run 2>&1 | Where-Object {
    # Filter out verbose logs
    $_ -notmatch "BLASTBufferQueue" -and
    $_ -notmatch "acquireNextBuffer" -and
    $_ -notmatch "SurfaceView" -and
    $_ -notmatch "I/flutter" -and
    $_ -notmatch "D/EGL" -and
    $_ -notmatch "D/libEGL" -and
    $_ -notmatch "I/Choreographer" -and
    $_ -notmatch "D/OpenGLRenderer" -and
    $_ -notmatch "I/Adreno" -and
    ($_ -match "ERROR|WARNING|Exception|FATAL|flutter:" -or $_ -match "DEBUG:" -or $_ -match "Running Gradle")
  }

