import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Handles realtime chat: register, join/leave room, and incoming messages.
/// Listens to [chat:message] and debug-prints received payload; single attach per socket.
class ChatSocketService {
  dynamic _socket;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _groupCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onGroupCreated =>
      _groupCreatedController.stream;

  /// Attach to socket and listen for chat:message. Idempotent: no-op if already attached to same socket.
  void attach(dynamic socket) {
    if (socket == null) {
      if (kDebugMode) debugPrint('[ChatSocket] attach: socket is null');
      return;
    }
    if (_socket == socket) {
      if (kDebugMode) debugPrint('[ChatSocket] attach: already attached to this socket, skip');
      return;
    }
    detach();
    _socket = socket;
    _socket.on('chat:message', (data) => _handleChatMessage('chat:message', data));
    _socket.on('chat:message:deleted',
        (data) => _handleChatMessage('chat:message:deleted', data));
    _socket.on('chat:group:created',
        (data) => _handleChatMessage('chat:group:created', data));
    if (kDebugMode) {
      debugPrint(
          '[ChatSocket] attach: listening for "chat:message", "chat:message:deleted", "chat:group:created"');
    }
  }

  void detach() {
    if (_socket != null) {
      _socket.off('chat:message');
      _socket.off('chat:message:deleted');
      _socket.off('chat:group:created');
      _socket = null;
      if (kDebugMode) debugPrint('[ChatSocket] detach: listeners removed');
    }
  }

  void register(String userId) {
    if (_socket != null && userId.isNotEmpty) {
      _socket.emit('chat:register', userId);
      if (kDebugMode) debugPrint('[ChatSocket] emit chat:register userId=$userId');
    } else if (kDebugMode) {
      debugPrint('[ChatSocket] register skipped: socket=${_socket != null} userId.isEmpty=${userId.isEmpty}');
    }
  }

  void join(String conversationId) {
    if (_socket != null && conversationId.isNotEmpty) {
      _socket.emit('chat:join', conversationId);
      if (kDebugMode) debugPrint('[ChatSocket] emit chat:join conversationId=$conversationId');
    } else if (kDebugMode) {
      debugPrint('[ChatSocket] join skipped: socket=${_socket != null} convId=${conversationId.isEmpty ? "empty" : conversationId}');
    }
  }

  void leave(String conversationId) {
    if (_socket != null && conversationId.isNotEmpty) {
      _socket.emit('chat:leave', conversationId);
      if (kDebugMode) debugPrint('[ChatSocket] emit chat:leave conversationId=$conversationId');
    } else if (kDebugMode) {
      debugPrint('[ChatSocket] leave skipped: socket=${_socket != null} convId=${conversationId.isEmpty ? "empty" : conversationId}');
    }
  }

  void _handleChatMessage(String eventName, dynamic data) {
    if (_messageController.isClosed ||
        _messageDeletedController.isClosed ||
        _groupCreatedController.isClosed) {
      if (kDebugMode) {
        debugPrint('[ChatSocket] SKIP: one or more controllers are closed');
      }
      return;
    }
    try {
      dynamic payload = data;
      if (payload is String) {
        try {
          final decoded = jsonDecode(payload);
          payload = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
        } catch (_) {
          payload = <String, dynamic>{};
        }
      }
      if (payload is List && payload.isNotEmpty) {
        payload = payload.first;
      }
      if (payload is! Map || payload.isEmpty) {
        if (kDebugMode) debugPrint('[ChatSocket] payload not a map or empty: ${payload.runtimeType}');
        return;
      }

      final map = Map<String, dynamic>.from(payload);

      // Always debug-print received data from socket (chat:message)
      if (kDebugMode) {
        final time = _formatLogTime(DateTime.now());
        const encoder = JsonEncoder.withIndent('  ');
        final jsonStr = encoder.convert(map);
        debugPrint('[ChatSocket] [$time] $eventName received:');
        debugPrint(jsonStr);
      }

      final mapData = _flattenEnvelope(map);

      if (eventName == 'chat:message') {
        final normalized = _normalizeMessagePayload(mapData);
        if (normalized.isNotEmpty) {
          _messageController.add(normalized);
          if (kDebugMode) {
            debugPrint(
                '[ChatSocket] -> onMessage (convId=${normalized['conversationId']} message=${(normalized['message'] ?? '').toString().length > 20 ? '...' : normalized['message']})');
          }
        }
        return;
      }

      if (eventName == 'chat:message:deleted') {
        final normalized = _normalizeDeletedPayload(mapData);
        if (normalized.isNotEmpty) {
          _messageDeletedController.add(normalized);
          if (kDebugMode) {
            debugPrint(
                '[ChatSocket] -> onMessageDeleted (messageId=${normalized['messageId'] ?? normalized['_id']})');
          }
        }
        return;
      }

      if (eventName == 'chat:group:created') {
        final normalized = _normalizeGroupCreatedPayload(mapData);
        if (normalized.isNotEmpty) {
          _groupCreatedController.add(normalized);
          if (kDebugMode) {
            debugPrint(
                '[ChatSocket] -> onGroupCreated (groupId=${normalized['groupId'] ?? normalized['id']})');
          }
        }
        return;
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ChatSocket] _handleChatMessage error: $e\n$st');
    }
  }

