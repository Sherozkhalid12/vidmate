# Riverpod Migration Guide

This app has been migrated to use **Riverpod** for state management, providing **super fast performance** and better developer experience.

## ✅ Completed Migrations

### Core Providers (All Created)
- ✅ `theme_provider_riverpod.dart` - Theme management
- ✅ `auth_provider_riverpod.dart` - Authentication state
- ✅ `posts_provider_riverpod.dart` - Posts/Feed state
- ✅ `reels_provider_riverpod.dart` - Reels state
- ✅ `main.dart` - Updated to use Riverpod

### Screens Updated
- ✅ `main.dart` - Uses `ConsumerWidget` and Riverpod providers
- ✅ `settings_screen.dart` - Uses Riverpod for theme toggle

## 🔄 How to Migrate Screens

### Step 1: Update Imports

**Before (Provider):**
```dart
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
```

**After (Riverpod):**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/theme_provider_riverpod.dart';
```

### Step 2: Convert Widget Types

**Before:**
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

**After:**
```dart
class MyScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  @override
  Widget build(BuildContext context) {
    // Use ref.watch() and ref.read() instead of Provider
  }
}
```

### Step 3: Replace Provider Access

**Before (Provider):**
```dart
// Reading
final themeProvider = Provider.of<ThemeProvider>(context);
final isDark = themeProvider.isDarkMode;

// Watching
Consumer<ThemeProvider>(
  builder: (context, themeProvider, child) {
    return Text(themeProvider.isDarkMode ? 'Dark' : 'Light');
  },
)
```

**After (Riverpod):**
```dart
// Reading (one-time)
final themeNotifier = ref.read(themeProvider.notifier);
final isDark = ref.read(isDarkModeProvider);

// Watching (reactive)
final isDark = ref.watch(isDarkModeProvider);
return Text(isDark ? 'Dark' : 'Light');
```

### Step 4: Update State Changes

**Before:**
```dart
themeProvider.toggleTheme();
```

**After:**
```dart
ref.read(themeProvider.notifier).toggleTheme();
```

## 📋 Available Providers

### Theme
```dart
// Watch theme state
final isDark = ref.watch(isDarkModeProvider);
final theme = ref.watch(currentThemeProvider);

// Toggle theme
ref.read(themeProvider.notifier).toggleTheme();
ref.read(themeProvider.notifier).setTheme(true);
```

### Authentication
```dart
// Watch auth state
final user = ref.watch(currentUserProvider);
final isAuth = ref.watch(isAuthenticatedProvider);
final isLoading = ref.watch(authLoadingProvider);
final error = ref.watch(authErrorProvider);

// Perform actions
ref.read(authProvider.notifier).login(email, password);
ref.read(authProvider.notifier).signUp(...);
ref.read(authProvider.notifier).logout();
```

### Posts/Feed
```dart
// Watch posts
final posts = ref.watch(postsListProvider);
final isLiked = ref.watch(postLikedProvider(postId));
final likeCount = ref.watch(postLikeCountProvider(postId));

// Actions
ref.read(postsProvider.notifier).toggleLike(postId);
ref.read(postsProvider.notifier).deletePost(postId);
ref.read(postsProvider.notifier).loadPosts();
```

### Reels
```dart
// Watch reels
final reels = ref.watch(reelsListProvider);
final currentIndex = ref.watch(currentReelIndexProvider);
final isLiked = ref.watch(reelLikedProvider(reelId));
final likeCount = ref.watch(reelLikeCountProvider(reelId));

// Actions
ref.read(reelsProvider.notifier).setCurrentIndex(index);
ref.read(reelsProvider.notifier).toggleLike(reelId);
ref.read(reelsProvider.notifier).loadReels();
```

## 🚀 Performance Benefits

1. **Automatic Rebuild Optimization**: Riverpod only rebuilds widgets that actually need updates
2. **No Context Required**: Access providers anywhere with `ref`
3. **Type Safety**: Compile-time checks prevent runtime errors
4. **Testability**: Easy to mock and test providers
5. **Code Generation**: Optional code generation for even better performance

## 📝 Remaining Screens to Migrate

- [ ] `home_screen.dart` - Use `postsProvider`
- [ ] `reels_screen.dart` - Use `reelsProvider`
- [ ] `profile_screen.dart` - Use auth/user providers
- [ ] `instagram_post_card.dart` - Use `postsProvider` for likes
- [ ] `login_screen.dart` - Use `authProvider`
- [ ] `signup_screen.dart` - Use `authProvider`
- [ ] Other screens with `setState` or `Provider`

## 🔧 Quick Migration Checklist

For each screen:
1. ✅ Change `StatefulWidget` → `ConsumerStatefulWidget`
2. ✅ Change `State` → `ConsumerState`
3. ✅ Replace `Provider.of` → `ref.watch` or `ref.read`
4. ✅ Replace `Consumer` → Direct `ref.watch` in build
5. ✅ Update imports
6. ✅ Test functionality

## 💡 Tips

- Use `ref.watch()` for reactive values that should trigger rebuilds
- Use `ref.read()` for one-time reads or actions (like button clicks)
- Use `ref.listen()` to react to state changes (like showing snackbars)
- Family providers are great for parameterized data (like `postLikedProvider(postId)`)

## 🎯 Next Steps

1. Migrate remaining screens one by one
2. Remove old Provider imports and files
3. Run `flutter pub get` after migration
4. Test all functionality
5. Enjoy super fast performance! 🚀

