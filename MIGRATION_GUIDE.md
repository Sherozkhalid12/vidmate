# Theme Migration Guide

## Overview
The app has been migrated to use a theme-aware color system. Instead of using direct color constants like `AppColors.neonPurple`, use theme extensions that automatically adapt to light/dark themes.

## Key Changes

### Before (Old Way - Don't Use)
```dart
// ❌ Direct color constants - not theme-aware
AppColors.neonPurple
AppColors.cyanGlow
AppColors.softBlue
AppColors.primaryBackground
context.backgroundColor  // Old extension
```

### After (New Way - Use This)
```dart
// ✅ Theme-aware colors - adapts to theme
context.buttonColor          // White in dark, black in light
context.accentColor          // Same as buttonColor
context.backgroundColor      // First gradient color
context.secondaryBackgroundColor  // Middle gradient color
context.surfaceColor         // Glass surface color
context.borderColor          // Glass border color
context.textPrimary          // Primary text color
context.textSecondary        // Secondary text color
context.textMuted            // Muted text color
```

## Migration Pattern

### Buttons & Interactive Elements
```dart
// Old
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.neonPurple,
  ),
)

// New
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: context.buttonColor,
    foregroundColor: context.buttonTextColor,
  ),
)
```

### Backgrounds
```dart
// Old
backgroundColor: AppColors.primaryBackground

// New
backgroundColor: Colors.transparent,  // Use gradient instead
// Then wrap body with:
Container(
  decoration: BoxDecoration(
    gradient: context.backgroundGradient,
  ),
  child: YourWidget(),
)
```

### Text Colors
```dart
// Old
Text('Hello', style: TextStyle(color: Colors.white))

// New
Text('Hello', style: TextStyle(color: context.textPrimary))
```

### Glass Surfaces
```dart
// Old
Container(
  color: Colors.white.withOpacity(0.1),
  border: Border.all(color: Colors.white.withOpacity(0.2)),
)

// New
Container(
  color: context.surfaceColor,
  border: Border.all(color: context.borderColor),
)
```

## Legacy Constants

The following constants are still available for backward compatibility but are deprecated:
- `AppColors.neonPurple` → Use `context.buttonColor`
- `AppColors.cyanGlow` → Use `context.buttonColor`
- `AppColors.softBlue` → Use `context.buttonColor`
- `AppColors.primaryBackground` → Use `context.backgroundColor`
- `AppColors.lightBackground` → Use `context.backgroundColor`

These will be removed in a future version. Please migrate to theme extensions.

