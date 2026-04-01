import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/models/call_model.dart';
import '../../core/utils/app_logger.dart';

/// Handles realtime call signaling:
/// - Client → Server: calls:register, calls:join, calls:leave
/// - Server → Client: calls:incoming, calls:ended
class CallsSocketService {
  dynamic _socket;

  final StreamController<IncomingCallPayload> _incomingController =
      StreamController<IncomingCallPayload>.broadcast();
  final StreamController<CallEndedPayload> _endedController =
      StreamController<CallEndedPayload>.broadcast();
  final StreamController<CallAcceptedPayload> _acceptedController =
      StreamController<CallAcceptedPayload>.broadcast();
  final StreamController<CallRejectedPayload> _rejectedController =
      StreamController<CallRejectedPayload>.broadcast();

  Stream<IncomingCallPayload> get onIncomingCall => _incomingController.stream;
  Stream<CallEndedPayload> get onCallEnded => _endedController.stream;
  Stream<CallAcceptedPayload> get onCallAccepted =>
      _acceptedController.stream;
  Stream<CallRejectedPayload> get onCallRejected =>
      _rejectedController.stream;

  void attach(dynamic socket) {
    if (socket == null) return;
    if (_socket == socket) return;

    detach();
    _socket = socket;

    _socket.on('calls:incoming', _handleIncomingCall);
    _socket.on('calls:ended', _handleCallEnded);
    _socket.on('calls:accepted', _handleCallAccepted);
    _socket.on('calls:rejected', _handleCallRejected);

    if (kDebugMode) AppLogger.d('CallsSocket', 'attach: listeners added');
  }

  void detach() {
    if (_socket != null) {
      _socket.off('calls:incoming');
      _socket.off('calls:ended');
      _socket.off('calls:accepted');
      _socket.off('calls:rejected');
    }
    _socket = null;
  }

  /// API event: register yourself on socket.
  void register(String userId) {
    if (_socket == null || userId.isEmpty) return;
    _socket.emit('calls:register', userId);
    if (kDebugMode) AppLogger.debounced('calls:register:$userId', 'CallsSocket', 'calls:register userId=$userId');
  }

  /// Optional: join by callId room.
  void join(String callId) {
    if (_socket == null || callId.isEmpty) return;
    _socket.emit('calls:join', callId);
    if (kDebugMode) AppLogger.debounced('calls:join:$callId', 'CallsSocket', 'calls:join callId=$callId');
  }

  /// Optional: leave by callId room.
  void leave(String callId) {
    if (_socket == null || callId.isEmpty) return;
    _socket.emit('calls:leave', callId);
    if (kDebugMode) AppLogger.debounced('calls:leave:$callId', 'CallsSocket', 'calls:leave callId=$callId');
  }

  void _handleIncomingCall(dynamic data) {
    if (_incomingController.isClosed) return;
    try {
      final map = _normalizeToMap(data);
      if (map.isEmpty) return;
      final payload = IncomingCallPayload.fromJson(map);
      if (kDebugMode) {
        AppLogger.debounced(
          'calls:incoming:${payload.call.callId}',
          'CallsSocket',
          'calls:incoming callerId=${payload.callerId} receiverId=${payload.receiverId} callId=${payload.call.callId} channel=${payload.call.channelName}',
        );
      }
      _incomingController.add(payload);
    } catch (e, st) {
      if (kDebugMode) {
        AppLogger.d('CallsSocket', '_handleIncomingCall error: $e\n$st');
      }
    }
  }

  void _handleCallEnded(dynamic data) {
    if (_endedController.isClosed) return;
    try {
      final map = _normalizeToMap(data);
      if (map.isEmpty) return;
      final payload = CallEndedPayload.fromJson(map);
      if (kDebugMode) {
        AppLogger.debounced(
          'calls:ended:${payload.call.callId}',
          'CallsSocket',
          'calls:ended endedBy=${payload.endedBy} callId=${payload.call.callId}',
        );
      }
      _endedController.add(payload);
    } catch (e, st) {
      if (kDebugMode) {
        AppLogger.d('CallsSocket', '_handleCallEnded error: $e\n$st');
      }
    }
  }

  void _handleCallAccepted(dynamic data) {
    if (_acceptedController.isClosed) return;
    try {
      if (kDebugMode) {
        final type = data == null ? 'null' : data.runtimeType.toString();
        final preview = (data is String)
            ? (data.length > 260 ? '${data.substring(0, 260)}…' : data)
            : (data is Map
                ? Map<String, dynamic>.from(data).toString()
                : data.toString());
        AppLogger.debounced(
          'calls:accepted:raw',
          'CallsSocket',
          'calls:accepted rawType=$type raw=$preview',
          windowMs: 1500,
        );
      }
      final map = _normalizeToMap(data);
      if (map.isEmpty) return;
      final payload = CallAcceptedPayload.fromJson(map);
      if (kDebugMode) {
        AppLogger.debounced(
          'calls:accepted:${payload.call.callId}',
          'CallsSocket',
          'calls:accepted callerId=${payload.callerId} receiverId=${payload.receiverId} acceptedBy=${payload.acceptedBy} callId=${payload.call.callId} token=${(payload.token ?? '').isNotEmpty ? "present" : "missing"}',
          windowMs: 1500,
        );
      }
      _acceptedController.add(payload);
    } catch (e, st) {
      if (kDebugMode) {
        AppLogger.d('CallsSocket', '_handleCallAccepted error: $e\n$st');
      }
    }
  }

  void _handleCallRejected(dynamic data) {
    if (_rejectedController.isClosed) return;
    try {
      if (kDebugMode) {
        final type = data == null ? 'null' : data.runtimeType.toString();
        final preview = (data is String)
            ? (data.length > 260 ? '${data.substring(0, 260)}…' : data)
            : (data is Map
                ? Map<String, dynamic>.from(data).toString()
                : data.toString());
        AppLogger.debounced(
          'calls:rejected:raw',
          'CallsSocket',
          'calls:rejected rawType=$type raw=$preview',
          windowMs: 1500,
        );
      }
      final map = _normalizeToMap(data);
      if (map.isEmpty) return;
      final payload = CallRejectedPayload.fromJson(map);
      if (kDebugMode) {
        AppLogger.debounced(
          'calls:rejected:${payload.call.callId}',
          'CallsSocket',
          'calls:rejected callerId=${payload.callerId} receiverId=${payload.receiverId} rejectedBy=${payload.rejectedBy} callId=${payload.call.callId} token=${(payload.token ?? '').isNotEmpty ? "present" : "missing"}',
          windowMs: 1500,
        );
      }
      _rejectedController.add(payload);
    } catch (e, st) {
      if (kDebugMode) {
        AppLogger.d('CallsSocket', '_handleCallRejected error: $e\n$st');
      }
    }
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
    if (payload is List && payload.isNotEmpty) {
      payload = payload.first;
    }
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return {};
  }
}

