import 'package:flutter/foundation.dart';

/// Centralized logger with debouncing.
///
/// - In release: disabled by default.
/// - In debug/profile: enabled by default.
/// - Use [debounced] to avoid duplicate prints from retries/socket duplicates.
class AppLogger {
  AppLogger._();

  static bool enabled = !kReleaseMode;

  /// If set, only allow logs that include one of these tags.
  static Set<String> allowTags = {};

  static final Map<String, int> _lastByKeyMs = {};

  static void d(String tag, String message) {
    if (!enabled) return;
    if (allowTags.isNotEmpty && !allowTags.contains(tag)) return;
    debugPrint('[$tag] $message');
  }

  static void debounced(
    String key,
    String tag,
    String message, {
    int windowMs = 1200,
  }) {
    if (!enabled) return;
    if (allowTags.isNotEmpty && !allowTags.contains(tag)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastByKeyMs[key];
    if (last != null && (now - last) < windowMs) return;
    _lastByKeyMs[key] = now;
    debugPrint('[$tag] $message');
  }
}

