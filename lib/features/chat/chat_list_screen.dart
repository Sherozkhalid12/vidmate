import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/chat_conversation_model.dart';
import '../../core/models/chat_conversation_api.dart';
import '../../core/models/message_model.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/chat_provider_riverpod.dart';
import '../../core/providers/socket_provider_riverpod.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import '../../services/chat/chat_service.dart';

/// Chat list screen: loads conversations from API via Riverpod.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socketConnectionProvider.notifier).ensureConnection();
    });
  }

  ChatConversationModel _itemToConversation(
    ChatConversationItem item,
    Set<String> unreadConversationIds,
  ) {
    final isGroup = item.isGroup;
    final groupId = item.group?.id.isNotEmpty == true
        ? item.group!.id
        : (item.conversationId.startsWith('group:')
            ? item.conversationId.split(':').last
            : '');
    // Always choose a stable, non-empty identifier for navigation.
    final stableId = isGroup
        ? (groupId.isNotEmpty ? groupId : item.conversationId)
        : item.user.id;
    final title = isGroup
        ? ((item.group?.name ?? '').isNotEmpty ? item.group!.name : 'Group')
        : item.user.username;
    final avatar = isGroup ? (item.group?.avatarUrl ?? '') : item.user.profilePicture;
    final user = UserModel(
      id: stableId,
      username: title,
      displayName: title,
      avatarUrl: avatar,
    );
    final lastMessage = MessageModel(
      id: '',
      sender: user,
      text: item.lastMessage,
      timestamp: item.lastMessageAt,
      type: MessageType.text,
    );
    final hasUnread = unreadConversationIds.contains(item.conversationId);
    return ChatConversationModel(
      id: stableId,
      conversationId: item.conversationId,
      user: user,
      isGroup: isGroup,
      groupName: isGroup ? title : null,
      groupAvatar: isGroup ? avatar : null,
      lastMessage: lastMessage,
      lastMessageTime: item.lastMessageAt,
      unreadCount: hasUnread ? 1 : 0,
      isOnline: false,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  (Color, Color) _shimmerColors(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return (base, base.withValues(alpha: 0.35));
  }

  Widget _buildConversationSkeletonTile(BuildContext context) {
    final (base, hi) = _shimmerColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: hi,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    final conversations = state.conversations
        .map((item) => _itemToConversation(item, state.unreadConversationIds))
        .toList();
    final showSkeleton =
        !state.initialFetchCompleted && conversations.isEmpty;
    final isEmpty = conversations.isEmpty &&
        !state.loading &&
        state.initialFetchCompleted;
    final error = state.error;

    return Material(
      color: ThemeHelper.getBackgroundColor(context),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Messages',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
              actionsIconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Search conversations feature coming soon',
                          style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                        ),
                        backgroundColor: ThemeHelper.getSurfaceColor(context),
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_circle_outline),
                  onSelected: (value) {
                    if (value == 'one_to_one') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Select a user to start chatting',
                            style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                          ),
                          backgroundColor: ThemeHelper.getSurfaceColor(context),
                        ),
                      );
                    } else if (value == 'group') {
                      _openCreateGroupSheet();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'one_to_one',
                      child: Row(
                        children: [
                          Icon(Icons.person_add),
                          SizedBox(width: 8),
                          Text('New Chat'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'group',
                      child: Row(
                        children: [
                          Icon(Icons.group_add),
                          SizedBox(width: 8),
                          Text('New Group'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: showSkeleton
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: 8,
                      itemBuilder: (context, index) =>
                          _buildConversationSkeletonTile(context),
                    )
                  : error != null && conversations.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ThemeHelper.getTextMuted(context)),
                            ),
                          ),
                        )
                      : isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: ThemeHelper.getTextMuted(context),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      color: ThemeHelper.getTextMuted(context),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : AnimationLimiter(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: conversations.length,
                                itemBuilder: (context, index) {
                                  return AnimationConfiguration.staggeredList(
                                    position: index,
                                    duration: const Duration(milliseconds: 375),
                                    child: SlideAnimation(
                                      verticalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: _buildConversationItem(conversations[index]),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String url) {
    if (url.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(
          Icons.person,
          color: ThemeHelper.getTextSecondary(context),
          size: 30,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        width: 60,
        height: 60,
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context), size: 30),
      ),
      errorWidget: (_, __, ___) => Container(
        width: 60,
        height: 60,
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context), size: 30),
      ),
    );
  }

  Widget _buildConversationItem(ChatConversationModel conversation) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        ref.read(conversationsProvider.notifier).markConversationAsRead(conversation.conversationId ?? '');
        if (conversation.isGroup) {
          final rawId = conversation.id;
          final groupId =
              rawId.startsWith('group:') ? rawId.split(':').last.trim() : rawId.trim();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupChatScreen(
                groupId: groupId,
                groupName: conversation.groupName ?? 'Group',
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                user: conversation.user,
                conversationId: conversation.conversationId,
              ),
            ),
          );
        }
      },
      child: Row(
        children: [
          Stack(
            children: [
              ClipOval(
                child: _buildAvatar(conversation.user.avatarUrl),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.user.displayName.isNotEmpty
                            ? conversation.user.displayName
                            : conversation.user.username,
                        style: TextStyle(
                          color: conversation.unreadCount > 0
                              ? ThemeHelper.getTextPrimary(context)
                              : ThemeHelper.getTextSecondary(context),
                          fontSize: 16,
                          fontWeight: conversation.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (conversation.unreadCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: ThemeHelper.getOnAccentColor(context),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ThemeHelper.getSurfaceColor(context),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          _formatTime(conversation.lastMessageTime),
                          style: TextStyle(
                            color: ThemeHelper.getTextMuted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.lastMessage.text.isEmpty
                            ? conversation.lastMessage.type == MessageType.image
                                ? '📷 Photo'
                                : conversation.lastMessage.type == MessageType.video
                                    ? '🎥 Video'
                                    : 'Media'
                            : conversation.lastMessage.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: conversation.unreadCount > 0
                              ? ThemeHelper.getTextPrimary(context)
                              : ThemeHelper.getTextMuted(context),
                          fontSize: 14,
                          fontWeight: conversation.unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (conversation.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getAccentColor(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : conversation.unreadCount.toString(),
                          style: TextStyle(
                            color: ThemeHelper.getOnAccentColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateGroupSheet() async {
    final service = ChatService();
    final res = await service.getShareableUsers();
    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Failed to load users')),
      );
      return;
    }
    final users = res.data ?? const <Map<String, dynamic>>[];
    final selected = <String>{};
    final nameCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeHelper.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ThemeHelper.getTextMuted(ctx).withAlpha(60),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'New group',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(ctx),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Group name',
                        filled: true,
                        fillColor: ThemeHelper.getBackgroundColor(ctx).withAlpha(90),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: ThemeHelper.getBorderColor(ctx).withAlpha(70),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (ctx, i) {
                          final u = users[i];
                          final id = (u['id'] ?? u['_id'] ?? '').toString();
                          final uname = (u['username'] ?? u['name'] ?? u['displayName'] ?? 'User').toString();
                          final avatar = (u['profilePicture'] ?? u['avatarUrl'] ?? u['image'] ?? '').toString();
                          final isOn = selected.contains(id);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: ThemeHelper.getSurfaceColor(ctx),
                              backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                              child: avatar.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            title: Text(
                              uname,
                              style: TextStyle(color: ThemeHelper.getTextPrimary(ctx)),
                            ),
                            trailing: Checkbox(
                              value: isOn,
                              onChanged: id.isEmpty
                                  ? null
                                  : (v) => setModal(() {
                                        if (v == true) {
                                          selected.add(id);
                                        } else {
                                          selected.remove(id);
                                        }
                                      }),
                            ),
                            onTap: id.isEmpty
                                ? null
                                : () => setModal(() {
                                      if (selected.contains(id)) {
                                        selected.remove(id);
                                      } else {
                                        selected.add(id);
                                      }
                                    }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: selected.isEmpty || nameCtrl.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeHelper.getAccentColor(ctx),
                          foregroundColor: ThemeHelper.getOnAccentColor(ctx),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final groupName = nameCtrl.text.trim();
    if (groupName.isEmpty || selected.isEmpty) return;

    final create = await service.createGroup(name: groupName, participantIds: selected.toList());
    if (!mounted) return;
    if (!create.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(create.errorMessage ?? 'Failed to create group')),
      );
      return;
    }
    final data = create.data ?? const <String, dynamic>{};
    final group = data['group'] is Map<String, dynamic>
        ? data['group'] as Map<String, dynamic>
        : (data['group'] is Map ? Map<String, dynamic>.from(data['group'] as Map) : <String, dynamic>{});
    final groupId = (group['_id'] ?? group['id'] ?? data['groupId'] ?? '').toString();
    final name = (group['name'] ?? groupName).toString();
    if (groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created, but missing group id')),
      );
      return;
    }

    // Refresh list so it appears immediately
    ref.read(conversationsProvider.notifier).load();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(groupId: groupId, groupName: name),
      ),
    );
  }
}
