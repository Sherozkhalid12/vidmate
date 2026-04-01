import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/livestream_model.dart';
import '../../services/calls/livestream_service.dart';

enum LivestreamSessionStatus {
  idle,
  starting,
  live,
  ending,
  ended,
  error,
}

class LivestreamSessionState {
  final LivestreamSessionStatus status;
  final LivestreamAgoraAuth? auth;
  final String? errorMessage;

  const LivestreamSessionState({
    this.status = LivestreamSessionStatus.idle,
    this.auth,
    this.errorMessage,
  });

  LivestreamSessionState copyWith({
    LivestreamSessionStatus? status,
    LivestreamAgoraAuth? auth,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LivestreamSessionState(
      status: status ?? this.status,
      auth: auth ?? this.auth,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LivestreamSessionNotifier extends StateNotifier<LivestreamSessionState> {
  LivestreamSessionNotifier() : super(const LivestreamSessionState());

  final LivestreamService _service = LivestreamService();
  bool _startingGuard = false;

  Future<bool> start({
    required String channelName,
    int uid = 0,
    String? title,
    String? description,
    String? thumbnail,
  }) async {
    if (_startingGuard) return false;
    _startingGuard = true;
    state = state.copyWith(status: LivestreamSessionStatus.starting, clearError: true);
    try {
      final res = await _service.startLive(
        channelName: channelName,
        uid: uid,
        title: title,
        description: description,
        thumbnail: thumbnail,
      );
      if (!res.success || res.data == null) {
        state = state.copyWith(
          status: LivestreamSessionStatus.error,
          errorMessage: res.errorMessage ?? 'Failed to start livestream',
        );
        return false;
      }
      state = state.copyWith(
        status: LivestreamSessionStatus.live,
        auth: res.data,
      );
      return true;
    } finally {
      _startingGuard = false;
    }
  }

  Future<void> end() async {
    final auth = state.auth;
    final streamId = auth?.stream.streamId ?? '';
    if (streamId.isEmpty) return;
    state = state.copyWith(status: LivestreamSessionStatus.ending, clearError: true);
    final res = await _service.end(streamId);
    if (!res.success) {
      state = state.copyWith(
        status: LivestreamSessionStatus.live,
        errorMessage: res.errorMessage ?? 'Failed to end livestream',
      );
      return;
    }
    state = state.copyWith(status: LivestreamSessionStatus.ended);
  }

  void reset() {
    state = const LivestreamSessionState();
  }
}

final livestreamSessionProvider =
    StateNotifierProvider<LivestreamSessionNotifier, LivestreamSessionState>((ref) {
  return LivestreamSessionNotifier();
});

