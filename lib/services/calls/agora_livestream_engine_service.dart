import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

enum LivestreamRtcRole {
  publisher,
  subscriber,
}

enum LivestreamRtcConnection {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class LivestreamRtcSnapshot {
  final LivestreamRtcConnection connection;
  final bool joined;
  final int? localUid;
  final Set<int> remoteUids;
  final bool micMuted;
  final bool cameraOn;
  final bool speakerOn;
  final String? lastError;

  const LivestreamRtcSnapshot({
    required this.connection,
    required this.joined,
    required this.localUid,
    required this.remoteUids,
    required this.micMuted,
    required this.cameraOn,
    required this.speakerOn,
    required this.lastError,
  });

  factory LivestreamRtcSnapshot.initial() => const LivestreamRtcSnapshot(
        connection: LivestreamRtcConnection.disconnected,
        joined: false,
        localUid: null,
        remoteUids: {},
        micMuted: false,
        cameraOn: true,
        speakerOn: true,
        lastError: null,
      );
}

/// Low-level Agora engine wrapper for livestream.
///
/// Goals:
/// - single engine instance per session
/// - stream of snapshots for Riverpod state
/// - handles token expiry callbacks
/// - handles connection state transitions (lost / reconnecting)
class AgoraLivestreamEngineService {
  RtcEngine? _engine;
  bool _initialized = false;
  bool _joined = false;
  int? _localUid;
  final Set<int> _remoteUids = <int>{};
  LivestreamRtcRole _role = LivestreamRtcRole.subscriber;

  bool _micMuted = false;
  bool _cameraOn = true;
  bool _speakerOn = true;

  LivestreamRtcConnection _connection = LivestreamRtcConnection.disconnected;
  String? _lastError;

  final StreamController<LivestreamRtcSnapshot> _snapshotController =
      StreamController<LivestreamRtcSnapshot>.broadcast();

  final StreamController<void> _tokenWillExpireController =
      StreamController<void>.broadcast();

  Stream<LivestreamRtcSnapshot> get snapshots => _snapshotController.stream;
  Stream<void> get onTokenPrivilegeWillExpire =>
      _tokenWillExpireController.stream;

  LivestreamRtcSnapshot get current => LivestreamRtcSnapshot(
        connection: _connection,
        joined: _joined,
        localUid: _localUid,
        remoteUids: Set<int>.from(_remoteUids),
        micMuted: _micMuted,
        cameraOn: _cameraOn,
        speakerOn: _speakerOn,
        lastError: _lastError,
      );

  void _emit() {
    if (_snapshotController.isClosed) return;
    _snapshotController.add(current);
  }

  Future<void> init({
    required String appId,
    required LivestreamRtcRole role,
  }) async {
    if (_initialized) return;
    _role = role;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onError: (err, msg) {
          _lastError = msg;
          _connection = LivestreamRtcConnection.failed;
          if (kDebugMode) debugPrint('[LiveRTC] onError $err $msg');
          _emit();
        },
        onJoinChannelSuccess: (conn, elapsed) {
          _joined = true;
          _localUid = conn.localUid;
          _connection = LivestreamRtcConnection.connected;
          if (kDebugMode) {
            debugPrint(
                '[LiveRTC] joined channel=${conn.channelId} uid=${conn.localUid}');
          }
          _emit();
        },
        onUserJoined: (conn, uid, elapsed) {
          _remoteUids.add(uid);
          _emit();
        },
        onUserOffline: (conn, uid, reason) {
          _remoteUids.remove(uid);
          _emit();
        },
        onTokenPrivilegeWillExpire: (conn, token) {
          if (kDebugMode) debugPrint('[LiveRTC] token will expire');
          if (!_tokenWillExpireController.isClosed) {
            _tokenWillExpireController.add(null);
          }
        },
        onConnectionStateChanged: (conn, state, reason) {
          switch (state) {
            case ConnectionStateType.connectionStateConnecting:
              _connection = LivestreamRtcConnection.connecting;
              break;
            case ConnectionStateType.connectionStateConnected:
              _connection = LivestreamRtcConnection.connected;
              break;
            case ConnectionStateType.connectionStateReconnecting:
              _connection = LivestreamRtcConnection.reconnecting;
              break;
            case ConnectionStateType.connectionStateDisconnected:
              _connection = LivestreamRtcConnection.disconnected;
              break;
            case ConnectionStateType.connectionStateFailed:
              _connection = LivestreamRtcConnection.failed;
              break;
          }
          _emit();
        },
      ),
    );

    // Always enable video; subscriber will just render remote.
    await _engine!.enableAudio();
    await _engine!.enableVideo();
    if (role == LivestreamRtcRole.publisher) {
      await _engine!.startPreview();
    }

    _initialized = true;
    _emit();
  }

  Future<void> join({
    required String token,
    required String channelName,
    required int uid,
  }) async {
    if (!_initialized || _engine == null) return;
    if (_joined) return;
    _connection = LivestreamRtcConnection.connecting;
    _emit();

    final options = ChannelMediaOptions(
      clientRoleType: _role == LivestreamRtcRole.publisher
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
      autoSubscribeAudio: true,
      autoSubscribeVideo: true,
    );
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: options,
    );
    // Ensure speaker is set after join to avoid ERR_NOT_READY (-3).
    try {
      await _engine!.setEnableSpeakerphone(_speakerOn);
    } catch (_) {}
  }

  Future<void> renewToken(String token) async {
    if (_engine == null) return;
    try {
      await _engine!.renewToken(token);
      if (kDebugMode) debugPrint('[LiveRTC] token renewed');
    } catch (e) {
      _lastError = e.toString();
      _emit();
    }
  }

  Future<void> setMicMuted(bool muted) async {
    _micMuted = muted;
    _emit();
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(muted);
  }

  Future<void> setCameraOn(bool on) async {
    _cameraOn = on;
    _emit();
    if (_engine == null) return;
    if (on) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.stopPreview();
      await _engine!.disableVideo();
    }
  }

  Future<void> setSpeakerOn(bool on) async {
    _speakerOn = on;
    _emit();
    if (_engine == null) return;
    try {
      await _engine!.setEnableSpeakerphone(on);
    } catch (e) {
      if (kDebugMode) debugPrint('[LiveRTC] setEnableSpeakerphone failed: $e');
    }
  }

  RtcEngine? get engine => _engine;

  Future<void> leave() async {
    if (_engine == null) return;
    try {
      if (_joined) await _engine!.leaveChannel();
    } catch (_) {}
    _joined = false;
    _localUid = null;
    _remoteUids.clear();
    _connection = LivestreamRtcConnection.disconnected;
    _emit();
  }

  Future<void> dispose() async {
    await leave();
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    _initialized = false;
    _lastError = null;
    _connection = LivestreamRtcConnection.disconnected;
    if (!_snapshotController.isClosed) await _snapshotController.close();
    if (!_tokenWillExpireController.isClosed) {
      await _tokenWillExpireController.close();
    }
  }
}

