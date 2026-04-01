import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/chat_message_bubble.dart';
import '../models/chat_conversation_api.dart';
import '../../services/chat/chat_service.dart';
import 'auth_provider_riverpod.dart';
import '../utils/share_link_helper.dart';
import '../../services/storage/user_storage_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// Current open chat: peer user id and conversation id (for socket routing).
final currentChatPeerUserIdProvider = StateProvider<String?>((ref) => null);
final currentConversationIdProvider = StateProvider<String?>((ref) => null);

// --- Conversations list ---

class ConversationsState {
  final List<ChatConversationItem> conversations;
  final bool loading;
  final String? error;
  /// Conversation IDs that have unread messages (from peer).
  final Set<String> unreadConversationIds;

  const ConversationsState({
    this.conversations = const [],
    this.loading = false,
    this.error,
    this.unreadConversationIds = const {},
  });
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  ConversationsNotifier(this._ref) : super(const ConversationsState());
  final Ref _ref;

  Future<void> load() async {
    state = ConversationsState(
      loading: true,
      conversations: state.conversations,
      unreadConversationIds: state.unreadConversationIds,
    );
    final service = _ref.read(chatServiceProvider);
    final result = await service.getConversations();
    if (!result.success) {
      state = ConversationsState(
        loading: false,
        error: result.errorMessage,
        conversations: state.conversations,
        unreadConversationIds: state.unreadConversationIds,
      );
      return;
    }
    state = ConversationsState(
      loading: false,
      conversations: result.conversations,
      error: null,
      unreadConversationIds: state.unreadConversationIds,
    );
  }

  void markConversationAsRead(String conversationId) {
    if (conversationId.isEmpty) return;
    final next = Set<String>.from(state.unreadConversationIds)..remove(conversationId);
    if (next.length == state.unreadConversationIds.length) return;
    state = ConversationsState(
      loading: state.loading,
      conversations: state.conversations,
      error: state.error,
      unreadConversationIds: next,
    );
  }

  /// Update last message for a conversation from socket (so chat list reflects new messages).
  /// When [isFromPeer] is true, the conversation is marked unread (show dot).
  void updateLastMessageFromSocket(
    String conversationId,
    String messageText,
    DateTime messageAt, {
    bool isFromPeer = false,
    String lastMessageType = 'text',
  }) {
    if (conversationId.isEmpty) return;
    final list = state.conversations;
    final index = list.indexWhere((c) => _normalizeConvId(c.conversationId) == _normalizeConvId(conversationId));
    if (index < 0) {
      load();
      if (isFromPeer) {
        final next = Set<String>.from(state.unreadConversationIds)..add(conversationId);
        state = ConversationsState(
          loading: state.loading,
          conversations: state.conversations,
          error: state.error,
          unreadConversationIds: next,
        );
      }
      return;
    }
    final item = list[index];
    final updated = ChatConversationItem(
      conversationId: item.conversationId,
      user: item.user,
      group: item.group,
      isGroup: item.isGroup,
      lastMessage: messageText,
      lastMessageType: lastMessageType.isNotEmpty ? lastMessageType : item.lastMessageType,
      lastMessageAt: messageAt,
    );
    final newList = List<ChatConversationItem>.from(list)..[index] = updated;
    newList.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    Set<String> unread = state.unreadConversationIds;
    if (isFromPeer) {
      unread = Set<String>.from(unread)..add(conversationId);
    }
    state = ConversationsState(
      loading: state.loading,
      conversations: newList,
      error: state.error,
      unreadConversationIds: unread,
    );
  }

  static String _normalizeConvId(String id) {
    if (id.isEmpty || !id.contains('_')) return id;
    final parts = id.split('_');
    if (parts.length != 2) return id;
    parts.sort();
    return '${parts[0]}_${parts[1]}';
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  return ConversationsNotifier(ref);
});

// --- Messages for one conversation (by peer userId) ---

class ChatMessagesState {
  final String? conversationId;
  final List<MessageModel> messages;
  final bool loading;
  final String? error;
  final bool sending;
  final bool loadingOlder;
  final bool hasMoreOlder;

  const ChatMessagesState({
    this.conversationId,
    this.messages = const [],
    this.loading = false,
    this.error,
    this.sending = false,
    this.loadingOlder = false,
    this.hasMoreOlder = true,
  });
}

