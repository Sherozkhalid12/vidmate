import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../services/calls/agora_call_service.dart';

class AgoraCallState {
  final bool initialized;
  final bool joined;
  final bool micMuted;
  final bool speakerOn;
  final bool cameraOn;
  final int? localUid;
  final int? remoteUid;
  final bool remoteVideoAvailable;
  final String? error;

  const AgoraCallState({
    this.initialized = false,
    this.joined = false,
    this.micMuted = false,
    this.speakerOn = false,
    this.cameraOn = false,
    this.localUid,
    this.remoteUid,
    this.remoteVideoAvailable = false,
    this.error,
  });

  AgoraCallState copyWith({
    bool? initialized,
    bool? joined,
    bool? micMuted,
    bool? speakerOn,
    bool? cameraOn,
    int? localUid,
    int? remoteUid,
    bool? remoteVideoAvailable,
    String? error,
    bool clearError = false,
  }) {
    return AgoraCallState(
      initialized: initialized ?? this.initialized,
      joined: joined ?? this.joined,
      micMuted: micMuted ?? this.micMuted,
      speakerOn: speakerOn ?? this.speakerOn,
      cameraOn: cameraOn ?? this.cameraOn,
      localUid: localUid ?? this.localUid,
      remoteUid: remoteUid ?? this.remoteUid,
      remoteVideoAvailable: remoteVideoAvailable ?? this.remoteVideoAvailable,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AgoraCallNotifier extends StateNotifier<AgoraCallState> {
  AgoraCallNotifier() : super(const AgoraCallState());

  final AgoraCallService _service = AgoraCallService();
  RtcEngine? get engine => _service.engine;

  StreamSubscription<int?>? _remoteSub;
  StreamSubscription<bool>? _joinedSub;
  StreamSubscription<bool>? _remoteVideoSub;
  StreamSubscription<String?>? _errorSub;

  Future<void> init({required String appId, bool enableVideo = true}) async {
    if (state.initialized) return;
    await _service.init(appId: appId, enableVideo: enableVideo);
    _wireStreams();
    state = state.copyWith(initialized: true, clearError: true);
  }

  void _wireStreams() {
    _remoteSub?.cancel();
    _joinedSub?.cancel();
    _remoteVideoSub?.cancel();
    _errorSub?.cancel();

    _remoteSub = _service.remoteUidStream.listen((uid) {
      state = state.copyWith(remoteUid: uid);
    });
    _remoteVideoSub = _service.remoteVideoAvailableStream.listen((available) {
      state = state.copyWith(remoteVideoAvailable: available);
    });
    _joinedSub = _service.joinedStream.listen((joined) {
      state = state.copyWith(joined: joined, localUid: _service.localUid);
    });
    _errorSub = _service.errorStream.listen((msg) {
      if (msg == null || msg.isEmpty) return;
      state = state.copyWith(error: msg);
    });
  }

  Future<void> join({
    required String token,
    required String channelName,
    int uid = 0,
  }) async {
    await _service.join(token: token, channelName: channelName, uid: uid);
  }

  Future<void> setSpeakerOn(bool on) async {
    try {
      await _service.setSpeakerOn(on);
      state = state.copyWith(speakerOn: on);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setCameraOn(bool on) async {
    try {
      await _service.setCameraOn(on);
      state = state.copyWith(cameraOn: on);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> leave() async {
    await _service.leave();
    state = state.copyWith(joined: false, remoteUid: null);
  }

  Future<void> toggleMic() async {
    final next = !state.micMuted;
    try {
      await _service.setMicMuted(next);
      state = state.copyWith(micMuted: next);
    } catch (e) {
      // Safety net: engine methods should not crash UI.
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    try {
      await _service.setSpeakerOn(next);
      state = state.copyWith(speakerOn: next);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleCamera() async {
    final next = !state.cameraOn;
    try {
      await _service.setCameraOn(next);
      state = state.copyWith(cameraOn: next);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    _joinedSub?.cancel();
    _remoteVideoSub?.cancel();
    _errorSub?.cancel();
    // Dispose engine in background to keep UI snappy.
    Future.microtask(() => _service.dispose());
    super.dispose();
  }
}

final agoraCallProvider =
    StateNotifierProvider<AgoraCallNotifier, AgoraCallState>((ref) {
  return AgoraCallNotifier();
});

