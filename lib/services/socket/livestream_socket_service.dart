import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/utils/app_logger.dart';

/// Dedicated socket service for livestream realtime overlay (chat + likes + viewer count).
///
/// Server events (backend-provided, from your updated docs):
/// - Server → Client: `livestreams:message`
/// - Server → Client: `livestreams:likes-updated`
/// - Server → Client: `livestreams:viewer-joined` / `livestreams:user-joined`
/// - Server → Client: `livestreams:viewer-left` / `livestreams:user-left`
/// - Server → Client: `livestreams:viewer-count`
/// - Server → Client: `livestreams:started` (optional)
/// - Server → Client: `livestreams:ended`
///
/// Client emits (from your updated docs):
/// - `livestreams:register` (USER_ID)
/// - `livestreams:join` (viewer => streamId string, host => {streamId, hostId, asHost:true})
/// - `livestreams:leave` (viewer => streamId string, host => {streamId, hostId, asHost:true})
/// - optional `livestreams:host-online` / `livestreams:host-offline`
class LivestreamSocketService {
  dynamic _socket;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _likesUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<int> _viewerCountController = StreamController<int>.broadcast();
  final StreamController<int> _likeCountController =
      StreamController<int>.broadcast();
  final StreamController<Map<String, dynamic>> _endedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _startedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onLikesUpdated => _likesUpdatedController.stream;
  Stream<int> get onViewerCount => _viewerCountController.stream;
  Stream<int> get onLikeCount => _likeCountController.stream;
  Stream<Map<String, dynamic>> get onEnded => _endedController.stream;
  Stream<Map<String, dynamic>> get onStarted => _startedController.stream;

  void attach(dynamic socket) {
    if (socket == null) return;
    if (_socket == socket) return;
    detach();
    _socket = socket;

    _socket.on('livestreams:message', _handleMessage);
    _socket.on('livestreams:likes-updated', _handleLikesUpdated);
    _socket.on('livestreams:viewer-joined', _handleViewerJoinedLeft);
    _socket.on('livestreams:user-joined', _handleViewerJoinedLeft);
    _socket.on('livestreams:viewer-left', _handleViewerJoinedLeft);
    _socket.on('livestreams:user-left', _handleViewerJoinedLeft);
    _socket.on('livestreams:viewer-count', _handleViewerCount);
    _socket.on('livestreams:started', _handleStarted);
    _socket.on('livestreams:ended', _handleEnded);

    if (kDebugMode) AppLogger.d('LivestreamSocket', 'attach: listeners added');
  }

  void detach() {
    if (_socket != null) {
      _socket.off('livestreams:message');
      _socket.off('livestreams:likes-updated');
      _socket.off('livestreams:viewer-joined');
      _socket.off('livestreams:user-joined');
      _socket.off('livestreams:viewer-left');
      _socket.off('livestreams:user-left');
      _socket.off('livestreams:viewer-count');
      _socket.off('livestreams:started');
      _socket.off('livestreams:ended');
    }
    _socket = null;
  }

  void join(String streamId) {
    if (_socket == null || streamId.isEmpty) return;
    _socket.emit('livestreams:join', {'streamId': streamId});
    if (kDebugMode) {
      AppLogger.debounced(
        'livestreams:join:$streamId',
        'LivestreamSocket',
        'livestreams:join streamId=$streamId',
      );
    }
  }

  /// Emit `livestreams:register` with the current user id.
  void register(String userId) {
    if (_socket == null || userId.isEmpty) return;
    _socket.emit('livestreams:register', {'userId': userId});
  }

  /// Host join: emit `livestreams:join` with the recommended payload object.
  void joinHost({
    required String streamId,
    required String hostId,
  }) {
    if (_socket == null || streamId.isEmpty || hostId.isEmpty) return;
    _socket.emit('livestreams:join', {
      'streamId': streamId,
      'hostId': hostId,
      'asHost': true,
    });
  }

  /// Viewer leave: emit `livestreams:leave` with a streamId string payload.
  void leave(String streamId) {
    if (_socket == null || streamId.isEmpty) return;
    _socket.emit('livestreams:leave', {'streamId': streamId});
  }

  /// Host leave: emit `livestreams:leave` with the recommended payload object.
  void leaveHost({
    required String streamId,
    required String hostId,
  }) {
    if (_socket == null || streamId.isEmpty || hostId.isEmpty) return;
    _socket.emit('livestreams:leave', {
      'streamId': streamId,
      'hostId': hostId,
      'asHost': true,
    });
  }

  /// Optional manual host online/offline signals (only needed if backend expects it).
  void hostOnline({
    required String streamId,
    required String hostId,
  }) {
    if (_socket == null || streamId.isEmpty || hostId.isEmpty) return;
    _socket.emit('livestreams:host-online', {
      'streamId': streamId,
      'hostId': hostId,
    });
  }

  void hostOffline({
    required String streamId,
    required String hostId,
  }) {
    if (_socket == null || streamId.isEmpty || hostId.isEmpty) return;
    _socket.emit('livestreams:host-offline', {
      'streamId': streamId,
      'hostId': hostId,
    });
  }

  Map<String, dynamic> _normalizeToMap(dynamic data) {
    dynamic payload = data;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {
        payload = {};
      }
    }
    if (payload is List && payload.isNotEmpty) payload = payload.first;
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return {};
  }

  void _handleMessage(dynamic data) {
    if (_messageController.isClosed) return;
    final map = _normalizeToMap(data);
    if (map.isEmpty) return;
    _messageController.add(map);
  }

  void _handleLikesUpdated(dynamic data) {
    if (_likesUpdatedController.isClosed) return;
    if (_likeCountController.isClosed) return;
    final map = _normalizeToMap(data);
    if (map.isEmpty) return;
    _likesUpdatedController.add(map);
    final count = map['likeCount'] ?? map['likesCount'] ?? map['count'] ?? map['likes'];
    final parsed = count is int ? count : int.tryParse(count?.toString() ?? '') ?? 0;
    _likeCountController.add(parsed);
  }

  void _handleViewerJoinedLeft(dynamic data) {
    if (_viewerCountController.isClosed) return;
    final map = _normalizeToMap(data);
    if (map.isEmpty) return;

    final raw = map['viewerCount'] ?? map['viewer_count'] ?? (map['stream'] is Map ? (map['stream']['viewerCount'] ?? map['stream']['viewer_count']) : null);
    if (raw == null) return;

    final parsed = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
    _viewerCountController.add(parsed);
  }

  void _handleViewerCount(dynamic data) {
    if (_viewerCountController.isClosed) return;
    final map = _normalizeToMap(data);
    if (map.isEmpty) return;

    final raw = map['viewerCount'] ?? map['viewer_count'];
    if (raw == null) return;

    final parsed = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
    _viewerCountController.add(parsed);
  }

  void _handleStarted(dynamic data) {
    if (_startedController.isClosed) return;
    final map = _normalizeToMap(data);
    if (map.isEmpty) return;
    _startedController.add(map);
  }

  void _handleEnded(dynamic data) {
    if (_endedController.isClosed) return;
    final map = _normalizeToMap(data);
    if (map.isEmpty) return;
    _endedController.add(map);
  }
}