  /// Flattens server envelope:
  /// - { chat: {...}, conversationId, senderId, receiverId }
  /// - { data: {...} }
  static Map<String, dynamic> _flattenEnvelope(Map<String, dynamic> map) {
    var mapData = map;
    if (mapData['chat'] is Map) {
      final chat = Map<String, dynamic>.from(mapData['chat'] as Map);
      mapData = {
        'conversationId': mapData['conversationId'] ?? chat['conversationId'],
        'senderId': mapData['senderId'] ?? chat['senderId'],
        'receiverId': mapData['receiverId'] ?? chat['receiverId'],
        'groupId': mapData['groupId'] ?? chat['groupId'],
        'participantIds': mapData['participantIds'] ?? chat['participantIds'],
        ...chat,
      };
    } else if (mapData['data'] is Map) {
      mapData = Map<String, dynamic>.from(mapData['data'] as Map);
    }
    return mapData;
  }

  static Map<String, dynamic> _normalizeDeletedPayload(
      Map<String, dynamic> map) {
    if (map.isEmpty) return {};
    final messageId =
        map['messageId'] ?? map['_id'] ?? map['id'] ?? map['chatId'];
    if (messageId == null || messageId.toString().isEmpty) return {};
    return {
      ...map,
      'messageId': messageId.toString(),
      '_id': messageId.toString(),
      'id': messageId.toString(),
      'conversationId': (map['conversationId'] ?? map['conversation_id'] ?? '')
          .toString(),
    };
  }

  static Map<String, dynamic> _normalizeGroupCreatedPayload(
      Map<String, dynamic> map) {
    if (map.isEmpty) return {};
    final group = map['group'] is Map
        ? Map<String, dynamic>.from(map['group'] as Map)
        : null;
    final groupId = map['groupId'] ??
        (group != null ? (group['_id'] ?? group['id']) : null) ??
        map['_id'] ??
        map['id'];
    if (groupId == null || groupId.toString().isEmpty) return {};
    return {
      ...map,
      if (group != null) 'group': group,
      'groupId': groupId.toString(),
      'id': groupId.toString(),
      '_id': groupId.toString(),
    };
  }

  static String _formatLogTime(DateTime dt) {
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final am = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }

  /// Normalize payload so providers get consistent keys (message, _id, conversationId, createdAt).
  static Map<String, dynamic> _normalizeMessagePayload(Map<String, dynamic> map) {
    if (map.isEmpty) return map;
    final messageType = (map['messageType'] ?? map['type'] ?? 'text').toString();
    final message = (map['message'] ?? map['text'] ?? map['content'] ?? '').toString();
    final attachments = map['attachments'];
    final hasAttachments = attachments is List && attachments.isNotEmpty;
    final hasSharedPost = map['sharedPostData'] != null || map['sharedPostId'] != null;
    final hasRenderableContent = message.isNotEmpty || hasAttachments || hasSharedPost || messageType == 'deleted';
    if (!hasRenderableContent) return {};
    final id = map['_id'] ?? map['id'] ?? map['messageId'];
    final convId = map['conversationId'] ?? map['conversation_id'];
    final senderId = map['senderId'] ?? map['sender_id'] ?? map['from'];
    final createdAt = map['createdAt'] ?? map['created_at'] ?? map['timestamp'];
    final generatedId = id?.toString() ?? 'socket-${DateTime.now().millisecondsSinceEpoch}';
    return {
      ...map,
      '_id': generatedId,
      'id': generatedId,
      'messageType': messageType.isNotEmpty ? messageType : 'text',
      'message': message,
      'text': message,
      'conversationId': convId?.toString() ?? '',
      'senderId': senderId?.toString() ?? '',
      'receiverId': map['receiverId'] ?? map['receiver_id'] ?? '',
      'groupId': map['groupId'] ?? map['group_id'] ?? '',
      'createdAt': createdAt?.toString() ?? DateTime.now().toIso8601String(),
      'updatedAt': map['updatedAt'] ?? map['updated_at'] ?? createdAt?.toString() ?? DateTime.now().toIso8601String(),
      'readBy': map['readBy'] ?? map['read_by'] ?? [],
    };
  }
}