MessageModel _messageFromBubble(
  ChatMessageBubble b,
  String currentUserId,
  UserModel currentUser,
  UserModel peerUser,
) {
  final isFromMe = b.senderId == currentUserId;

  final raw = b.message;
  final msgType = b.messageType.trim().isEmpty ? 'text' : b.messageType.trim();

  // Sender info: prefer backend-provided `sender{}` and `senderProfilePicture`.
  final sender = isFromMe
      ? currentUser
      : UserModel(
          id: b.sender?.id.isNotEmpty == true ? b.sender!.id : peerUser.id,
          username: b.sender?.username.isNotEmpty == true ? b.sender!.username : peerUser.username,
          displayName: b.sender?.username.isNotEmpty == true ? b.sender!.username : peerUser.displayName,
          avatarUrl: (b.sender?.profilePicture.isNotEmpty == true
                  ? b.sender!.profilePicture
                  : (b.senderProfilePicture.isNotEmpty ? b.senderProfilePicture : peerUser.avatarUrl)),
        );

  // Read receipts: for outgoing messages, prefer "receiver has read" when available.
  final isRead = isFromMe
      ? (b.receiverId.isNotEmpty ? b.readBy.contains(b.receiverId) : b.readBy.any((id) => id != currentUserId))
      : true;

  String text = raw;
  MessageType type = MessageType.text;
  String? mediaUrl;

  if (b.isDeletedForEveryone || msgType == 'deleted') {
    text = 'Message deleted';
    type = MessageType.text;
    mediaUrl = null;
  } else if (msgType == 'post') {
    final p = b.sharedPostData;
    final img = (p != null && p.images.isNotEmpty) ? p.images.first : '';
    final vid = (p != null && p.video.isNotEmpty) ? p.video : '';
    if (img.isNotEmpty) {
      type = MessageType.image;
      mediaUrl = img;
    } else if (vid.isNotEmpty) {
      type = MessageType.video;
      mediaUrl = vid;
    } else {
      type = MessageType.text;
    }
    final caption = (p != null && p.caption.trim().isNotEmpty) ? p.caption.trim() : '';
    text = raw.trim().isNotEmpty ? raw.trim() : (caption.isNotEmpty ? caption : 'Shared a post');
    // If we have a preview image/video but no caption, don't render placeholder text inside the bubble.
    if (type != MessageType.text && text == 'Shared a post') {
      text = '';
    }
  } else if (msgType == 'image' || msgType == 'video' || msgType == 'media') {
    final att = b.attachments.where((a) => a.url.trim().isNotEmpty).toList();
    final pick = att.isNotEmpty ? att.first : null;
    final attType = pick?.mediaType.trim().toLowerCase() ?? '';
    final url = pick?.url.trim() ?? '';
    if (url.isNotEmpty) {
      mediaUrl = url;
      if (msgType == 'video' || attType == 'video') {
        type = MessageType.video;
      } else {
        type = MessageType.image;
      }
    } else {
      type = MessageType.text;
    }
    text = raw.trim();
  } else {
    // Backward-compatibility for older share-link based UI.
    final payload = ShareLinkHelper.parse(raw);
    final hasThumb =
        payload.thumbnailUrl != null && payload.thumbnailUrl!.isNotEmpty;
    if (payload.contentId != null && hasThumb) {
      type = MessageType.image;
      mediaUrl = payload.thumbnailUrl;
      text = '';
    } else {
      // Fallback URL heuristics (some backends used to send URL in `message` for media).
      final lower = raw.toLowerCase().trim();
      final looksLikeUrl = lower.startsWith('http://') || lower.startsWith('https://');
      final isImageUrl = looksLikeUrl &&
          (lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.webp') ||
              lower.contains('.jpg?') ||
              lower.contains('.jpeg?') ||
              lower.contains('.png?') ||
              lower.contains('.webp?'));
      final isVideoUrl = looksLikeUrl &&
          (lower.endsWith('.mp4') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.mkv') ||
              lower.contains('.mp4?') ||
              lower.contains('.mov?') ||
              lower.contains('.mkv?'));
      if (isImageUrl) {
        type = MessageType.image;
        mediaUrl = raw;
        text = '';
      } else if (isVideoUrl) {
        type = MessageType.video;
        mediaUrl = raw;
        text = '';
      } else {
        type = MessageType.text;
        mediaUrl = null;
        text = raw;
      }
    }
  }

  return MessageModel(
    id: b.id,
    sender: sender,
    text: text,
    timestamp: b.createdAt,
    isRead: isRead,
    type: type,
    mediaUrl: mediaUrl,
  );
}

