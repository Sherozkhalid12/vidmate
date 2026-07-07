import 'package:flutter/material.dart';

import '../../../core/utils/theme_helper.dart';
import '../media/chat_media_models.dart';
import '../media/chat_media_viewer.dart';
import '../utils/chat_message_grouper.dart';
import 'chat_media_collage.dart';

/// Renders a run of consecutive media-only messages as a single collage bubble.
///
/// Tapping any cell opens the grid (for multi-item runs) or the swipeable
/// viewer directly (single item), matching the Instagram album flow.
class ChatMediaGroupBubble extends StatelessWidget {
  final MediaGroupRow row;
  final bool isMe;
  final bool showSenderName;
  final String? senderDisplayName;
  final double maxBubbleWidth;
  final VoidCallback? onLongPress;
  final Widget Function(String url)? avatarBuilder;

  const ChatMediaGroupBubble({
    super.key,
    required this.row,
    required this.isMe,
    required this.maxBubbleWidth,
    this.showSenderName = false,
    this.senderDisplayName,
    this.onLongPress,
    this.avatarBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final items = ChatMediaItem.fromMessages(row.messages);
    if (items.isEmpty) return const SizedBox.shrink();

    final width = maxBubbleWidth.clamp(0.0, 300.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && avatarBuilder != null) ...[
              avatarBuilder!(row.messages.last.sender.avatarUrl),
              const SizedBox(width: 8),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: Column(
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
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ChatMediaCollage(
                      items: items,
                      maxWidth: width,
                      onTapIndex: (index) => _open(context, items, index),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, List<ChatMediaItem> items, int index) {
    if (items.length == 1) {
      openChatMediaViewer(context, items, initialIndex: index);
    } else {
      openChatMediaGrid(context, items, title: 'Media');
    }
  }
}
