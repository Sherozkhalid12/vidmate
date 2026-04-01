import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/api_constants.dart';

import 'comments_socket_service.dart';
import 'chat_socket_service.dart';
import 'notifications_socket_service.dart';
import 'calls_socket_service.dart';
import 'live_stream_socket_service.dart';
import 'livestream_socket_service.dart';

/// Main socket service: single connection after login. One socket only; no duplicates.
/// Correct sequence for chat: connect → attach listeners → onConnect → chat:register (required by server).
class SocketService {
  io.Socket? _socket;
  String? _currentUserId;
  bool _isConnecting = false;
  final CommentsSocketService _commentsSocket = CommentsSocketService();
  final ChatSocketService _chatSocket = ChatSocketService();
  final NotificationsSocketService _notificationsSocket =
      NotificationsSocketService();
  final CallsSocketService _callsSocket = CallsSocketService();
  final LiveStreamSocketService _liveStreamSocket = LiveStreamSocketService();
  final LivestreamSocketService _livestreamSocket = LivestreamSocketService();

  CommentsSocketService get commentsSocket => _commentsSocket;
  ChatSocketService get chatSocket => _chatSocket;
  NotificationsSocketService get notificationsSocket => _notificationsSocket;
  CallsSocketService get callsSocket => _callsSocket;
  LiveStreamSocketService get liveStreamSocket => _liveStreamSocket;
  LivestreamSocketService get livestreamSocket => _livestreamSocket;

  bool get isConnected => _socket?.connected == true;

  /// Callbacks set by Riverpod so socket events update state.
  void Function(Map<String, dynamic>)? onLikesUpdated;

  /// Connect to socket server. Single connection only.
  /// Steps: 1) Create socket 2) Attach listeners (comments, chat:message, likes) 3) On connect → chat:register (required for chat to work).
  void connect(String userId, {String? token}) {
    if (userId.isEmpty) {
      if (kDebugMode) debugPrint('[Socket] connect skipped: empty userId');
      return;
    }
    if (_isConnecting) {
      if (kDebugMode) debugPrint('[Socket] connect skipped: already connecting');
      return;
    }
    if (_socket != null && _socket!.connected) {
      if (kDebugMode) debugPrint('[Socket] already connected');
      _ensureChatRegistered();
      return;
    }

    _isConnecting = true;
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _commentsSocket.detach();
    _chatSocket.detach();

    final url = ApiConstants.socketUrl;
    assert(url.isNotEmpty, 'Socket URL must be set');
    if (kDebugMode) debugPrint('[Socket] connecting to $url userId=$userId');

    _currentUserId = userId;
    _socket = io.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      if (token != null && token.isNotEmpty) 'extraHeaders': {'Authorization': 'Bearer $token'},
    });

    // 1) Attach listeners first (same as comments: attach then server can send events)
    _attachAllServices();

    // 2) Register for chat ONLY after connection – server requires chat:register to route chat:message
    _socket!.onConnect((_) {
      _isConnecting = false;
      if (kDebugMode) debugPrint('[Socket] connected');
      _ensureChatRegistered();
      // Join notifications channel for this user
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        _notificationsSocket.join(_currentUserId!);
        _callsSocket.register(_currentUserId!);
        _livestreamSocket.register(_currentUserId!);
      }
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) debugPrint('[Socket] disconnected');
    });

    _socket!.onConnectError((e) {
      _isConnecting = false;
      if (kDebugMode) debugPrint('[Socket] connect error: $e');
    });
  }

  /// Emit chat:register with current user. Call only when socket is connected (e.g. in onConnect).
  /// Without this the server will not deliver chat:message to this client.
  void _ensureChatRegistered() {
    if (_socket == null || !_socket!.connected) return;
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    _chatSocket.register(_currentUserId!);
    if (kDebugMode) debugPrint('[Socket] chat:register sent userId=$_currentUserId');
  }

  void _attachAllServices() {
    if (_socket == null) return;
    _commentsSocket.attach(_socket);
    _chatSocket.attach(_socket);
    _notificationsSocket.attach(_socket);
    _callsSocket.attach(_socket);
    _liveStreamSocket.attach(_socket);
    _livestreamSocket.attach(_socket);
    _socket!.on('likes:updated', _handleLikesUpdated);
    if (kDebugMode) {
      debugPrint(
          '[Socket] services attached (comments, chat:message, notifications:new, calls, live, likes)');
    }
  }

  void _handleLikesUpdated(dynamic data) {
    if (onLikesUpdated == null) return;
    try {
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : null);
      if (map != null && map.isNotEmpty) onLikesUpdated!(map);
    } catch (_) {}
  }

  /// Disconnect and clear. Call on logout. Ensures single clean teardown.
  void disconnect() {
    if (kDebugMode) debugPrint('[Socket] disconnect()');
    _isConnecting = false;
    _socket?.off('likes:updated');
    _commentsSocket.detach();
    _chatSocket.detach();
    _notificationsSocket.detach();
    _callsSocket.detach();
    _liveStreamSocket.detach();
    _livestreamSocket.detach();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentUserId = null;
    onLikesUpdated = null;
  }
}