bool _matchesPendingMessage(MessageModel pending, MessageModel incoming) {
  if (pending.status != MessageSendStatus.sending) return false;
  if (pending.type != incoming.type) return false;
  final timeDiff = pending.timestamp.difference(incoming.timestamp).abs();
  if (timeDiff > const Duration(minutes: 2)) return false;
  if (pending.type == MessageType.text) {
    return pending.text.trim() == incoming.text.trim();
  }
  // For media/post-like messages, match by type and timing.
  return true;
}

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  ChatMessagesNotifier(this._peerUserId, this._ref) : super(const ChatMessagesState());
  final String _peerUserId;
  final Ref _ref;

  ChatService get _service => _ref.read(chatServiceProvider);

  static const int _pageSize = 20;

  Future<void> load() async {
    state = ChatMessagesState(
      loading: true,
      messages: state.messages,
      conversationId: state.conversationId,
      hasMoreOlder: state.hasMoreOlder,
    );
    final result = await _service.getUserChat(_peerUserId, limit: _pageSize, skip: 0);
    final currentUser = _ref.read(currentUserProvider);
    if (!result.success || currentUser == null) {
      state = ChatMessagesState(
        loading: false,
        error: result.errorMessage ?? 'Not authenticated',
        messages: state.messages,
        conversationId: state.conversationId,
        hasMoreOlder: state.hasMoreOlder,
      );
      return;
    }
    final peerUser = UserModel(
      id: _peerUserId,
      username: '',
      displayName: '',
      avatarUrl: '',
    );
    final messages = result.messages
        .map((b) => _messageFromBubble(b, currentUser.id, currentUser, peerUser))
        .toList();
    state = ChatMessagesState(
      loading: false,
      conversationId: result.conversationId,
      messages: messages,
      error: null,
      hasMoreOlder: result.messages.length >= _pageSize,
    );
    _cacheChatSnapshot();
  }

  /// Load older messages (pagination). Call when user scrolls up.
  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMoreOlder || state.messages.isEmpty) return;
    state = ChatMessagesState(
      conversationId: state.conversationId,
      messages: state.messages,
      loading: state.loading,
      error: state.error,
      sending: state.sending,
      loadingOlder: true,
      hasMoreOlder: state.hasMoreOlder,
    );
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = ChatMessagesState(
        conversationId: state.conversationId,
        messages: state.messages,
        loading: state.loading,
        error: state.error,
        sending: state.sending,
        loadingOlder: false,
        hasMoreOlder: state.hasMoreOlder,
      );
      return;
    }
    final peerUser = UserModel(id: _peerUserId, username: '', displayName: '', avatarUrl: '');
    final existingIds = state.messages.map((m) => m.id).toSet();
    final skip = state.messages.length;
    final result = await _service.getUserChat(_peerUserId, limit: _pageSize, skip: skip);
    if (!result.success) {
      state = ChatMessagesState(
        conversationId: state.conversationId,
        messages: state.messages,
        loading: state.loading,
        error: state.error,
        sending: state.sending,
        loadingOlder: false,
        hasMoreOlder: state.hasMoreOlder,
      );
      return;
    }
    final older = result.messages
        .map((b) => _messageFromBubble(b, currentUser.id, currentUser, peerUser))
        .where((m) => !existingIds.contains(m.id))
        .toList();
    // No more to load: API returned empty, or fewer than a page, or all were duplicates
    final noMoreOlder = result.messages.isEmpty ||
        result.messages.length < _pageSize ||
        older.isEmpty;
    state = ChatMessagesState(
      conversationId: state.conversationId ?? result.conversationId,
      messages: older.isEmpty ? state.messages : [...state.messages, ...older],
      loading: state.loading,
      error: state.error,
      sending: state.sending,
      loadingOlder: false,
      hasMoreOlder: !noMoreOlder,
    );
    _cacheChatSnapshot();
  }

  /// Call after load when we have peer user info (e.g. from conversation list) to set display name/avatar.
  void setPeerUser(UserModel peer) {
    if (peer.id != _peerUserId) return;
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;
    final updated = state.messages.map((m) {
      if (m.sender.id == _peerUserId) {
        return MessageModel(
          id: m.id,
          serverId: m.serverId,
          sender: peer,
          text: m.text,
          timestamp: m.timestamp,
          isRead: m.isRead,
          mediaUrl: m.mediaUrl,
          type: m.type,
          status: m.status,
        );
      }
      return m;
    }).toList();
    state = ChatMessagesState(
      conversationId: state.conversationId,
      messages: updated,
      loading: state.loading,
      error: state.error,
      sending: state.sending,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );
  }

  void _markOptimisticAsSent({
    required String localId,
    required ChatMessageBubble chat,
    required UserModel currentUser,
  }) {
    final peerUser =
        UserModel(id: _peerUserId, username: '', displayName: '', avatarUrl: '');
    final sent = _messageFromBubble(chat, currentUser.id, currentUser, peerUser);

    final idx = state.messages.indexWhere((m) => m.id == localId);
    if (idx < 0) return;

    final updated = List<MessageModel>.from(state.messages);
    updated[idx] = MessageModel(
      id: localId,
      serverId: chat.id,
      sender: sent.sender,
      text: sent.text,
      mediaUrl: sent.mediaUrl,
      timestamp: sent.timestamp,
      isRead: sent.isRead,
      type: sent.type,
      status: MessageSendStatus.sent,
    );
    state = ChatMessagesState(
      conversationId: state.conversationId ?? chat.conversationId,
      messages: updated,
      loading: state.loading,
      error: state.error,
      sending: false,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );
    _cacheChatSnapshot();
  }

  Future<bool> sendMessage(String text) async {
    final t = text.trim();
    if (t.isEmpty) return false;
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final payload = ShareLinkHelper.parse(t);
    final isShared = payload.contentId != null;
    final hasThumb =
        payload.thumbnailUrl != null && payload.thumbnailUrl!.isNotEmpty;

    final localId = 'pending-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: localId,
      sender: currentUser,
      text: isShared ? (hasThumb ? '' : 'Shared content') : t,
      timestamp: DateTime.now(),
      isRead: false,
      type: hasThumb ? MessageType.image : MessageType.text,
      mediaUrl: hasThumb ? payload.thumbnailUrl : null,
      status: MessageSendStatus.sending,
    );
    state = ChatMessagesState(
      conversationId: state.conversationId,
      messages: [...state.messages, optimistic],
      sending: true,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );

    final result = await _service.sendMessage(receiverId: _peerUserId, message: t);
    state = ChatMessagesState(
      conversationId: result.chat != null ? (state.conversationId ?? result.chat!.conversationId) : state.conversationId,
      messages: state.messages,
      sending: false,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );

    if (!result.success) {
      state = ChatMessagesState(
        conversationId: state.conversationId,
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        sending: false,
        error: result.errorMessage,
        loadingOlder: state.loadingOlder,
        hasMoreOlder: state.hasMoreOlder,
      );
      return false;
    }
    _markOptimisticAsSent(localId: localId, chat: result.chat!, currentUser: currentUser);
    return true;
  }

  /// Sends a post link as a chat "post" message (backend will attach `sharedPostData`).
  Future<bool> sendPostLink(String postLink) async {
    final link = postLink.trim();
    if (link.isEmpty) return false;
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final localId = 'pending-post-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: localId,
      sender: currentUser,
      text: 'Shared a post',
      timestamp: DateTime.now(),
      isRead: false,
      type: MessageType.text,
      status: MessageSendStatus.sending,
    );
    state = ChatMessagesState(
      conversationId: state.conversationId,
      messages: [...state.messages, optimistic],
      sending: true,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );

    final result = await _service.sendMessage(
      receiverId: _peerUserId,
      postLink: link,
      messageType: 'post',
    );

    state = ChatMessagesState(
      conversationId: result.chat != null
          ? (state.conversationId ?? result.chat!.conversationId)
          : state.conversationId,
      messages: state.messages,
      sending: false,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );

    if (!result.success || result.chat == null) {
      state = ChatMessagesState(
        conversationId: state.conversationId,
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        sending: false,
        error: result.errorMessage,
        loadingOlder: state.loadingOlder,
        hasMoreOlder: state.hasMoreOlder,
      );
      return false;
    }

    _markOptimisticAsSent(localId: localId, chat: result.chat!, currentUser: currentUser);
    return true;
  }

  Future<bool> sendMedia(String filePath, MessageType type) async {
    final p = filePath.trim();
    if (p.isEmpty) return false;
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final localId = 'pending-media-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: localId,
      sender: currentUser,
      text: '',
      timestamp: DateTime.now(),
      isRead: false,
      type: type,
      mediaUrl: p,
      status: MessageSendStatus.sending,
    );
    state = ChatMessagesState(
      conversationId: state.conversationId,
      messages: [...state.messages, optimistic],
      sending: true,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );

    final result = await _service.sendMessage(
      receiverId: _peerUserId,
      mediaFilePaths: [p],
      messageType: type == MessageType.video ? 'video' : 'image',
    );

    state = ChatMessagesState(
      conversationId: result.chat != null
          ? (state.conversationId ?? result.chat!.conversationId)
          : state.conversationId,
      messages: state.messages,
      sending: false,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );

    if (!result.success || result.chat == null) {
      state = ChatMessagesState(
        conversationId: state.conversationId,
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        sending: false,
        error: result.errorMessage,
        loadingOlder: state.loadingOlder,
        hasMoreOlder: state.hasMoreOlder,
      );
      return false;
    }

    _markOptimisticAsSent(localId: localId, chat: result.chat!, currentUser: currentUser);
    return true;
  }

  void appendFromSocket(Map<String, dynamic> data) {
    final id = (data['_id'] ?? data['id'] ?? data['messageId'] ?? 'socket-${DateTime.now().millisecondsSinceEpoch}').toString();
    final conversationId = data['conversationId']?.toString();
    if (state.messages.any((m) => m.id == id || m.serverId == id)) return;

    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;
    final senderId = data['senderId']?.toString() ?? data['sender_id']?.toString() ?? '';

    try {
      final bubble = ChatMessageBubble.fromJson(Map<String, dynamic>.from(data));
      final peerUser = UserModel(
        id: _peerUserId,
        username: bubble.sender?.username.isNotEmpty == true
            ? bubble.sender!.username
            : (data['senderName']?.toString() ?? data['username']?.toString() ?? ''),
        displayName: bubble.sender?.username.isNotEmpty == true
            ? bubble.sender!.username
            : (data['senderName']?.toString() ?? data['username']?.toString() ?? ''),
        avatarUrl: (bubble.sender?.profilePicture.isNotEmpty == true
                ? bubble.sender!.profilePicture
                : (bubble.senderProfilePicture.isNotEmpty
                    ? bubble.senderProfilePicture
                : (data['senderAvatar']?.toString() ?? data['profilePicture']?.toString() ?? ''))),
      );
      final msg = _messageFromBubble(bubble, currentUser.id, currentUser, peerUser);
      if (senderId == currentUser.id) {
        final idx = state.messages.indexWhere((m) =>
            m.sender.id == currentUser.id && _matchesPendingMessage(m, msg));
        if (idx >= 0) {
          final updated = List<MessageModel>.from(state.messages);
          updated[idx] = MessageModel(
            id: updated[idx].id,
            serverId: bubble.id,
            sender: msg.sender,
            text: msg.text,
            mediaUrl: msg.mediaUrl,
            timestamp: msg.timestamp,
            isRead: msg.isRead,
            type: msg.type,
            status: MessageSendStatus.sent,
          );
          state = ChatMessagesState(
            conversationId: state.conversationId ?? conversationId ?? state.conversationId,
            messages: updated,
            loading: state.loading,
            error: state.error,
            sending: state.sending,
            loadingOlder: state.loadingOlder,
            hasMoreOlder: state.hasMoreOlder,
          );
          _cacheChatSnapshot();
          return;
        }
      }
      state = ChatMessagesState(
        conversationId: state.conversationId ?? conversationId ?? state.conversationId,
        messages: [...state.messages, msg],
        loading: state.loading,
        error: state.error,
        sending: state.sending,
        loadingOlder: state.loadingOlder,
        hasMoreOlder: state.hasMoreOlder,
      );
      _cacheChatSnapshot();
    } catch (_) {
      final text = (data['message'] ?? data['text'] ?? data['content'] ?? '').toString();
      final payload = ShareLinkHelper.parse(text);
      final isShared = payload.contentId != null;
      final hasThumb =
          payload.thumbnailUrl != null && payload.thumbnailUrl!.isNotEmpty;

      final msg = MessageModel(
        id: id,
        sender: senderId == currentUser.id
            ? currentUser
            : UserModel(
                id: _peerUserId,
                username: '',
                displayName: '',
                avatarUrl: '',
              ),
        text: isShared ? (hasThumb ? '' : 'Shared content') : text.toString(),
        timestamp: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
        isRead: false,
        type: hasThumb ? MessageType.image : MessageType.text,
        mediaUrl: hasThumb ? payload.thumbnailUrl : null,
      );
      if (senderId == currentUser.id) {
        final idx = state.messages.indexWhere((m) =>
            m.sender.id == currentUser.id && _matchesPendingMessage(m, msg));
        if (idx >= 0) {
          final updated = List<MessageModel>.from(state.messages);
          updated[idx] = MessageModel(
            id: updated[idx].id,
            serverId: id,
            sender: msg.sender,
            text: msg.text,
            mediaUrl: msg.mediaUrl,
            timestamp: msg.timestamp,
            isRead: msg.isRead,
            type: msg.type,
            status: MessageSendStatus.sent,
          );
          state = ChatMessagesState(
            conversationId: state.conversationId ?? conversationId ?? state.conversationId,
            messages: updated,
            loading: state.loading,
            error: state.error,
            sending: state.sending,
            loadingOlder: state.loadingOlder,
            hasMoreOlder: state.hasMoreOlder,
          );
          _cacheChatSnapshot();
          return;
        }
      }
      state = ChatMessagesState(
        conversationId: state.conversationId ?? conversationId ?? state.conversationId,
        messages: [...state.messages, msg],
        loading: state.loading,
        error: state.error,
        sending: state.sending,
        loadingOlder: state.loadingOlder,
        hasMoreOlder: state.hasMoreOlder,
      );
      _cacheChatSnapshot();
    }
  }

  /// Apply a delete-for-everyone socket event to the open chat.
  /// Server payload is normalized by `ChatSocketService` and should include `messageId` (or `_id`).
  void removeFromSocket(Map<String, dynamic> data) {
    final id = (data['messageId'] ?? data['_id'] ?? data['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (state.messages.isEmpty) return;
    if (!state.messages.any((m) => m.id == id || m.serverId == id)) return;
    state = ChatMessagesState(
      conversationId: state.conversationId,
      messages: state.messages.where((m) => m.id != id && m.serverId != id).toList(),
      loading: state.loading,
      error: state.error,
      sending: state.sending,
      loadingOlder: state.loadingOlder,
      hasMoreOlder: state.hasMoreOlder,
    );
    _cacheChatSnapshot();
  }

  void _cacheChatSnapshot() {
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheLastMessagesForChat(
        _peerUserId,
        state.messages,
      );
    });
  }
}

