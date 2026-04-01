import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment_model.dart';
import '../models/call_model.dart';
import '../../services/socket/socket_service.dart';
import '../../services/auth/auth_service.dart';
import 'auth_provider_riverpod.dart';
import 'posts_provider_riverpod.dart';
import 'comments_provider_riverpod.dart';
import 'chat_provider_riverpod.dart';
import 'notifications_provider_riverpod.dart';
import 'calls_provider_riverpod.dart';
import 'reels_provider_riverpod.dart';
import '../../features/long_videos/providers/long_videos_provider.dart';
import '../utils/share_link_helper.dart';
import 'socket_instance_provider_riverpod.dart';

/// Ensures socket connects when user is logged in and disconnects on logout.
/// Single connection only; guards against concurrent ensureConnection.
class SocketConnectionNotifier extends StateNotifier<bool> {
  SocketConnectionNotifier(this._getService, this._ref) : super(false) {
    _service = _getService();
  }

  final SocketService Function() _getService;
  final Ref _ref;
  late final SocketService _service;
  StreamSubscription<Map<String, dynamic>>? _chatMessageSub;
  StreamSubscription<Map<String, dynamic>>? _chatDeletedSub;
  StreamSubscription<Map<String, dynamic>>? _chatGroupCreatedSub;
  StreamSubscription? _notificationSub;
  StreamSubscription<IncomingCallPayload>? _callIncomingSub;
  StreamSubscription<CallEndedPayload>? _callEndedSub;
  StreamSubscription<CallAcceptedPayload>? _callAcceptedSub;
  StreamSubscription<CallRejectedPayload>? _callRejectedSub;
  bool _isEnsuringConnection = false;

  Future<void> ensureConnection() async {
    if (_isEnsuringConnection) {
      if (kDebugMode) debugPrint('[SocketProvider] ensureConnection skipped: already in progress');
      return;
    }
    final user = _ref.read(currentUserProvider);
    if (user == null || user.id.isEmpty) {
      if (_service.isConnected) {
        _service.disconnect();
        _chatMessageSub?.cancel();
        _chatMessageSub = null;
        state = false;
      }
      return;
    }
    if (_service.isConnected) {
      _service.chatSocket.register(user.id);
      _service.callsSocket.register(user.id);
      _service.livestreamSocket.register(user.id);
      _wireCallbacks();
      state = true;
      return;
    }
    _isEnsuringConnection = true;
    try {
      final token = await AuthService().getToken();
      _service.connect(user.id, token: token);
      _wireCallbacks();
      state = true;
      if (kDebugMode) debugPrint('[SocketProvider] ensureConnection done userId=${user.id}');
    } finally {
      _isEnsuringConnection = false;
    }
  }

