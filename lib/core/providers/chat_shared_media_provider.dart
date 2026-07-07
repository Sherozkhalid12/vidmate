import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_bubble.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../../features/chat/utils/chat_message_filters.dart';
import 'auth_provider_riverpod.dart';
import 'chat_provider_riverpod.dart';

class ChatSharedMediaKey {
  final String? peerUserId;
  final String? groupId;

  const ChatSharedMediaKey({this.peerUserId, this.groupId});

  @override
  bool operator ==(Object other) =>
      other is ChatSharedMediaKey &&
      other.peerUserId == peerUserId &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(peerUserId, groupId);
}

class ChatSharedMediaState {
  final List<MessageModel> messages;
  final bool loading;
  final String? error;

  const ChatSharedMediaState({
    this.messages = const [],
    this.loading = false,
    this.error,
  });

  List<MessageModel> get photosAndVideos =>
      messages.where(ChatMessageFilters.isPhotoOrVideo).toList();

  List<MessageModel> get reelsAndLongVideos =>
      messages.where(ChatMessageFilters.isReelOrLongVideo).toList();

  List<MessageModel> get linksAndFiles =>
      messages.where(ChatMessageFilters.isLinkOrFile).toList();
}

class ChatSharedMediaNotifier extends StateNotifier<ChatSharedMediaState> {
  ChatSharedMediaNotifier(this._key, this._ref)
      : super(const ChatSharedMediaState(loading: true)) {
    _load();
  }

  final ChatSharedMediaKey _key;
  final Ref _ref;

  Future<void> _load() async {
    state = const ChatSharedMediaState(loading: true);
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = const ChatSharedMediaState(error: 'Not signed in');
      return;
    }

    final groupId = _key.groupId?.trim() ?? '';
    final peerId = _key.peerUserId?.trim() ?? '';

    try {
      if (groupId.isNotEmpty) {
        final res = await _ref.read(chatServiceProvider).getGroupMessages(
              groupId,
              limit: 100,
              skip: 0,
            );
        if (!res.success) {
          state = ChatSharedMediaState(error: res.errorMessage ?? 'Failed to load');
          return;
        }
        final data = res.data ?? const <String, dynamic>{};
        final list = data['messages'];
        state = ChatSharedMediaState(
          messages: _messagesFromRawList(list, currentUser, peerUser: null),
        );
        return;
      }

      if (peerId.isNotEmpty) {
        final res = await _ref.read(chatServiceProvider).getUserChat(
              peerId,
              limit: 100,
              skip: 0,
            );
        if (!res.success) {
          state = ChatSharedMediaState(error: res.errorMessage ?? 'Failed to load');
          return;
        }
        final peer = UserModel(id: peerId, username: '', displayName: '', avatarUrl: '');
        state = ChatSharedMediaState(
          messages: res.messages
              .map((b) => messageModelFromChatBubble(b, currentUser, peer))
              .toList(),
        );
        return;
      }

      state = const ChatSharedMediaState(error: 'Missing conversation target');
    } catch (e) {
      state = ChatSharedMediaState(error: e.toString());
    }
  }

  List<MessageModel> _messagesFromRawList(
    dynamic list,
    UserModel currentUser, {
    UserModel? peerUser,
  }) {
    if (list is! List) return const [];
    final out = <MessageModel>[];
    for (final e in list) {
      final m = e is Map<String, dynamic>
          ? e
          : (e is Map ? Map<String, dynamic>.from(e) : null);
      if (m == null) continue;
      final bubble = ChatMessageBubble.fromJson(m);
      final fallback = UserModel(
        id: bubble.senderId,
        username: bubble.sender?.username ?? '',
        displayName: bubble.sender?.username ?? '',
        avatarUrl: bubble.sender?.profilePicture ?? bubble.senderProfilePicture,
      );
      out.add(messageModelFromChatBubble(bubble, currentUser, peerUser ?? fallback));
    }
    return out;
  }

  void refresh() => _load();
}

final chatSharedMediaProvider = StateNotifierProvider.autoDispose
    .family<ChatSharedMediaNotifier, ChatSharedMediaState, ChatSharedMediaKey>(
  (ref, key) => ChatSharedMediaNotifier(key, ref),
);