final chatMessagesProvider =
    StateNotifierProvider.family<ChatMessagesNotifier, ChatMessagesState, String>((ref, peerUserId) {
  return ChatMessagesNotifier(peerUserId, ref);
});

// --- Chat composer (per peer) ---

class ChatComposerState {
  final bool resolvingPost;
  final Map<String, dynamic>? resolvedPostPreview;
  final String lastResolvedInput;

  const ChatComposerState({
    this.resolvingPost = false,
    this.resolvedPostPreview,
    this.lastResolvedInput = '',
  });
}

class ChatComposerNotifier extends StateNotifier<ChatComposerState> {
  ChatComposerNotifier() : super(const ChatComposerState());

  void clearPreview() {
    if (!state.resolvingPost &&
        state.resolvedPostPreview == null &&
        state.lastResolvedInput.isEmpty) return;
    state = const ChatComposerState();
  }

  void setResolving(String input) {
    final t = input.trim();
    state = ChatComposerState(
      resolvingPost: true,
      resolvedPostPreview: state.resolvedPostPreview,
      lastResolvedInput: t,
    );
  }

  void setResolved(String input, Map<String, dynamic>? preview) {
    state = ChatComposerState(
      resolvingPost: false,
      resolvedPostPreview: preview,
      lastResolvedInput: input.trim(),
    );
  }
}

