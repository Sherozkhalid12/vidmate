import 'package:flutter/material.dart';

import '../../../core/models/message_attachment.dart';
import '../media/chat_media_models.dart';
import '../media/chat_media_viewer.dart';
import 'chat_media_collage.dart';

/// Thin adapter that renders the media of a *single* message (used inside
/// text+media bubbles). Layout + caching live in [ChatMediaCollage] /
/// [ChatMediaImage]; this just wires the message's attachments to the viewer.
class ChatMediaMosaic extends StatelessWidget {
  final String messageId;
  final List<MessageAttachment> attachments;
  final bool isOutgoing;
  final double maxWidth;

  const ChatMediaMosaic({
    super.key,
    required this.messageId,
    required this.attachments,
    this.isOutgoing = false,
    this.maxWidth = 260,
  });

  @override
  Widget build(BuildContext context) {
    final items = ChatMediaItem.fromAttachments(messageId, attachments);
    if (items.isEmpty) return const SizedBox.shrink();

    return ChatMediaCollage(
      items: items,
      maxWidth: maxWidth,
      onTapIndex: (index) {
        if (items.length == 1) {
          openChatMediaViewer(context, items, initialIndex: index);
        } else {
          openChatMediaGrid(context, items);
        }
      },
    );
  }
}
