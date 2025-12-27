import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Custom logger that only shows important messages
/// Use this instead of print() or debugPrint()
class AppLogger {
  static const String _tag = 'App';
  
  /// Log an error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      developer.log(
        message,
        name: _tag,
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Log a warning message
  static void warning(String message) {
    if (kDebugMode) {
      developer.log(
        message,
        name: _tag,
        level: 900,
      );
    }
  }
  
  /// Log a debug message (only in debug mode)
  static void debug(String message) {
    if (kDebugMode) {
      developer.log(
        message,
        name: _tag,
        level: 700,
      );
    }
  }
  
  /// Log an info message (suppressed by default)
  static void info(String message) {
    // Info messages are suppressed to reduce log noise
    // Uncomment below if you need info logs
    // if (kDebugMode) {
    //   developer.log(message, name: _tag, level: 800);
    // }
  }
  
  /// Log verbose message (suppressed by default)
  static void verbose(String message) {
    // Verbose messages are always suppressed
  }
}