final chatComposerProvider = StateNotifierProvider.autoDispose
    .family<ChatComposerNotifier, ChatComposerState, String>((ref, peerUserId) {
  return ChatComposerNotifier();
});

// --- Group chat messages (by groupId) ---

class GroupChatState {
  final String conversationId;
  final List<MessageModel> messages;
  final bool loading;
  final String? error;
  final bool sending;

  const GroupChatState({
    this.conversationId = '',
    this.messages = const [],
    this.loading = false,
    this.error,
    this.sending = false,
  });
}

class GroupChatNotifier extends StateNotifier<GroupChatState> {
  GroupChatNotifier(this._groupId, this._ref) : super(const GroupChatState());

  final String _groupId;
  final Ref _ref;

  ChatService get _service => _ref.read(chatServiceProvider);

  String get roomId => 'group:$_groupId';

  void _markOptimisticAsSent({
    required String localId,
    required ChatMessageBubble chat,
    required UserModel currentUser,
  }) {
    final senderFallback = UserModel(
      id: chat.senderId,
      username: currentUser.username,
      displayName: currentUser.displayName,
      avatarUrl: currentUser.avatarUrl,
    );
    final sent = _messageFromBubble(chat, currentUser.id, currentUser, senderFallback);
    final idx = state.messages.indexWhere((m) => m.id == localId);
    if (idx < 0) return;

    final updated = List<MessageModel>.from(state.messages);
    updated[idx] = MessageModel(
      id: localId,
      serverId: chat.id,
      sender: sent.sender,
      text: sent.text,
      mediaUrl: sent.mediaUrl,
      timestamp: sent.timestamp,
      isRead: sent.isRead,
      type: sent.type,
      status: MessageSendStatus.sent,
    );
    state = GroupChatState(
      conversationId: state.conversationId.isNotEmpty ? state.conversationId : chat.conversationId,
      messages: updated,
      loading: state.loading,
      error: null,
      sending: false,
    );
  }

