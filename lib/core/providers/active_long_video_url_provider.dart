import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the long-video URL currently owned by embedded [VideoPlayerProvider].
final activeLongVideoUrlProvider = StateProvider<String?>((ref) => null);
