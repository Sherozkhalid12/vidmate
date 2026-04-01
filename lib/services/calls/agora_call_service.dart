import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/app_logger.dart';

/// Lightweight wrapper around Agora RTC engine for 1:1 calls.
///
/// - Initializes engine once per call session.
/// - Exposes streams for call UI (remote join/leave, audio/video state).
/// - Keeps memory low by not holding big objects in state.
class AgoraCallService {
  RtcEngine? _engine;
  bool _initialized = false;
  bool _joined = false;

  bool _micMuted = false;
  bool _speakerOn = false; // voice call default: earpiece
  bool _cameraOn = false; // voice call default: camera off

  int? _localUid;
  int? _remoteUid;
  bool _remoteVideoAvailable = false;

  final StreamController<int?> _remoteUidController =
      StreamController<int?>.broadcast();
  final StreamController<bool> _remoteVideoController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _joinedController =
      StreamController<bool>.broadcast();
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();

  Stream<int?> get remoteUidStream => _remoteUidController.stream;
  Stream<bool> get remoteVideoAvailableStream => _remoteVideoController.stream;
  Stream<bool> get joinedStream => _joinedController.stream;
  Stream<String?> get errorStream => _errorController.stream;

  bool get joined => _joined;
  bool get micMuted => _micMuted;
  bool get speakerOn => _speakerOn;
  bool get cameraOn => _cameraOn;
  int? get localUid => _localUid;
  int? get remoteUid => _remoteUid;
  bool get remoteVideoAvailable => _remoteVideoAvailable;
  RtcEngine? get engine => _engine;

  bool _isErrNotReady(Object e) {
    // Agora frequently surfaces ERR_NOT_READY as code -3, often with null message.
    // Exception string examples vary by platform/plugin version, so we match loosely.
    final s = e.toString();
    return s.contains(' -3') ||
        s.contains('(-3') ||
        s.contains('ERR_NOT_READY') ||
        s.contains('errNotReady') ||
        s.contains('err_not_ready');
  }

  bool _isNullOrEmptyAgoraMsg(String? msg) => msg == null || msg.trim().isEmpty;

