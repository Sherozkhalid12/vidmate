import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/models/message_model.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/chat_provider_riverpod.dart';
import '../../core/providers/chat_settings_provider.dart';
import '../../core/providers/socket_instance_provider_riverpod.dart';
import '../../core/providers/socket_provider_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/ios_back_button.dart';
import '../../services/chat/chat_service.dart';
import 'profile/group_profile_screen.dart';
import 'utils/chat_media_actions.dart';
import 'utils/chat_message_grouper.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_media_group_bubble.dart';
import 'widgets/chat_message_bubble_widget.dart';
import 'widgets/chat_screen_background.dart';

/// Group chat screen with shared DM-quality bubbles, media, input, and theming.
class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupAvatar;
  final List<Map<String, dynamic>> members;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatar,
    this.members = const [],
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadingOlderInProgress = false;
  double _maxScrollExtentBeforeLoadOlder = 0;

  String get _normalizedGroupId {
    final id = widget.groupId.trim();
    if (id.isEmpty) return '';
    if (id.startsWith('group:')) return id.split(':').last.trim();
    return id;
  }

  String get _roomId => 'group:$_normalizedGroupId';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_normalizedGroupId.isEmpty) {
        await ref.read(groupChatProvider(_normalizedGroupId).notifier).load();
        return;
      }
      await ref.read(socketConnectionProvider.notifier).ensureConnection();
      if (!mounted) return;
      ref.read(currentConversationIdProvider.notifier).state = _roomId;
      ref.read(socketServiceProvider).chatSocket.join(_roomId);
      if (kDebugMode) debugPrint('[GroupChat] join room=$_roomId');
      await ref.read(groupChatProvider(_normalizedGroupId).notifier).load();
      if (!mounted) return;
      _scrollToEnd();
    });
  }

  @override
  void dispose() {
    try {
      ref.read(socketServiceProvider).chatSocket.leave(_roomId);
    } catch (_) {}
    if (ref.read(currentConversationIdProvider) == _roomId) {
      Future.microtask(() {
        ref.read(currentConversationIdProvider.notifier).state = null;
      });
    }
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= 80;
  }

  (Color, Color) _shimmerColors(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return (base, base.withValues(alpha: 0.35));
  }

  Widget _buildChatMessagesSkeleton(BuildContext context) {
    final (base, hi) = _shimmerColors(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(8, (i) {
        final alignRight = i % 3 == 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: hi,
            child: Row(
              mainAxisAlignment:
                  alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!alignRight) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    height: i % 4 == 0 ? 72 : 52,
                    margin: EdgeInsets.only(
                      left: alignRight ? 56 : 0,
                      right: alignRight ? 0 : 36,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOlderMessagesShimmer(BuildContext context) {
    final (base, hi) = _shimmerColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: hi,
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onScroll() {
    final groupId = _normalizedGroupId;
    if (groupId.isEmpty || _loadingOlderInProgress) return;
    final state = ref.read(groupChatProvider(groupId));
    if (state.loadingOlder || !state.hasMoreOlder || state.messages.isEmpty) {
      return;
    }
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      _loadingOlderInProgress = true;
      _maxScrollExtentBeforeLoadOlder = pos.maxScrollExtent;
      ref.read(groupChatProvider(groupId).notifier).loadOlder().whenComplete(() {
        _loadingOlderInProgress = false;
      }).then((_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            final newMax = _scrollController.position.maxScrollExtent;
            final delta = newMax - _maxScrollExtentBeforeLoadOlder;
            if (delta > 0) {
              _scrollController.jumpTo(_scrollController.position.pixels + delta);
            }
          });
        });
      });
    }
  }

  Future<void> _sendText() async {
    final groupId = _normalizedGroupId;
    if (groupId.isEmpty) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await ref.read(groupChatProvider(groupId).notifier).sendText(text);
    _scrollToEnd();
  }

  Future<void> _sendMedia(String path, MessageType type) async {
    final groupId = _normalizedGroupId;
    if (groupId.isEmpty || path.trim().isEmpty) return;
    await ref.read(groupChatProvider(groupId).notifier).sendMedia(path.trim(), type);
    _scrollToEnd();
  }

  Widget _buildRow(ChatRenderRow row, double maxBubbleWidth) {
    if (row is MediaGroupRow) {
      final me = ref.watch(currentUserProvider);
      final anchor = row.anchor;
      final isMe = me != null && row.senderId == me.id;
      final fallbackName = anchor.sender.displayName.isNotEmpty
          ? anchor.sender.displayName
          : (anchor.sender.username.isNotEmpty ? anchor.sender.username : 'Member');
      final senderName = ref.read(groupSettingsProvider.notifier).displayNameFor(
            groupId: _normalizedGroupId,
            userId: anchor.sender.id,
            fallbackName: fallbackName,
          );
      return ChatMediaGroupBubble(
        row: row,
        isMe: isMe,
        showSenderName: !isMe,
        senderDisplayName: senderName,
        maxBubbleWidth: maxBubbleWidth,
        onLongPress: () => _showMessageActions(anchor, isMe: isMe),
      );
    }
    return _buildMessageBubble((row as MessageRow).message, maxBubbleWidth);
  }

  Widget _buildMessageBubble(MessageModel message, double maxBubbleWidth) {
    final me = ref.watch(currentUserProvider);
    final isMe = me != null && message.sender.id == me.id;
    final fallbackName = message.sender.displayName.isNotEmpty
        ? message.sender.displayName
        : (message.sender.username.isNotEmpty ? message.sender.username : 'Member');
    final senderName = ref.read(groupSettingsProvider.notifier).displayNameFor(
          groupId: _normalizedGroupId,
          userId: message.sender.id,
          fallbackName: fallbackName,
        );

    return ChatMessageBubbleWidget(
      message: message,
      isMe: isMe,
      showSenderName: !isMe,
      senderDisplayName: senderName,
      maxBubbleWidth: maxBubbleWidth,
      onLongPress: () => _showMessageActions(message, isMe: isMe),
    );
  }

  Future<void> _showMessageActions(MessageModel message, {required bool isMe}) async {
    final id = message.serverId ?? message.id;
    if (id.isEmpty || id.startsWith('pending-')) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ThemeHelper.getSecondaryBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeHelper.getTextMuted(ctx).withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  Icons.forward_to_inbox_outlined,
                  color: ThemeHelper.getTextPrimary(ctx),
                ),
                title: Text(
                  'Forward',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(ctx),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _forwardMessage(messageId: id);
                },
              ),
              if (isMe)
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: ThemeHelper.getAccentColor(ctx),
                  ),
                  title: Text(
                    'Delete for everyone',
                    style: TextStyle(
                      color: ThemeHelper.getAccentColor(ctx),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ChatService().deleteMessage(
                      messageId: id,
                      deleteForEveryone: true,
                    );
                    ref
                        .read(groupChatProvider(_normalizedGroupId).notifier)
                        .removeFromSocket({'messageId': id});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _forwardMessage({required String messageId}) async {
    final res = await ChatService().getShareableUsers();
    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Failed to load users')),
      );
      return;
    }
    final users = res.data ?? const <Map<String, dynamic>>[];
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: ThemeHelper.getSecondaryBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: users.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: ThemeHelper.getBorderColor(ctx).withValues(alpha: 0.2),
          ),
          itemBuilder: (ctx, i) {
            final user = users[i];
            final id = (user['id'] ?? user['_id'] ?? '').toString();
            final name =
                (user['username'] ?? user['name'] ?? user['displayName'] ?? 'User')
                    .toString();
            final avatar =
                (user['profilePicture'] ?? user['avatarUrl'] ?? user['image'] ?? '')
                    .toString();
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: ThemeHelper.getSurfaceColor(ctx),
                backgroundImage:
                    avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(
                name,
                style: TextStyle(color: ThemeHelper.getTextPrimary(ctx)),
              ),
              onTap: id.isEmpty ? null : () => Navigator.pop(ctx, user),
            );
          },
        ),
      ),
    );

    if (selected == null) return;
    final receiverId = (selected['id'] ?? selected['_id'] ?? '').toString();
    if (receiverId.isEmpty) return;
    final result = await ChatService().forwardMessage(
      messageId: messageId,
      receiverId: receiverId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Forwarded'
            : (result.errorMessage ?? 'Forward failed')),
      ),
    );
  }

  void _openMediaSheet() {
    ChatMediaActions.showAttachmentPicker(
      context,
      onGallery: _pickFromGallery,
      onCamera: () => ChatMediaActions.showCameraSheet(
        context,
        onPhoto: _capturePhoto,
        onVideo: _captureVideo,
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final files = await ChatMediaActions.pickFromGallery();
    if (!mounted || files.isEmpty) return;
    for (final file in files) {
      unawaited(_sendMedia(file.path, file.type));
    }
  }

  Future<void> _capturePhoto() async {
    final file = await ChatMediaActions.capturePhoto();
    if (!mounted || file == null) return;
    await _sendMedia(file.path, file.type);
  }

  Future<void> _captureVideo() async {
    final file = await ChatMediaActions.captureVideo();
    if (!mounted || file == null) return;
    await _sendMedia(file.path, file.type);
  }

  List<Map<String, dynamic>> _membersFromMessages(List<MessageModel> messages) {
    final members = <String, Map<String, dynamic>>{};
    for (final message in messages) {
      final sender = message.sender;
      if (sender.id.isEmpty || members.containsKey(sender.id)) continue;
      members[sender.id] = {
        'id': sender.id,
        'username': sender.username,
        'displayName': sender.displayName,
        'avatarUrl': sender.avatarUrl,
      };
    }
    return [...widget.members, ...members.values];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(groupChatProvider(_normalizedGroupId));
    final messages = state.messages;
    final rows = ChatMessageGrouper.group(messages);
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;

    ref.listen<GroupChatState>(groupChatProvider(_normalizedGroupId), (prev, next) {
      if (prev == null) return;
      if (next.messages.length != prev.messages.length && _isNearBottom) {
        _scrollToEnd();
      }
    });

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor:
            ThemeHelper.getSurfaceColor(context).withValues(alpha: isDark ? 0.4 : 0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
        leading: const IosBackButton(),
        titleSpacing: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupProfileScreen(
                      groupId: _normalizedGroupId,
                      groupName: widget.groupName,
                      groupAvatar: widget.groupAvatar,
                      members: _membersFromMessages(messages),
                    ),
                  ),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: ThemeHelper.getAccentGradient(context),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: (widget.groupAvatar ?? '').isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.groupAvatar!,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: ThemeHelper.getSurfaceColor(context),
                          child: Icon(
                            Icons.groups_rounded,
                            color: ThemeHelper.getAccentColor(context),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupProfileScreen(
                        groupId: _normalizedGroupId,
                        groupName: widget.groupName,
                        groupAvatar: widget.groupAvatar,
                        members: _membersFromMessages(messages),
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Tap for group profile',
                      style: TextStyle(
                        color: ThemeHelper.getTextMuted(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: ChatScreenBackground(
        conversationId: _roomId,
        child: Column(
          children: [
            Expanded(
              child: state.loading && messages.isEmpty
                  ? _buildChatMessagesSkeleton(context)
                  : state.error != null && messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              state.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ThemeHelper.getTextMuted(context)),
                            ),
                          ),
                        )
                      : AnimationLimiter(
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: rows.length + (state.loadingOlder ? 1 : 0),
                            itemBuilder: (ctx, index) {
                              if (state.loadingOlder && index == rows.length) {
                                return _buildOlderMessagesShimmer(context);
                              }
                              final row = rows[rows.length - 1 - index];
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 320),
                                child: SlideAnimation(
                                  verticalOffset: 36,
                                  child: FadeInAnimation(
                                    child: _buildRow(row, maxBubbleWidth),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
            ChatInputBar(
              controller: _messageController,
              composerKey: _roomId,
              sending: state.sending,
              hintText: 'Message group...',
              onSend: _sendText,
              onAttach: _openMediaSheet,
            ),
          ],
        ),
      ),
    );
  }
}
