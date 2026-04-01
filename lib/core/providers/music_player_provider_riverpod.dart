import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/music_model.dart';

class MusicPlayerArgs {
  final List<MusicModel> tracks;
  final int initialIndex;

  const MusicPlayerArgs({
    required this.tracks,
    required this.initialIndex,
  });
}

class MusicPlayerState {
  final List<MusicModel> tracks;
  final int currentIndex;
  final bool isPlaying;
  final bool isRepeat;
  final bool isShuffle;
  final Duration position;
  final Duration duration;
  final bool isLiked;
  final String? errorMessage;

  const MusicPlayerState({
    required this.tracks,
    required this.currentIndex,
    this.isPlaying = false,
    this.isRepeat = false,
    this.isShuffle = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isLiked = false,
    this.errorMessage,
  });

  MusicModel get currentTrack => tracks[currentIndex];

  MusicPlayerState copyWith({
    List<MusicModel>? tracks,
    int? currentIndex,
    bool? isPlaying,
    bool? isRepeat,
    bool? isShuffle,
    Duration? position,
    Duration? duration,
    bool? isLiked,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MusicPlayerState(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isRepeat: isRepeat ?? this.isRepeat,
      isShuffle: isShuffle ?? this.isShuffle,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isLiked: isLiked ?? this.isLiked,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MusicPlayerNotifier extends StateNotifier<MusicPlayerState> {
  MusicPlayerNotifier(MusicPlayerArgs args)
      : super(
          MusicPlayerState(
            tracks: args.tracks,
            currentIndex: args.tracks.isEmpty ? 0 : args.initialIndex.clamp(0, args.tracks.length - 1),
            isLiked: args.tracks.isEmpty ? false : args.tracks[args.initialIndex.clamp(0, args.tracks.length - 1)].isLiked,
          ),
        ) {
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((dur) {
      state = state.copyWith(duration: dur);
    });

    _stateSub = _audioPlayer.onPlayerStateChanged.listen((s) {
      state = state.copyWith(isPlaying: s == PlayerState.playing);
    });

    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      // If repeat, replay current track. Otherwise advance.
      if (state.tracks.isEmpty) return;
      if (state.isRepeat) {
        _safeReplayCurrent();
      } else {
        next();
      }
    });
  }

  late final AudioPlayer _audioPlayer;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  bool _isUnsupportedUrl(String url) {
    return url.contains('open.spotify.com');
  }

  bool get _hasTracks => state.tracks.isNotEmpty;

  Future<void> togglePlayPause() async {
    if (!_hasTracks) return;
    state = state.copyWith(clearError: true);

    if (state.isPlaying) {
      await _audioPlayer.pause();
      state = state.copyWith(isPlaying: false);
      return;
    }

    final track = state.currentTrack;
    if (track.audioUrl.isEmpty || _isUnsupportedUrl(track.audioUrl)) {
      state = state.copyWith(
        isPlaying: false,
        errorMessage: 'This audio URL is not playable yet (Spotify URLs are not supported).',
      );
      return;
    }

    try {
      await _audioPlayer.play(UrlSource(track.audioUrl));
      state = state.copyWith(isPlaying: true, position: Duration.zero);
    } catch (e) {
      state = state.copyWith(
        isPlaying: false,
        errorMessage: 'Failed to play audio',
      );
    }
  }

  Future<void> seek(Duration position) async {
    if (!_hasTracks) return;
    state = state.copyWith(position: position, clearError: true);
    try {
      await _audioPlayer.seek(position);
    } catch (_) {}
  }

  Future<void> selectTrack(int index) async {
    if (!_hasTracks) return;
    final nextIndex = index.clamp(0, state.tracks.length - 1);

    // Update UI immediately.
    final track = state.tracks[nextIndex];
    state = state.copyWith(
      currentIndex: nextIndex,
      position: Duration.zero,
      duration: track.duration,
      isLiked: track.isLiked,
      clearError: true,
    );

    // Preserve playing state.
    if (state.isPlaying) {
      final shouldPlay = track.audioUrl.isNotEmpty && !_isUnsupportedUrl(track.audioUrl);
      if (shouldPlay) {
        try {
          await _audioPlayer.play(UrlSource(track.audioUrl));
        } catch (_) {
          state = state.copyWith(isPlaying: false, errorMessage: 'Failed to play audio');
        }
      } else {
        state = state.copyWith(
          isPlaying: false,
          errorMessage: 'This audio URL is not playable yet (Spotify URLs are not supported).',
        );
      }
    }
  }

  void toggleRepeat() {
    state = state.copyWith(isRepeat: !state.isRepeat, clearError: true);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle, clearError: true);
  }

  void toggleLike() {
    state = state.copyWith(isLiked: !state.isLiked);
  }

  Future<void> next() async {
    if (!_hasTracks) return;
    if (state.tracks.length <= 1 && !state.isRepeat) return;

    final lastIndex = state.tracks.length - 1;
    int targetIndex;
    if (state.isShuffle && state.tracks.length > 1) {
      // Simple deterministic shuffle without importing extra deps.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      targetIndex = (nowMs % state.tracks.length);
      if (targetIndex == state.currentIndex) {
        targetIndex = (targetIndex + 1) % state.tracks.length;
      }
    } else {
      targetIndex = state.currentIndex < lastIndex ? state.currentIndex + 1 : 0;
      if (targetIndex == 0 && !state.isRepeat) {
        // End of list when not repeating.
        state = state.copyWith(isPlaying: false, position: Duration.zero);
        await _audioPlayer.stop();
        return;
      }
    }

    await selectTrack(targetIndex);
  }

  Future<void> previous() async {
    if (!_hasTracks) return;
    if (state.currentIndex <= 0) return;
    await selectTrack(state.currentIndex - 1);
  }

  Future<void> _safeReplayCurrent() async {
    if (!_hasTracks) return;
    final track = state.currentTrack;
    if (track.audioUrl.isEmpty || _isUnsupportedUrl(track.audioUrl)) {
      state = state.copyWith(
        isPlaying: false,
        errorMessage: 'This audio URL is not playable yet (Spotify URLs are not supported).',
      );
      return;
    }
    state = state.copyWith(position: Duration.zero, clearError: true);
    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play(UrlSource(track.audioUrl));
    } catch (_) {
      state = state.copyWith(isPlaying: false, errorMessage: 'Failed to replay audio');
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

final musicPlayerProvider =
    StateNotifierProvider.autoDispose.family<MusicPlayerNotifier, MusicPlayerState, MusicPlayerArgs>(
  (ref, args) => MusicPlayerNotifier(args),
);

