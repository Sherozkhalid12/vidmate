import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/user_model.dart';
import '../../core/models/message_model.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/socket_provider_riverpod.dart';
import '../../core/providers/socket_instance_provider_riverpod.dart';
import '../../core/providers/chat_provider_riverpod.dart';
import '../../core/providers/calls_provider_riverpod.dart';
import '../../services/chat/chat_service.dart';
import 'dart:async';

/// Messenger-style chat screen. Uses chat API + socket; Riverpod for state.
/// Joins socket room when conversationId is available; leaves on dispose.
class ChatScreen extends ConsumerStatefulWidget {
  final UserModel? user;
  final String? conversationId;

  const ChatScreen({
    super.key,
    this.user,
    this.conversationId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _currentConversationId;
  dynamic _socketService;
  dynamic _chatPeerNotifier;
  dynamic _convIdNotifier;
  double _maxScrollExtentBeforeLoadOlder = 0;
  bool _loadingOlderInProgress = false;
  Timer? _resolveDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final peerId = widget.user?.id ?? '';
    if (peerId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(socketConnectionProvider.notifier).ensureConnection();
        if (!mounted) return;
        _chatPeerNotifier = ref.read(currentChatPeerUserIdProvider.notifier);
        _convIdNotifier = ref.read(currentConversationIdProvider.notifier);
        _socketService = ref.read(socketServiceProvider);
        _chatPeerNotifier.state = peerId;
        if (widget.user != null) {
          ref.read(chatMessagesProvider(peerId).notifier).setPeerUser(widget.user!);
        }
        ref.read(chatMessagesProvider(peerId).notifier).load().then((_) {
          if (!mounted) return;
          final state = ref.read(chatMessagesProvider(peerId));
          if (widget.user != null) {
            ref.read(chatMessagesProvider(peerId).notifier).setPeerUser(widget.user!);
          }
          if (state.conversationId != null && state.conversationId!.isNotEmpty) {
            if (kDebugMode) debugPrint('[ChatScreen] join room conversationId=${state.conversationId}');
            _currentConversationId = state.conversationId;
            _convIdNotifier.state = state.conversationId;
            _socketService?.chatSocket?.join(state.conversationId!);
          } else if (kDebugMode) {
            debugPrint('[ChatScreen] no conversationId yet (new chat?)');
          }
          _scrollToEnd();
        });
      });
    }
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    if (_currentConversationId != null && _currentConversationId!.isNotEmpty && _socketService != null) {
      if (kDebugMode) debugPrint('[ChatScreen] leave room conversationId=$_currentConversationId');
      _socketService.chatSocket.leave(_currentConversationId!);
    }
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
    if (_chatPeerNotifier != null || _convIdNotifier != null) {
      Future.microtask(() {
        _chatPeerNotifier?.state = null;
        _convIdNotifier?.state = null;
      });
    }
  }

  /// Scroll to bottom (newest messages). ListView is reverse: true so 0 = bottom.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  (Color, Color) _shimmerColors(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
    return (base, base.withValues(alpha: 0.35));
  }

  /// Shown at the visual top while older messages are loading (reverse list).
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
              crossAxisAlignment: CrossAxisAlignment.end,
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

  /// True if user is near the bottom (newest) so we can auto-scroll on incoming message.
  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.pixels <= 80;
  }

  void _onScroll() {
    final peerId = widget.user?.id ?? '';
    if (peerId.isEmpty) return;
    if (_loadingOlderInProgress) return;
    final state = ref.read(chatMessagesProvider(peerId));
    if (state.loadingOlder || !state.hasMoreOlder || state.messages.isEmpty) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // In reverse list, maxScrollExtent is the top (older messages). Load more only when at top.
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      _loadingOlderInProgress = true;
      _maxScrollExtentBeforeLoadOlder = pos.maxScrollExtent;
      ref.read(chatMessagesProvider(peerId).notifier).loadOlder().whenComplete(() {
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

  void _sendMessage() {
    final peerId = widget.user?.id ?? '';
    if (peerId.isEmpty) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    // If user pasted a post link and we resolved it, send as postLink so backend can attach post data.
    final composer = ref.read(chatComposerProvider(peerId));
    if (composer.resolvedPostPreview != null &&
        composer.lastResolvedInput == text) {
      ref.read(chatComposerProvider(peerId).notifier).clearPreview();
      ref.read(chatMessagesProvider(peerId).notifier).sendPostLink(text);
    } else {
      ref.read(chatMessagesProvider(peerId).notifier).sendMessage(text);
    }
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final peerId = widget.user?.id ?? '';
    final chatUser = widget.user ?? UserModel(id: '', username: '', displayName: '', avatarUrl: '');

    if (peerId.isEmpty) {
      return Material(
        color: ThemeHelper.getBackgroundColor(context),
        child: Scaffold(
          backgroundColor: ThemeHelper.getBackgroundColor(context),
          appBar: AppBar(title: const Text('Chat')),
          body: const Center(child: Text('Select a user to chat')),
        ),
      );
    }

    final chatState = ref.watch(chatMessagesProvider(peerId));
    final composerState = ref.watch(chatComposerProvider(peerId));

    ref.listen<ChatMessagesState>(chatMessagesProvider(peerId), (prev, next) {
      if (prev == null) return;
      if (next.conversationId != null && prev.conversationId != next.conversationId) {
        final convId = next.conversationId!;
        _currentConversationId = convId;
        if (kDebugMode) debugPrint('[ChatScreen] ref.listen: conversationId updated, joining convId=$convId');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_convIdNotifier != null) {
            _convIdNotifier.state = convId;
          } else {
            ref.read(currentConversationIdProvider.notifier).state = convId;
          }
          if (_socketService != null) {
            _socketService.chatSocket.join(convId);
          } else {
            ref.read(socketServiceProvider).chatSocket.join(convId);
          }
        });
      }
      // Only auto-scroll when a new message was added and user is already at bottom (e.g. incoming from peer)
      if (next.messages.length != prev.messages.length && _isNearBottom) {
        _scrollToEnd();
      }
    });

    final messages = chatState.messages;

    return Material(
      color: ThemeHelper.getBackgroundColor(context),
      child: Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: ThemeHelper.getSurfaceColor(context).withOpacity(isDark ? 0.4 : 0.85),
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: Border(
            bottom: BorderSide(
              color: ThemeHelper.getBorderColor(context).withOpacity(0.5),
              width: 0.5,
            ),
          ),
          iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
          titleSpacing: 0,
          title: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ThemeHelper.getBorderColor(context),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildAvatar(chatUser.avatarUrl, 44),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chatUser.displayName.isNotEmpty ? chatUser.displayName : chatUser.username,
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.videocam_outlined, color: ThemeHelper.getTextPrimary(context)),
              onPressed: () {
                final peerId = widget.user?.id ?? '';
                if (peerId.isEmpty) return;
                final me = ref.read(currentUserProvider);
                if (me == null || me.id.isEmpty) return;
                final ids = [me.id, peerId]..sort();
                final channel =
                    'call_${ids.join("_")}_${DateTime.now().millisecondsSinceEpoch}';
                ref.read(callsProvider.notifier).startOutgoingCall(
                      channelName: channel,
                      receiverId: peerId,
                      receiverUsername: widget.user?.username,
                      receiverProfilePicture: widget.user?.avatarUrl,
                      startWithVideo: true,
                    );
              },
            ),
            IconButton(
              icon: Icon(Icons.call_outlined, color: ThemeHelper.getTextPrimary(context)),
              onPressed: () {
                final peerId = widget.user?.id ?? '';
                if (peerId.isEmpty) return;
                final me = ref.read(currentUserProvider);
                if (me == null || me.id.isEmpty) return;
                final ids = [me.id, peerId]..sort();
                final channel =
                    'call_${ids.join("_")}_${DateTime.now().millisecondsSinceEpoch}';
                ref.read(callsProvider.notifier).startOutgoingCall(
                      channelName: channel,
                      receiverId: peerId,
                      receiverUsername: widget.user?.username,
                      receiverProfilePicture: widget.user?.avatarUrl,
                      startWithVideo: false,
                    );
              },
            ),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: ThemeHelper.getBackgroundGradient(context),
          ),
          child: Column(
            children: [
              Expanded(
                child: chatState.loading && messages.isEmpty
                    ? _buildChatMessagesSkeleton(context)
                    : chatState.error != null && messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                chatState.error!,
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
                              itemCount: messages.length + (chatState.loadingOlder ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (chatState.loadingOlder && index == messages.length) {
                                  return _buildOlderMessagesShimmer(context);
                                }
                                final msg = messages[messages.length - 1 - index];
                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 375),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: _buildMessageBubble(msg),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
              _buildModernInputBar(chatState.sending, composerState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String url, double size) {
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context), size: size * 0.5),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context), size: size * 0.5),
      ),
      errorWidget: (_, __, ___) => Container(
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context), size: size * 0.5),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final currentUser = ref.watch(currentUserProvider);
    final isMe = currentUser != null && message.sender.id == currentUser.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message, isMe: isMe),
        child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: _buildAvatar(message.sender.avatarUrl, 32),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: AnimatedSlide(
              key: ValueKey(message.id),
              offset: (isMe && message.status == MessageSendStatus.sending)
                  ? const Offset(-0.06, 0)
                  : Offset.zero,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    backgroundColor: isMe
                        ? ThemeHelper.getAccentColor(context).withOpacity(0.2)
                        : ThemeHelper.getSurfaceColor(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.type == MessageType.image &&
                            message.mediaUrl != null &&
                            message.mediaUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildImagePreview(message.mediaUrl!),
                          ),
                        if (message.type == MessageType.video &&
                            message.mediaUrl != null &&
                            message.mediaUrl!.isNotEmpty)
                          _buildVideoStub(message.mediaUrl!),
                        if (message.text.isNotEmpty) ...[
                          if (message.type == MessageType.image) const SizedBox(height: 8),
                          Text(
                            message.text,
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: ThemeHelper.getTextMuted(context),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMe)
                    Positioned(
                      bottom: -6,
                      right: -6,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: message.status == MessageSendStatus.sending
                            ? Container(
                                key: const ValueKey('sending'),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: ThemeHelper.getSurfaceColor(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ThemeHelper.getBorderColor(context).withOpacity(0.5),
                                  ),
                                ),
                                child: Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: ThemeHelper.getTextMuted(context),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('sent')),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _showMessageActions(MessageModel message,
      {required bool isMe}) async {
    final peerId = widget.user?.id ?? '';
    if (peerId.isEmpty) return;
    final id = message.id;
    if (id.isEmpty || id.startsWith('pending-')) return;

    final accent = ThemeHelper.getAccentColor(context);
    final sheetBg = ThemeHelper.getSecondaryBackgroundColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final textMuted = ThemeHelper.getTextMuted(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
                    color: textMuted.withAlpha(60),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.forward_to_inbox_outlined, color: textPrimary),
                  title: Text('Forward', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _forwardMessage(messageId: id);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: textPrimary),
                  title: Text('Delete for me', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ChatService().deleteMessage(messageId: id, deleteForEveryone: false);
                    // Local-only delete: remove from UI immediately.
                    ref.read(chatMessagesProvider(peerId).notifier).removeFromSocket({'messageId': id});
                  },
                ),
                if (isMe)
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: accent),
                    title: Text('Delete for everyone', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ChatService().deleteMessage(messageId: id, deleteForEveryone: true);
                      // For everyone: server should emit socket event, but we also remove optimistically.
                      ref.read(chatMessagesProvider(peerId).notifier).removeFromSocket({'messageId': id});
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _forwardMessage({required String messageId}) async {
    try {
      final res = await ChatService().getShareableUsers();
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage ?? 'Failed to load users')),
        );
        return;
      }
      final users = res.data ?? const <Map<String, dynamic>>[];
      if (users.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No users to share with')),
        );
        return;
      }

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: ThemeHelper.getSecondaryBackgroundColor(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: ThemeHelper.getBorderColor(ctx).withAlpha(50),
              ),
              itemBuilder: (ctx, i) {
                final u = users[i];
                final id = (u['id'] ?? u['_id'] ?? '').toString();
                final name = (u['username'] ?? u['name'] ?? u['displayName'] ?? 'User').toString();
                final avatar = (u['profilePicture'] ?? u['avatarUrl'] ?? u['image'] ?? '').toString();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ThemeHelper.getSurfaceColor(ctx),
                    backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                    child: avatar.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(name, style: TextStyle(color: ThemeHelper.getTextPrimary(ctx))),
                  subtitle: id.isNotEmpty ? Text(id, style: TextStyle(color: ThemeHelper.getTextMuted(ctx), fontSize: 11)) : null,
                  onTap: id.isEmpty ? null : () => Navigator.pop(ctx, u),
                );
              },
            ),
          );
        },
      );

      if (selected == null) return;
      final receiverId = (selected['id'] ?? selected['_id'] ?? '').toString();
      if (receiverId.isEmpty) return;
      final fwd = await ChatService().forwardMessage(
        messageId: messageId,
        receiverId: receiverId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fwd.success ? 'Forwarded' : (fwd.errorMessage ?? 'Forward failed'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildModernInputBar(bool sending, ChatComposerState composer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        decoration: BoxDecoration(
          color: isDark
              ? ThemeHelper.getSecondaryBackgroundColor(context)
              : ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: ThemeHelper.getBorderColor(context).withOpacity(0.3),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: isDark ? 16 : 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (composer.resolvingPost || composer.resolvedPostPreview != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeHelper.getSurfaceColor(context).withAlpha(230),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ThemeHelper.getBorderColor(context).withAlpha(80),
                  ),
                ),
                child: Row(
                  children: [
                    if (composer.resolvingPost)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ThemeHelper.getAccentColor(context),
                        ),
                      )
                    else
                      Icon(
                        Icons.link,
                        size: 18,
                        color: ThemeHelper.getAccentColor(context),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        composer.resolvingPost
                            ? 'Resolving post preview...'
                            : 'Post link preview ready',
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final peerId = widget.user?.id ?? '';
                        if (peerId.isEmpty) return;
                        ref.read(chatComposerProvider(peerId).notifier).clearPreview();
                      },
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: ThemeHelper.getTextMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: ThemeHelper.getAccentColor(context),
                size: 28,
              ),
              onPressed: _openPlusSheet,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark
                      ? ThemeHelper.getBackgroundColor(context).withOpacity(0.6)
                      : ThemeHelper.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ThemeHelper.getBorderColor(context).withOpacity(isDark ? 0.4 : 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                      blurRadius: isDark ? 4 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: true,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 16,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (val) {
                    final peerId = widget.user?.id ?? '';
                    if (peerId.isEmpty) return;
                    final t = val.trim();
                    if (!t.startsWith('http')) {
                      ref.read(chatComposerProvider(peerId).notifier).clearPreview();
                      return;
                    }
                    final last = ref.read(chatComposerProvider(peerId)).lastResolvedInput;
                    if (t == last) return;
                    _resolveDebounce?.cancel();
                    _resolveDebounce = Timer(const Duration(milliseconds: 450), () async {
                      if (!mounted) return;
                      if (_messageController.text.trim() != t) return;
                      ref.read(chatComposerProvider(peerId).notifier).setResolving(t);
                      final res = await ChatService().resolvePostPreview(postLink: t);
                      if (!mounted) return;
                      ref.read(chatComposerProvider(peerId).notifier).setResolved(
                            t,
                            res.success ? res.data : null,
                          );
                    });
                  },
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: ThemeHelper.getAccentGradient(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.getAccentColor(context).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: ThemeHelper.getOnAccentColor(context),
                    size: 22,
                  ),
                ),
              ),
            ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlusSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: ThemeHelper.getSecondaryBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeHelper.getBorderColor(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAttachmentOption(
                  Icons.photo_library_outlined,
                  'Gallery',
                  onTap: _pickFromGallery,
                ),
                _buildAttachmentOption(
                  Icons.camera_alt_outlined,
                  'Camera',
                  onTap: _openCameraCaptureSheet,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  MessageType _inferTypeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.mkv') ||
        p.endsWith('.webm') ||
        p.endsWith('.3gp')) {
      return MessageType.video;
    }
    return MessageType.image;
  }

  Future<void> _pickFromGallery() async {
    final peerId = widget.user?.id ?? '';
    if (peerId.isEmpty) return;

    final res = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (!mounted || res == null) return;
    final files = res.paths.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (files.isEmpty) return;

    for (final path in files) {
      final type = _inferTypeFromPath(path);
      unawaited(ref.read(chatMessagesProvider(peerId).notifier).sendMedia(path, type));
    }
  }

  Future<void> _openCameraCaptureSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: ThemeHelper.getSecondaryBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeHelper.getBorderColor(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAttachmentOption(
                  Icons.photo_camera_outlined,
                  'Take Photo',
                  onTap: _capturePhoto,
                ),
                _buildAttachmentOption(
                  Icons.videocam_outlined,
                  'Record Video',
                  onTap: _captureVideo,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _capturePhoto() async {
    final peerId = widget.user?.id ?? '';
    if (peerId.isEmpty) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (!mounted || file == null) return;
    await ref.read(chatMessagesProvider(peerId).notifier).sendMedia(file.path, MessageType.image);
  }

  Future<void> _captureVideo() async {
    final peerId = widget.user?.id ?? '';
    if (peerId.isEmpty) return;
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.camera);
    if (!mounted || file == null) return;
    await ref.read(chatMessagesProvider(peerId).notifier).sendMedia(file.path, MessageType.video);
  }

  Widget _buildAttachmentOption(IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ThemeHelper.getAccentColor(context).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: ThemeHelper.getAccentColor(context), size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: ThemeHelper.getTextPrimary(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap != null
          ? () {
              Navigator.pop(context);
              onTap();
            }
          : () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$label sharing coming soon',
                    style: TextStyle(color: ThemeHelper.getOnAccentColor(context)),
                  ),
                  backgroundColor: ThemeHelper.getAccentColor(context),
                ),
              );
            },
    );
  }

  Widget _buildImagePreview(String urlOrPath) {
    // Local file path
    if (!urlOrPath.startsWith('http://') && !urlOrPath.startsWith('https://')) {
      final f = File(urlOrPath);
      return Image.file(
        f,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 200,
          height: 200,
          color: ThemeHelper.getSurfaceColor(context),
          child: Icon(Icons.broken_image, color: ThemeHelper.getTextMuted(context)),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: urlOrPath,
      width: 200,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        width: 200,
        height: 200,
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(Icons.broken_image, color: ThemeHelper.getTextMuted(context)),
      ),
    );
  }

  Widget _buildVideoStub(String urlOrPath) {
    return Container(
      width: 220,
      height: 140,
      decoration: BoxDecoration(
        color: ThemeHelper.getSurfaceColor(context).withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context).withAlpha(80),
        ),
      ),
      child: Center(
        child: Icon(
          Icons.videocam_rounded,
          size: 42,
          color: ThemeHelper.getTextMuted(context),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
