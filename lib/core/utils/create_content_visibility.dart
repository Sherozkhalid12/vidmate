import 'package:flutter/foundation.dart';

/// Notifier for CreateContentScreen visibility.
/// When true, screens like ReelsScreen should pause/dispose media playback.
final ValueNotifier<bool> createContentVisibleNotifier = ValueNotifier<bool>(false);
