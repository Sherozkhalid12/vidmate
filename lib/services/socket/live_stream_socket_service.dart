import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Socket service for real live streaming overlay events.
///
/// Note: backend event names are not provided in the message, so these are
/// implemented with common patterns. Update event names if your backend differs.
class LiveStreamSocketService {
  dynamic _socket;

  final StreamController<Map<String, dynamic>> _commentController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<int> _likeCountController =
      StreamController<int>.broadcast();

  Stream<Map<String, dynamic>> get onLiveComment => _commentController.stream;
  Stream<int> get onLikeCount => _likeCountController.stream;

  void attach(dynamic socket) {
    if (socket == null) return;
    if (_socket == socket) return;
    detach();
    _socket = socket;

    // Commonly-used event names for live overlays.
    _socket.on('live:comments:new', _handleComment);
    _socket.on('live:likes:updated', _handleLikesUpdated);

    if (kDebugMode) debugPrint('[LiveStreamSocket] attach: listeners added');
  }

  void detach() {
    if (_socket != null) {
      _socket.off('live:comments:new');
      _socket.off('live:likes:updated');
    }
    _socket = null;
  }

  /// Optional: join a live room/channel by id.
  void join(String liveId) {
    if (_socket == null || liveId.isEmpty) return;
    _socket.emit('live:join', liveId);
    if (kDebugMode) debugPrint('[LiveStreamSocket] live:join liveId=$liveId');
  }

  /// Optional: leave a live room/channel by id.
  void leave(String liveId) {
    if (_socket == null || liveId.isEmpty) return;
    _socket.emit('live:leave', liveId);
    if (kDebugMode) debugPrint('[LiveStreamSocket] live:leave liveId=$liveId');
  }

  void _handleComment(dynamic data) {
    if (_commentController.isClosed) return;
    try {
      final map = _normalizeToMap(data);
      if (map.isEmpty) return;
      _commentController.add(map);
    } catch (_) {}
  }

  void _handleLikesUpdated(dynamic data) {
    if (_likeCountController.isClosed) return;
    try {
      if (data is int) {
        _likeCountController.add(data);
        return;
      }
      final map = _normalizeToMap(data);
      final count = map['likeCount'] ??
          map['likesCount'] ??
          map['count'] ??
          map['likes'];
      final parsed = count is int
          ? count
          : int.tryParse(count?.toString() ?? '') ?? 0;
      _likeCountController.add(parsed);
    } catch (_) {}
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
}