  Future<void> init({
    required String appId,
    bool enableVideo = true,
  }) async {
    if (_initialized) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onError: (err, msg) {
          if (kDebugMode) AppLogger.d('AgoraCall', 'onError: $err $msg');
          // Filter noisy "not ready" / null messages which are common during startup.
          if (_isNullOrEmptyAgoraMsg(msg)) return;
          _errorController.add(msg);
        },
        onJoinChannelSuccess: (connection, elapsed) {
          _joined = true;
          _localUid = connection.localUid;
          _joinedController.add(true);
          if (kDebugMode) {
            AppLogger.debounced(
              'agora:join:${connection.channelId}:${connection.localUid}',
              'AgoraCall',
              'joined channel=${connection.channelId} uid=${connection.localUid}',
              windowMs: 1500,
            );
          }

          // Apply deferred speaker route once the engine is ready.
          // Some devices throw ERR_NOT_READY (-3) if we do this too early (during init).
          Future.microtask(() async {
            try {
              await _engine?.setEnableSpeakerphone(_speakerOn);
            } catch (e) {
              if (_isErrNotReady(e)) return;
              _errorController.add(e.toString());
            }
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _remoteUid = remoteUid;
          _remoteUidController.add(remoteUid);
          // Reset remote video state until we actually receive frames.
          _remoteVideoAvailable = false;
          _remoteVideoController.add(false);
          if (kDebugMode) {
            AppLogger.debounced(
              'agora:remote_join:$remoteUid:${connection.channelId}',
              'AgoraCall',
              'remote joined uid=$remoteUid channel=${connection.channelId}',
              windowMs: 1500,
            );
          }
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          final isAvailable = state == RemoteVideoState.remoteVideoStateDecoding;
          if (_remoteUid == remoteUid && _remoteVideoAvailable != isAvailable) {
            _remoteVideoAvailable = isAvailable;
            _remoteVideoController.add(isAvailable);
          }
          if (kDebugMode) {
            AppLogger.debounced(
              'agora:remote_video:$remoteUid:${connection.channelId}:$state',
              'AgoraCall',
              'remote video uid=$remoteUid state=$state reason=$reason channel=${connection.channelId}',
              windowMs: 800,
            );
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (_remoteUid == remoteUid) {
            _remoteUid = null;
            _remoteUidController.add(null);
            _remoteVideoAvailable = false;
            _remoteVideoController.add(false);
          }
          if (kDebugMode) {
            AppLogger.debounced(
              'agora:remote_offline:$remoteUid:${connection.channelId}',
              'AgoraCall',
              'remote offline uid=$remoteUid reason=$reason channel=${connection.channelId}',
              windowMs: 1500,
            );
          }
        },
      ),
    );

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    if (enableVideo) {
      try {
        await _engine!.enableVideo();
        // Do NOT start camera preview automatically for 1:1 calls.
        //
        // Starting preview without a local renderer/consumer on some devices can
        // trigger continuous `ImageReader_JNI: Unable to acquire a buffer item`
        // warnings and flood logs. Local preview can be started explicitly by UI
        // if/when needed.
      } catch (e) {
        // Video preview can fail on some devices/permission states; don't crash init.
        _errorController.add(e.toString());
      }
    } else {
      try {
        await _engine!.disableVideo();
      } catch (e) {
        _errorController.add(e.toString());
      }
    }

    // Default audio route: speaker on.
    // Do NOT force speaker route during init.
    // On some devices this can throw ERR_NOT_READY (-3) (often with null message).
    // We apply it after `onJoinChannelSuccess` instead.

    _initialized = true;
  }

  Future<void> join({
    required String token,
    required String channelName,
    int uid = 0,
  }) async {
    if (!_initialized || _engine == null) {
      _errorController.add('Agora engine not initialized');
      return;
    }
    if (_joined) return;
    try {
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishMicrophoneTrack: true,
          publishCameraTrack: _cameraOn,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      _errorController.add(e.toString());
    }
  }

  Future<void> leave() async {
    if (_engine == null) return;
    try {
      if (_joined) {
        await _engine!.leaveChannel();
      }
    } catch (_) {}
    _joined = false;
    _joinedController.add(false);
    _remoteUid = null;
    _remoteUidController.add(null);
    _remoteVideoAvailable = false;
    _remoteVideoController.add(false);
  }

  Future<void> setMicMuted(bool muted) async {
    _micMuted = muted;
    if (_engine == null) return;
    try {
      await _engine!.muteLocalAudioStream(muted);
    } catch (e) {
      _errorController.add(e.toString());
    }
  }

  Future<void> setSpeakerOn(bool on) async {
    _speakerOn = on;
    if (_engine == null) return;
    try {
      await _engine!.setEnableSpeakerphone(on);
    } catch (e) {
      // Agora may throw if the engine is not fully ready (e.g. ERR_NOT_READY).
      if (_isErrNotReady(e)) return;
      _errorController.add(e.toString());
    }
  }

  Future<void> setCameraOn(bool on) async {
    _cameraOn = on;
    if (_engine == null) return;
    try {
      if (on) {
        await _engine!.enableVideo();
        // If user explicitly enabled video, start preview so local PiP can render.
        await _engine!.startPreview();
        // Ensure we publish camera once enabled.
        if (_joined) {
          await _engine!.updateChannelMediaOptions(
            ChannelMediaOptions(publishCameraTrack: true),
          );
        }
      } else {
        // Best-effort stop preview if it was started by UI.
        await _engine!.stopPreview();
        await _engine!.disableVideo();
        if (_joined) {
          await _engine!.updateChannelMediaOptions(
            ChannelMediaOptions(publishCameraTrack: false),
          );
        }
      }
    } catch (e) {
      _errorController.add(e.toString());
    }
  }

  Future<void> dispose() async {
    await leave();
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    _initialized = false;
  }
}

