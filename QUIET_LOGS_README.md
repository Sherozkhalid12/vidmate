# Quiet Logging Configuration

This project is configured to suppress verbose Flutter logs and only show important errors and debug messages.

## How It Works

1. **Custom Logging Configuration** (`lib/main.dart`)
   - Suppresses verbose `print()` and `debugPrint()` statements
   - Only shows messages containing "ERROR", "WARNING", or "DEBUG"

2. **Custom Logger** (`lib/core/utils/logger.dart`)
   - Use `AppLogger.error()`, `AppLogger.warning()`, or `AppLogger.debug()` instead of `print()`
   - These will always show in console
   - `AppLogger.info()` and `AppLogger.verbose()` are suppressed

3. **Android Log Filtering**
   - The `run_quiet.ps1` script filters out verbose Android system logs
   - Filters: BLASTBufferQueue, acquireNextBuffer, SurfaceView, EGL, Choreographer

## Usage

### Option 1: Use the Quiet Run Script (Recommended)

**Windows PowerShell:**
```powershell
# If you get execution policy error, run this first (one time):
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then run:
.\run_quiet.ps1

# OR bypass execution policy for this script only:
powershell -ExecutionPolicy Bypass -File .\run_quiet.ps1
```

**Windows Batch File (No execution policy needed):**
```cmd
run_quiet.bat
```

**Linux/Mac:**
```bash
chmod +x run_quiet.sh
./run_quiet.sh
```

### Option 2: Run Flutter Normally
```bash
flutter run
```
The app-level logging configuration will still filter verbose logs.

### Option 3: Use VS Code Launch Configuration
- Select "Flutter (Quiet Mode)" from the debug dropdown
- This uses the configuration in `.vscode/launch.json`

### Option 4: Filter Logcat Directly (Android)
```bash
# Only show errors
adb logcat *:E

# Show errors and warnings
adb logcat *:E *:W

# Filter specific tags
adb logcat | grep -v "BLASTBufferQueue\|acquireNextBuffer\|SurfaceView"
```

## Using Custom Logger

Instead of `print()`, use the custom logger:

```dart
import 'core/utils/logger.dart';

// This will always show
AppLogger.error('Something went wrong', error, stackTrace);
AppLogger.warning('This is a warning');
AppLogger.debug('Debug information');

// These are suppressed
AppLogger.info('Info message');  // Won't show
AppLogger.verbose('Verbose message');  // Won't show
```

## What Gets Filtered

The following logs are suppressed:
- ✅ BLASTBufferQueue messages
- ✅ acquireNextBuffer warnings
- ✅ SurfaceView verbose logs
- ✅ EGL/libEGL debug messages
- ✅ Choreographer info logs
- ✅ Standard Flutter framework verbose logs
- ✅ Regular `print()` statements (unless they contain ERROR/WARNING/DEBUG)

## What Still Shows

- ✅ Errors and exceptions
- ✅ Warnings
- ✅ Messages from `AppLogger.error()`, `AppLogger.warning()`, `AppLogger.debug()`
- ✅ `print()` statements containing "ERROR", "WARNING", or "DEBUG"

## PowerShell Execution Policy Fix

If you get "running scripts is disabled" error:

**Option 1: Enable for current user (Recommended)**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Option 2: Bypass for single script**
```powershell
powershell -ExecutionPolicy Bypass -File .\run_quiet.ps1
```

**Option 3: Use batch file instead**
```cmd
run_quiet.bat
```
