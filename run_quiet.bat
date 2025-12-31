@echo off
REM Batch file to run Flutter with minimal logging
REM Usage: run_quiet.bat

echo Starting Flutter app with quiet logging...

REM Set Android log filter to only show errors
set ANDROID_LOG_TAGS=*:E

REM Run Flutter (batch files don't filter well, so we'll rely on app-level filtering)
flutter run






