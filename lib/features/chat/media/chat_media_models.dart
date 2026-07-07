import '../../../core/models/message_attachment.dart';
import '../../../core/models/message_model.dart';

/// A single resolvable media unit (image or video) inside a chat.
///
/// Lightweight + immutable so it can be passed cheaply to the collage,
/// grid, and full-screen viewer without re-deriving anything.
class ChatMediaItem {
  final String url;
  final bool isVideo;

  /// Stable id used both for Hero animations and de-duplication.
  final String heroTag;

  const ChatMediaItem({
    required this.url,
    required this.isVideo,
    required this.heroTag,
  });

  bool get isLocal => !url.startsWith('http');

  static List<ChatMediaItem> fromAttachments(
    String messageId,
    List<MessageAttachment> attachments,
  ) {
    final out = <ChatMediaItem>[];
    for (var i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      final url = a.url.trim();
      if (url.isEmpty) continue;
      out.add(
        ChatMediaItem(
          url: url,
          isVideo: a.isVideo,
          heroTag: 'chat-media-$messageId-$i-$url',
        ),
      );
    }
    return out;
  }

  /// Flattens a run of consecutive media messages into a single ordered list.
  static List<ChatMediaItem> fromMessages(List<MessageModel> messages) {
    final out = <ChatMediaItem>[];
    for (final m in messages) {
      out.addAll(fromAttachments(m.id, m.effectiveAttachments));
    }
    return out;
  }
}