  Future<void> load({int limit = 50, int skip = 0}) async {
    if (_groupId.trim().isEmpty) {
      state = const GroupChatState(loading: false, error: 'Missing group id');
      return;
    }
    state = GroupChatState(
      conversationId: state.conversationId.isNotEmpty ? state.conversationId : roomId,
      messages: state.messages,
      loading: true,
      error: null,
      sending: state.sending,
    );
    final res = await _service.getGroupMessages(_groupId, limit: limit, skip: skip);
    final currentUser = _ref.read(currentUserProvider);
    if (!res.success || currentUser == null) {
      state = GroupChatState(
        conversationId: state.conversationId.isNotEmpty ? state.conversationId : roomId,
        messages: state.messages,
        loading: false,
        error: res.errorMessage ?? 'Failed to load messages',
        sending: state.sending,
      );
      return;
    }

    final data = res.data ?? const <String, dynamic>{};
    final convId = (data['conversationId'] ?? data['conversation_id'] ?? roomId).toString();
    final list = data['messages'];
    final out = <MessageModel>[];
    if (list is List) {
      for (final e in list) {
        final m = e is Map<String, dynamic>
            ? e
            : (e is Map ? Map<String, dynamic>.from(e) : null);
        if (m == null) continue;
        final bubble = ChatMessageBubble.fromJson(m);
        final senderFallback = UserModel(
          id: bubble.senderId,
          username: bubble.sender?.username ?? '',
          displayName: bubble.sender?.username ?? '',
          avatarUrl: bubble.sender?.profilePicture ?? bubble.senderProfilePicture,
        );
        out.add(_messageFromBubble(bubble, currentUser.id, currentUser, senderFallback));
      }
    }

    state = GroupChatState(
      conversationId: convId,
      messages: out,
      loading: false,
      error: null,
      sending: false,
    );
  }