  void _wireCallbacks() {
    _service.onLikesUpdated = (data) {
      final postId = data['postId']?.toString();
      final likesCount = data['likesCount'];
      final action = data['action']?.toString();
      if (postId == null || postId.isEmpty) return;
      final count = likesCount is int ? likesCount : (likesCount != null ? int.tryParse(likesCount.toString()) : null);
      _ref.read(postsProvider.notifier).applyLikesUpdate(postId: postId, likesCount: count, action: action);
      _ref.read(reelsProvider.notifier).applyLikesUpdate(postId: postId, likesCount: count, action: action);
      _ref.read(longVideosProvider.notifier).applyLikesUpdate(postId: postId, likesCount: count, action: action);
    };
    _service.commentsSocket.setOnNewComment((PostComment comment) {
      _ref.read(commentsProvider(comment.postId).notifier).appendComment(comment);
      _ref.read(postsProvider.notifier).incrementCommentCount(comment.postId);
    });
    _chatMessageSub?.cancel();
    _chatMessageSub = _service.chatSocket.onMessage.listen((data) {
      // Data is normalized by ChatSocketService (message, conversationId, createdAt, etc.)
      final convId = data['conversationId']?.toString() ?? '';
      final messageType = (data['messageType'] ?? data['type'] ?? 'text').toString();
      final messageText = _previewTextFromChatPayload(data);
      final createdAt = data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now();
      final senderId = data['senderId']?.toString() ?? '';
      final currentUser = _ref.read(currentUserProvider);
      final isFromPeer = currentUser != null && senderId.isNotEmpty && senderId != currentUser.id;

      if (kDebugMode) {
        debugPrint('[SocketProvider][Chat] onMessage: convId=$convId message=${messageText.length > 30 ? "${messageText.substring(0, 30)}..." : messageText}');
      }

      // Always update chat list so list screen shows latest message; mark unread when message is from peer
      if (convId.isNotEmpty) {
        _ref.read(conversationsProvider.notifier).updateLastMessageFromSocket(
          convId,
          messageText,
          createdAt,
          isFromPeer: isFromPeer,
          lastMessageType: messageType,
        );
        if (kDebugMode) debugPrint('[SocketProvider][Chat] onMessage: updated conversations list');
      }

      // If user has this chat open, append to messages so chat screen updates
      final currentConvId = _ref.read(currentConversationIdProvider);
      if (currentConvId == null || currentConvId.isEmpty) {
        if (kDebugMode) debugPrint('[SocketProvider][Chat] onMessage: open chat not set, list updated only');
        return;
      }
      if (_normalizeConvId(convId) != _normalizeConvId(currentConvId)) {
        if (kDebugMode) debugPrint('[SocketProvider][Chat] onMessage: message for different conv, list updated only');
        return;
      }

      if (convId.startsWith('group:')) {
        final groupId = convId.split(':').length > 1 ? convId.split(':').last : '';
        if (groupId.isEmpty) return;
        if (kDebugMode) debugPrint('[SocketProvider][Chat] onMessage: appending to open group groupId=$groupId');
        _ref.read(groupChatProvider(groupId).notifier).appendFromSocket(data);
        return;
      }

      final peerUserId = _ref.read(currentChatPeerUserIdProvider);
      if (peerUserId == null || peerUserId.isEmpty) {
        if (kDebugMode) debugPrint('[SocketProvider][Chat] onMessage: direct chat open but peerUserId not set');
        return;
      }
      if (kDebugMode) debugPrint('[SocketProvider][Chat] onMessage: appending to open chat peerUserId=$peerUserId');
      _ref.read(chatMessagesProvider(peerUserId).notifier).appendFromSocket(data);
    });
    if (kDebugMode) debugPrint('[SocketProvider][Chat] _wireCallbacks: chat onMessage listener subscribed');

    _chatDeletedSub?.cancel();
    _chatDeletedSub = _service.chatSocket.onMessageDeleted.listen((data) {
      final convId = data['conversationId']?.toString() ?? '';
      final messageId = (data['messageId'] ?? data['_id'] ?? data['id'] ?? '').toString();
      if (messageId.isEmpty) return;

      if (kDebugMode) {
        debugPrint('[SocketProvider][Chat] onMessageDeleted: convId=$convId messageId=$messageId');
      }

      // Only mutate open chat if it's the same conversation; otherwise list will refresh on next load.
      final currentConvId = _ref.read(currentConversationIdProvider);
      if (currentConvId == null || currentConvId.isEmpty) return;
      if (_normalizeConvId(convId) != _normalizeConvId(currentConvId)) return;
      if (convId.startsWith('group:')) {
        final groupId = convId.split(':').length > 1 ? convId.split(':').last : '';
        if (groupId.isEmpty) return;
        _ref.read(groupChatProvider(groupId).notifier).removeFromSocket(data);
        return;
      }
      final peerUserId = _ref.read(currentChatPeerUserIdProvider);
      if (peerUserId == null || peerUserId.isEmpty) return;
      _ref.read(chatMessagesProvider(peerUserId).notifier).removeFromSocket(data);
    });

    _chatGroupCreatedSub?.cancel();
    _chatGroupCreatedSub = _service.chatSocket.onGroupCreated.listen((data) {
      if (kDebugMode) {
        debugPrint('[SocketProvider][Chat] onGroupCreated: ${data['groupId'] ?? data['id'] ?? ''}');
      }
      // Groups are surfaced in conversations list; easiest safe behavior is reload.
      _ref.read(conversationsProvider.notifier).load();
    });

    _notificationSub?.cancel();
    _notificationSub = _service.notificationsSocket.onNotification.listen(
      (item) {
        _ref.read(notificationsProvider.notifier).appendFromSocket(item);
      },
    );
    if (kDebugMode) {
      debugPrint(
          '[SocketProvider][Notifications] _wireCallbacks: notifications listener subscribed');
    }

    _callIncomingSub?.cancel();
    _callIncomingSub = _service.callsSocket.onIncomingCall.listen(
      (payload) => _ref.read(callsProvider.notifier).onIncomingCall(payload),
    );

    _callEndedSub?.cancel();
    _callEndedSub = _service.callsSocket.onCallEnded.listen(
      (payload) => _ref.read(callsProvider.notifier).onCallEnded(payload),
    );

    _callAcceptedSub?.cancel();
    _callAcceptedSub = _service.callsSocket.onCallAccepted.listen(
      (payload) => _ref.read(callsProvider.notifier).onCallAccepted(payload),
    );

    _callRejectedSub?.cancel();
    _callRejectedSub = _service.callsSocket.onCallRejected.listen(
      (payload) => _ref.read(callsProvider.notifier).onCallRejected(payload),
    );

    if (kDebugMode) {
      debugPrint('[SocketProvider][Calls] wired incoming/ended listeners');
    }
  }

