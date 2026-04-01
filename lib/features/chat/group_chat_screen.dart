import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/message_model.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/chat_provider_riverpod.dart';
import '../../core/providers/socket_provider_riverpod.dart';
import '../../core/providers/socket_instance_provider_riverpod.dart';
import '../../core/utils/theme_helper.dart';

/// Basic group chat screen.
/// - Joins socket room `group:<groupId>`
/// - Loads history from GET /chat/group/:groupId/messages
/// - Sends messages via POST /chat/send with groupId
class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_normalizedGroupId.isEmpty) {
        await ref.read(groupChatProvider(_normalizedGroupId).notifier).load();
        return;
      }
      await ref.read(socketConnectionProvider.notifier).ensureConnection();
      if (!mounted) return;
      // Mark this room as the currently-open conversation so SocketProvider can route group messages.
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
    final currentConvId = ref.read(currentConversationIdProvider);
    if (currentConvId == _roomId) {
      Future.microtask(() {
        ref.read(currentConversationIdProvider.notifier).state = null;
      });
    }
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

  Future<void> _sendText() async {
    final groupId = _normalizedGroupId;
    if (groupId.isEmpty) return;
    final t = _messageController.text.trim();
    if (t.isEmpty) return;
    _messageController.clear();
    await ref.read(groupChatProvider(groupId).notifier).sendText(t);
    _scrollToEnd();
  }

  Future<void> _sendMedia(String path, MessageType type) async {
    final groupId = _normalizedGroupId;
    if (groupId.isEmpty) return;
    final p = path.trim();
    if (p.isEmpty) return;
    await ref.read(groupChatProvider(groupId).notifier).sendMedia(p, type);
    _scrollToEnd();
  }

  Widget _buildImagePreview(String urlOrPath) {
    if (!urlOrPath.startsWith('http://') && !urlOrPath.startsWith('https://')) {
      return Image.file(
        File(urlOrPath),
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

  Widget _buildMessageBubble(MessageModel m) {
    final me = ref.watch(currentUserProvider);
    final isMe = me != null && m.sender.id == me.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: ThemeHelper.getSurfaceColor(context),
              backgroundImage: m.sender.avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(m.sender.avatarUrl)
                  : null,
              child: m.sender.avatarUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: AnimatedSlide(
              key: ValueKey(m.id),
              offset: (isMe && m.status == MessageSendStatus.sending)
                  ? const Offset(-0.06, 0)
                  : Offset.zero,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? ThemeHelper.getAccentColor(context).withAlpha(40)
                          : ThemeHelper.getSurfaceColor(context).withAlpha(140),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: Border.all(
                        color: ThemeHelper.getBorderColor(context).withAlpha(70),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              m.sender.displayName.isNotEmpty ? m.sender.displayName : 'Member',
                              style: TextStyle(
                                color: ThemeHelper.getTextMuted(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (m.type == MessageType.image && m.mediaUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildImagePreview(m.mediaUrl!),
                          ),
                        if (m.type == MessageType.video)
                          Container(
                            width: 220,
                            height: 140,
                            decoration: BoxDecoration(
                              color: ThemeHelper.getSurfaceColor(context).withAlpha(180),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.videocam_rounded,
                                size: 42,
                                color: ThemeHelper.getTextMuted(context),
                              ),
                            ),
                          ),
                        if (m.text.isNotEmpty) ...[
                          if (m.type != MessageType.text) const SizedBox(height: 8),
                          Text(
                            m.text,
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
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
                        child: m.status == MessageSendStatus.sending
                            ? Container(
                                key: const ValueKey('sending'),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: ThemeHelper.getSurfaceColor(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ThemeHelper.getBorderColor(context).withAlpha(80),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = ThemeHelper.getBackgroundColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(groupChatProvider(_normalizedGroupId));

    ref.listen<GroupChatState>(groupChatProvider(_normalizedGroupId), (prev, next) {
      if (prev == null) return;
      if (next.messages.length != prev.messages.length && _isNearBottom) {
        _scrollToEnd();
      }
    });

    final messages = state.messages;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: ThemeHelper.getSurfaceColor(context).withOpacity(isDark ? 0.4 : 0.85),
        elevation: 0,
        title: Text(
          widget.groupName,
          style: TextStyle(
            color: ThemeHelper.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: ThemeHelper.getBackgroundGradient(context)),
        child: Column(
          children: [
            Expanded(
              child: state.loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ThemeHelper.getAccentColor(context),
                      ),
                    )
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
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (ctx, i) {
                            final m = messages[messages.length - 1 - i];
                            return _buildMessageBubble(m);
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                decoration: BoxDecoration(
                  color: ThemeHelper.getSurfaceColor(context).withAlpha(230),
                  border: Border(
                    top: BorderSide(
                      color: ThemeHelper.getBorderColor(context).withAlpha(70),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: ThemeHelper.getAccentColor(context)),
                      onPressed: _openMediaSheet,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: true,
                        style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: ThemeHelper.getTextMuted(context)),
                          filled: true,
                          fillColor: ThemeHelper.getBackgroundColor(context).withAlpha(70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendText(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _sendText,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ThemeHelper.getAccentColor(context),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(Icons.send_rounded, color: ThemeHelper.getOnAccentColor(context), size: 20),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _GroupChatScreenState {
  Future<void> _openMediaSheet() async {
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
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeHelper.getTextMuted(ctx).withAlpha(60),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                _sheetOption(
                  ctx,
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromGallery();
                  },
                ),
                _sheetOption(
                  ctx,
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCameraCaptureSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ThemeHelper.getAccentColor(ctx).withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: ThemeHelper.getAccentColor(ctx)),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: ThemeHelper.getTextPrimary(ctx),
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
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
    final res = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (!mounted || res == null) return;
    final files = res.paths.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (files.isEmpty) return;
    for (final path in files) {
      final type = _inferTypeFromPath(path);
      unawaited(_sendMedia(path, type));
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
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeHelper.getTextMuted(ctx).withAlpha(60),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                _sheetOption(
                  ctx,
                  icon: Icons.photo_camera_outlined,
                  label: 'Take Photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _capturePhoto();
                  },
                ),
                _sheetOption(
                  ctx,
                  icon: Icons.videocam_outlined,
                  label: 'Record Video',
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final f = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (!mounted || f == null) return;
    await _sendMedia(f.path, MessageType.image);
  }

  Future<void> _captureVideo() async {
    final picker = ImagePicker();
    final f = await picker.pickVideo(source: ImageSource.camera);
    if (!mounted || f == null) return;
    await _sendMedia(f.path, MessageType.video);
  }
}
