import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-tile UI state for long-video feed tiles. Inline playback is owned by
/// [globalVideoEngineProvider]; this notifier only tracks embedded-route overlap.
class LongVideoWidgetState {
  final bool isEmbeddedOpen;

  const LongVideoWidgetState({
    this.isEmbeddedOpen = false,
  });

  LongVideoWidgetState copyWith({bool? isEmbeddedOpen}) {
    return LongVideoWidgetState(
      isEmbeddedOpen: isEmbeddedOpen ?? this.isEmbeddedOpen,
    );
  }
}

class VideoWidgetKey {
  final String widgetId;
  final String videoUrl;

  const VideoWidgetKey(this.widgetId, this.videoUrl);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoWidgetKey &&
          runtimeType == other.runtimeType &&
          widgetId == other.widgetId &&
          videoUrl == other.videoUrl;

  @override
  int get hashCode => widgetId.hashCode ^ videoUrl.hashCode;
}

final longVideoWidgetProvider = StateNotifierProvider.autoDispose
    .family<LongVideoWidgetNotifier, LongVideoWidgetState, VideoWidgetKey>(
  (ref, key) {
    return LongVideoWidgetNotifier();
  },
);

class LongVideoWidgetNotifier extends StateNotifier<LongVideoWidgetState> {
  LongVideoWidgetNotifier() : super(const LongVideoWidgetState());

  void setEmbeddedOpen(bool value) {
    state = state.copyWith(isEmbeddedOpen: value);
  }

  bool get isEmbeddedOpen => state.isEmbeddedOpen;
}
