import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/models/message_model.dart';
import '../../../core/utils/theme_helper.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/shared_post_message_bubble.dart';
import 'chat_media_mosaic.dart';

/// Unified chat bubble with content-based max width.
class ChatMessageBubbleWidget extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final bool showSenderName;
  final String? senderDisplayName;
  final double maxBubbleWidth;
  final VoidCallback? onLongPress;
  final Widget Function(String url)? avatarBuilder;

  const ChatMessageBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.showSenderName = false,
    this.senderDisplayName,
    required this.maxBubbleWidth,
    this.onLongPress,
    this.avatarBuilder,
  });

  BorderRadius get _tailRadius => BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMe ? 18 : 6),
        bottomRight: Radius.circular(isMe ? 6 : 18),
      );

  @override
  Widget build(BuildContext context) {
    final mediaOnly = message.isMediaOnly && !message.isSharedPost;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showAvatar) ...[
              _buildAvatar(context, message.sender.avatarUrl, 32),
              const SizedBox(width: 8),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: AnimatedSlide(
                key: ValueKey(message.id),
                offset: (isMe && message.status == MessageSendStatus.sending)
                    ? const Offset(-0.05, 0)
                    : Offset.zero,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  children: [
                    Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showSenderName && !isMe && senderDisplayName != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                            child: Text(
                              senderDisplayName!,
                              style: TextStyle(
                                color: ThemeHelper.getAccentColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        if (message.isSharedPost)
                          _sharedPostBubble(context)
                        else if (mediaOnly)
                          _mediaOnlyContent(context)
                        else
                          _textBubble(context, includeMedia: message.hasMedia),
                      ],
                    ),
                    if (isMe) _sendingBadge(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sharedPostBubble(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: _tailRadius,
      backgroundColor: isMe
          ? ThemeHelper.getAccentColor(context).withValues(alpha: 0.18)
          : ThemeHelper.getSurfaceColor(context),
      child: SharedPostMessageBubble(
        message: message,
        borderRadius: _tailRadius,
      ),
    );
  }

  Widget _mediaOnlyContent(BuildContext context) {
    return ChatMediaMosaic(
      messageId: message.id,
      attachments: message.effectiveAttachments,
      isOutgoing: isMe,
      maxWidth: maxBubbleWidth,
    );
  }

  Widget _textBubble(BuildContext context, {required bool includeMedia}) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      borderRadius: _tailRadius,
      backgroundColor: isMe
          ? ThemeHelper.getAccentColor(context).withValues(alpha: 0.2)
          : ThemeHelper.getSurfaceColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (includeMedia)
            Padding(
              padding: EdgeInsets.only(bottom: message.text.trim().isNotEmpty ? 8 : 0),
              child: ChatMediaMosaic(
                messageId: message.id,
                attachments: message.effectiveAttachments,
                isOutgoing: isMe,
                maxWidth: maxBubbleWidth - 24,
              ),
            ),
          if (message.text.trim().isNotEmpty)
            Text(
              message.text,
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 15,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sendingBadge(BuildContext context) {
    return Positioned(
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
                    color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.5),
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
    );
  }

  Widget _buildAvatar(BuildContext context, String url, double size) {
    if (avatarBuilder != null) return avatarBuilder!(url);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.45),
        ),
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  size: size * 0.5,
                  color: ThemeHelper.getTextSecondary(context),
                ),
              )
            : Icon(
                Icons.person,
                size: size * 0.5,
                color: ThemeHelper.getTextSecondary(context),
              ),
      ),
    );
  }
}
