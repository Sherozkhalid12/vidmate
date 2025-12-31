# Remaining Files to Refactor - Theme-Aware Colors

## Overview
This document lists all files that still contain hardcoded accent colors (`AppColors.neonPurple`, `cyanGlow`, `softBlue`, `purpleGradient`, `cyanGradient`, etc.) and need to be refactored to use theme-aware colors.

## Medium Priority Screens

### Feed Screens
1. **`lib/features/feed/post_detail_screen.dart`**
   - Replacements needed: `AppColors.cyanGlow` (3 instances), `AppColors.neonPurple` (1 instance)
   - Used in: Share icon, SnackBar backgrounds

2. **`lib/features/feed/comments_screen.dart`**
   - Replacements needed: `AppColors.neonPurple` (1 instance), `AppColors.cyanGlow` (1 instance)
   - Used in: Comment input, SnackBar backgrounds

3. **`lib/features/feed/create_post_screen.dart`**
   - Replacements needed: `AppColors.softBlue` (1 instance)
   - Used in: Background color

### Upload Screens
4. **`lib/features/upload/video_upload_screen.dart`**
   - Replacements needed: `AppColors.neonPurple` (2 instances), `AppColors.softBlue` (2 instances), `AppColors.cyanGlow` (2 instances)
   - Used in: AppBar icons, background colors, SnackBar backgrounds, loading indicators

5. **`lib/features/upload/story_upload_screen.dart`**
   - Replacements needed: `AppColors.neonPurple` (2 instances), `AppColors.softBlue` (2 instances), `AppColors.cyanGlow` (1 instance)
   - Used in: AppBar icons, background colors, action icons

### Onboarding & Splash
6. **`lib/features/onboarding/onboarding_screen.dart`**
   - Replacements needed: `AppColors.purpleGradient` (1 instance), `AppColors.cyanGradient` (1 instance), `AppColors.neonPurple` (2 instances), `AppColors.softBlue` (1 instance)
   - Used in: Background gradients, page indicator, skip button

7. **`lib/features/splash/splash_screen.dart`**
   - Replacements needed: `AppColors.neonPurple` (1 instance), `AppColors.cyanGlow` (1 instance), `AppColors.softBlue` (1 instance)
   - Used in: Loading indicator gradient colors

### Video & Stories
8. **`lib/features/stories/stories_viewer_screen.dart`**
   - Replacements needed: `AppColors.cyanGlow` (2 instances), `AppColors.purpleGradient` (1 instance)
   - Used in: Action button backgrounds, SnackBar backgrounds

### Other Screens
9. **`lib/features/copyright/copyright_screen.dart`**
   - Replacements needed: `AppColors.neonPurple` (2 instances), `AppColors.cyanGlow` (6 instances)
   - Used in: Icons, buttons, SnackBar backgrounds, status indicators

10. **`lib/features/analytics/analytics_screen.dart`**
    - Replacements needed: `AppColors.neonPurple` (1 instance), `AppColors.cyanGlow` (1 instance), `AppColors.softBlue` (1 instance)
    - Used in: Chart gradient colors, icon colors

## Replacement Patterns

For all files above, use these replacements:

```dart
// BEFORE
AppColors.cyanGlow
AppColors.neonPurple
AppColors.softBlue
AppColors.purpleGradient
AppColors.cyanGradient

// AFTER
ThemeHelper.getAccentColor(context)  // For solid colors
ThemeHelper.getAccentGradient(context)  // For gradients
```

## Quick Reference

**Add import:**
```dart
import '../../core/utils/theme_helper.dart';  // Adjust path as needed
```

**Common replacements:**
- `AppColors.cyanGlow` → `ThemeHelper.getAccentColor(context)`
- `AppColors.neonPurple` → `ThemeHelper.getAccentColor(context)`
- `AppColors.softBlue` → `ThemeHelper.getAccentColor(context)`
- `AppColors.purpleGradient` → `ThemeHelper.getAccentGradient(context)`
- `AppColors.cyanGradient` → `ThemeHelper.getAccentGradient(context)`

## Total Remaining Files: 10

All files follow the same pattern as the high-priority screens that were already refactored. Use `ThemeHelper.getAccentColor(context)` and `ThemeHelper.getAccentGradient(context)` consistently.



