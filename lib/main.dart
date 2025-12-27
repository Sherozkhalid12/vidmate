import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider_riverpod.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure logging to suppress verbose logs
  _configureLogging();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Configure logging to only show important errors and debug prints
void _configureLogging() {
  // Suppress verbose print statements
  // Note: This affects debugPrint, but direct print() calls may still appear
  // Use AppLogger from core/utils/logger.dart for better control
  if (kReleaseMode) {
    // In release mode, suppress all debug prints
    debugPrint = (String? message, {int? wrapWidth}) {
      // Suppress all prints in release mode
    };
  }
  // In debug mode, debugPrint will work normally
  // To filter prints, use AppLogger instead of print()
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme state for super fast updates
    final isDarkMode = ref.watch(isDarkModeProvider);
    final currentTheme = ref.watch(currentThemeProvider);

    // Update system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode 
            ? Brightness.light 
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDarkMode 
            ? Brightness.light 
            : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'VidConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
