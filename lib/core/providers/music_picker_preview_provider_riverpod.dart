import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/music_preview_player.dart';

class MusicPickerPreviewState {
  final String? loadedUrl;
  final bool isPlaying;
  final bool isLoading;
  final double progress;

  const MusicPickerPreviewState({
    this.loadedUrl,
    this.isPlaying = false,
    this.isLoading = false,
    this.progress = 0,
  });

  MusicPickerPreviewState copyWith({
    String? loadedUrl,
    bool? isPlaying,
    bool? isLoading,
    double? progress,
    bool clearLoadedUrl = false,
  }) {
    return MusicPickerPreviewState(
      loadedUrl: clearLoadedUrl ? null : (loadedUrl ?? this.loadedUrl),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
    );
  }

  bool matchesUrl(String url) => loadedUrl == url;
}

class MusicPickerPreviewNotifier extends StateNotifier<MusicPickerPreviewState> {
  MusicPickerPreviewNotifier() : super(const MusicPickerPreviewState()) {
    _player = MusicPreviewPlayer(
      onIsPlayingChanged: _onPlayingChanged,
      onProgressChanged: _onProgressChanged,
    );
    _player.warmUp();
  }

  late final MusicPreviewPlayer _player;
  int _toggleGeneration = 0;

  void markLoading(String url) {
    if (!mounted) return;
    state = state.copyWith(
      isLoading: true,
      loadedUrl: url,
      isPlaying: false,
      progress: 0,
    );
  }

  void _onPlayingChanged(bool playing) {
    if (!mounted) return;
    final url = _player.currentUrl;
    if (!playing && (url == null || url.isEmpty)) {
      state = const MusicPickerPreviewState();
      return;
    }
    state = state.copyWith(
      isPlaying: playing,
      isLoading: false,
      loadedUrl: url ?? state.loadedUrl,
    );
  }

  void _onProgressChanged(double progress) {
    if (!mounted) return;
    state = state.copyWith(
      progress: progress.clamp(0.0, 1.0),
      loadedUrl: _player.currentUrl ?? state.loadedUrl,
      isLoading: false,
    );
  }

  Future<void> toggle(String url) async {
    if (url.isEmpty) return;

    final op = ++_toggleGeneration;
    final sameLoaded = state.loadedUrl == url || _player.currentUrl == url;

    if (!sameLoaded) {
      state = state.copyWith(
        isLoading: true,
        loadedUrl: url,
        isPlaying: false,
        progress: 0,
      );
    }

    await _player.toggle(url);
    if (!mounted || op != _toggleGeneration) return;

    state = state.copyWith(
      isLoading: false,
      isPlaying: _player.isPlaying,
      loadedUrl: _player.currentUrl ?? url,
    );
  }

  Future<void> stop() async {
    _toggleGeneration++;
    await _player.stop();
    if (!mounted) return;
    state = const MusicPickerPreviewState();
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }
}

final musicPickerPreviewProvider = StateNotifierProvider.autoDispose<
    MusicPickerPreviewNotifier, MusicPickerPreviewState>((ref) {
  final notifier = MusicPickerPreviewNotifier();
  ref.onDispose(() {
    unawaited(notifier.stop());
  });
  return notifier;
});

/// Whether [trackKey] (url or track id) is the active preview row.
bool musicPreviewActiveKey(MusicPickerPreviewState s, String trackKey) =>
    s.loadedUrl == trackKey;
