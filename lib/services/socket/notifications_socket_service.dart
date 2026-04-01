import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../services/notifications/notifications_service.dart';

/// Handles realtime notifications: join channel and listen for notifications:new.
class NotificationsSocketService {
  dynamic _socket;
  final StreamController<NotificationItem> _controller =
      StreamController<NotificationItem>.broadcast();

  Stream<NotificationItem> get onNotification => _controller.stream;

  void attach(dynamic socket) {
    if (socket == null) {
      if (kDebugMode) {
        debugPrint('[NotificationsSocket] attach: socket is null');
      }
      return;
    }
    if (_socket == socket) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationsSocket] attach: already attached to this socket, skip');
      }
      return;
    }
    detach();
    _socket = socket;
    _socket.on('notifications:new', _handleNotification);
    if (kDebugMode) {
      debugPrint(
          '[NotificationsSocket] attach: listening for \"notifications:new\"');
    }
  }

  void detach() {
    if (_socket != null) {
      _socket.off('notifications:new');
      _socket = null;
      if (kDebugMode) {
        debugPrint('[NotificationsSocket] detach: listeners removed');
      }
    }
  }

  /// Join notifications channel with current user id.
  void join(String userId) {
    if (_socket != null && userId.isNotEmpty) {
      _socket.emit('notifications:join', userId);
      if (kDebugMode) {
        debugPrint(
            '[NotificationsSocket] emit notifications:join userId=$userId');
      }
    } else if (kDebugMode) {
      debugPrint(
          '[NotificationsSocket] join skipped: socket=${_socket != null} userId.isEmpty=${userId.isEmpty}');
    }
  }

  void _handleNotification(dynamic data) {
    if (_controller.isClosed) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationsSocket] SKIP: _controller is closed, dropping event');
      }
      return;
    }
    try {
      dynamic payload = data;
      if (payload is String) {
        try {
          payload = jsonDecode(payload);
        } catch (_) {
          payload = {};
        }
      }
      if (payload is List && payload.isNotEmpty) {
        payload = payload.first;
      }
      if (payload is! Map || payload.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '[NotificationsSocket] payload not a map or empty: ${payload.runtimeType}');
        }
        return;
      }
      final map = payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map);

      final item = NotificationItem.fromJson(map);
      _controller.add(item);

      if (kDebugMode) {
        debugPrint(
            '[NotificationsSocket] notifications:new id=${item.id} type=${item.type}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[NotificationsSocket] _handleNotification error: $e\n$st');
      }
    }
  }
}