  Future<bool> sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return false;
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final localId = 'pending-group-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: localId,
      sender: currentUser,
      text: t,
      timestamp: DateTime.now(),
      isRead: false,
      type: MessageType.text,
      status: MessageSendStatus.sending,
    );
    state = GroupChatState(
      conversationId: state.conversationId.isNotEmpty ? state.conversationId : roomId,
      messages: [...state.messages, optimistic],
      loading: state.loading,
      error: null,
      sending: true,
    );

    final result = await _service.sendMessage(
      groupId: _groupId,
      message: t,
    );

    state = GroupChatState(
      conversationId: result.chat != null
          ? (state.conversationId.isNotEmpty ? state.conversationId : result.chat!.conversationId)
          : state.conversationId,
      messages: state.messages,
      loading: state.loading,
      error: state.error,
      sending: false,
    );

    if (!result.success || result.chat == null) {
      state = GroupChatState(
        conversationId: state.conversationId,
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        loading: state.loading,
        error: result.errorMessage,
        sending: false,
      );
      return false;
    }

    _markOptimisticAsSent(localId: localId, chat: result.chat!, currentUser: currentUser);
    return true;
  }

  Future<bool> sendMedia(String filePath, MessageType type) async {
    final p = filePath.trim();
    if (p.isEmpty) return false;
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return false;

    final localId = 'pending-group-media-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: localId,
      sender: currentUser,
      text: '',
      timestamp: DateTime.now(),
      isRead: false,
      type: type,
      mediaUrl: p,
      status: MessageSendStatus.sending,
    );
    state = GroupChatState(
      conversationId: state.conversationId.isNotEmpty ? state.conversationId : roomId,
      messages: [...state.messages, optimistic],
      loading: state.loading,
      error: null,
      sending: true,
    );

    final result = await _service.sendMessage(
      groupId: _groupId,
      mediaFilePaths: [p],
      messageType: type == MessageType.video ? 'video' : 'image',
    );

    state = GroupChatState(
      conversationId: result.chat != null
          ? (state.conversationId.isNotEmpty ? state.conversationId : result.chat!.conversationId)
          : state.conversationId,
      messages: state.messages,
      loading: state.loading,
      error: state.error,
      sending: false,
    );

    if (!result.success || result.chat == null) {
      state = GroupChatState(
        conversationId: state.conversationId,
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        loading: state.loading,
        error: result.errorMessage,
        sending: false,
      );
      return false;
    }

    _markOptimisticAsSent(localId: localId, chat: result.chat!, currentUser: currentUser);
    return true;
  }

  void appendFromSocket(Map<String, dynamic> data) {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;
    final id = (data['_id'] ?? data['id'] ?? data['messageId'] ?? '').toString();
    if (id.isEmpty) return;
    if (state.messages.any((m) => m.id == id || m.serverId == id)) return;
    final senderId = data['senderId']?.toString() ?? data['sender_id']?.toString() ?? '';
    final bubble = ChatMessageBubble.fromJson(Map<String, dynamic>.from(data));
    final senderFallback = UserModel(
      id: bubble.senderId,
      username: bubble.sender?.username ?? '',
      displayName: bubble.sender?.username ?? '',
      avatarUrl: bubble.sender?.profilePicture ?? bubble.senderProfilePicture,
    );
    final msg = _messageFromBubble(bubble, currentUser.id, currentUser, senderFallback);
    if (senderId == currentUser.id) {
      final idx = state.messages.indexWhere((m) =>
          m.sender.id == currentUser.id && _matchesPendingMessage(m, msg));
      if (idx >= 0) {
        final updated = List<MessageModel>.from(state.messages);
        updated[idx] = MessageModel(
          id: updated[idx].id,
          serverId: bubble.id,
          sender: msg.sender,
          text: msg.text,
          mediaUrl: msg.mediaUrl,
          timestamp: msg.timestamp,
          isRead: msg.isRead,
          type: msg.type,
          status: MessageSendStatus.sent,
        );
        state = GroupChatState(
          conversationId: state.conversationId.isNotEmpty ? state.conversationId : roomId,
          messages: updated,
          loading: state.loading,
          error: state.error,
          sending: state.sending,
        );
        return;
      }
    }
    state = GroupChatState(
      conversationId: state.conversationId.isNotEmpty ? state.conversationId : roomId,
      messages: [...state.messages, msg],
      loading: state.loading,
      error: state.error,
      sending: state.sending,
    );
  }

  void removeFromSocket(Map<String, dynamic> data) {
    final id = (data['messageId'] ?? data['_id'] ?? data['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (!state.messages.any((m) => m.id == id || m.serverId == id)) return;
    state = GroupChatState(
      conversationId: state.conversationId,
      messages: state.messages.where((m) => m.id != id && m.serverId != id).toList(),
      loading: state.loading,
      error: state.error,
      sending: state.sending,
    );
  }
}

final groupChatProvider =
    StateNotifierProvider.family<GroupChatNotifier, GroupChatState, String>((ref, groupId) {
  return GroupChatNotifier(groupId, ref);
});