  void disconnect() {
    if (kDebugMode) debugPrint('[SocketProvider][Chat] disconnect()');
    _chatMessageSub?.cancel();
    _chatMessageSub = null;
    _chatDeletedSub?.cancel();
    _chatDeletedSub = null;
    _chatGroupCreatedSub?.cancel();
    _chatGroupCreatedSub = null;
    _notificationSub?.cancel();
    _notificationSub = null;
    _callIncomingSub?.cancel();
    _callIncomingSub = null;
    _callEndedSub?.cancel();
    _callEndedSub = null;
    _callAcceptedSub?.cancel();
    _callAcceptedSub = null;
    _callRejectedSub?.cancel();
    _callRejectedSub = null;
    _service.disconnect();
    state = false;
  }
}

String _previewTextFromChatPayload(Map<String, dynamic> data) {
  final type = (data['messageType'] ?? data['type'] ?? 'text').toString();
  final raw = (data['message'] ?? data['text'] ?? data['content'] ?? '').toString();

  if (type == 'deleted') return 'Message deleted';
  if (type == 'post') {
    final t = raw.trim();
    return t.isNotEmpty ? t : 'Shared a post';
  }

  // Prefer explicit attachments when message text is empty (media messages).
  final attachments = data['attachments'];
  if ((type == 'image' || type == 'video' || type == 'media') &&
      (raw.trim().isEmpty)) {
    if (attachments is List && attachments.isNotEmpty) {
      final first = attachments.first;
      final mediaType = first is Map
          ? (first['mediaType'] ?? first['type'] ?? '').toString()
          : '';
      if (mediaType == 'video' || type == 'video') return 'Video';
      if (mediaType == 'image' || type == 'image') return 'Photo';
    }
    if (type == 'video') return 'Video';
    if (type == 'image') return 'Photo';
    return 'Media';
  }

  // Backward-compatibility for older share-link based UI.
  final parsed = ShareLinkHelper.parse(raw);
  if (parsed.contentId != null) return 'Shared content';

  return raw.trim().isNotEmpty ? raw.trim() : 'Message';
}

String _normalizeConvId(String id) {
  if (id.isEmpty || !id.contains('_')) return id;
  final parts = id.split('_');
  if (parts.length != 2) return id;
  parts.sort();
  return '${parts[0]}_${parts[1]}';
}

final socketConnectionProvider = StateNotifierProvider<SocketConnectionNotifier, bool>((ref) {
  return SocketConnectionNotifier(() => ref.read(socketServiceProvider), ref);
});
