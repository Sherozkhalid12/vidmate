import '../../../core/models/message_model.dart';

/// A renderable row in the chat list: either a normal message or a run of
/// consecutive media-only messages from the same sender (shown as one collage).
sealed class ChatRenderRow {
  const ChatRenderRow();
}

class MessageRow extends ChatRenderRow {
  final MessageModel message;
  const MessageRow(this.message);
}

class MediaGroupRow extends ChatRenderRow {
  /// Chronological media-only messages, same sender, sent close together.
  final List<MessageModel> messages;
  const MediaGroupRow(this.messages);

  MessageModel get anchor => messages.last;
  String get senderId => messages.first.sender.id;
}

class ChatMessageGrouper {
  ChatMessageGrouper._();

  /// Max gap between two media messages to still be considered one "album".
  static const Duration _window = Duration(minutes: 2);

  static bool _isGroupable(MessageModel m) =>
      m.isMediaOnly && !m.isSharedPost && m.effectiveAttachments.isNotEmpty;

  /// [messages] must be chronological (oldest -> newest).
  static List<ChatRenderRow> group(List<MessageModel> messages) {
    final rows = <ChatRenderRow>[];
    var i = 0;
    while (i < messages.length) {
      final current = messages[i];
      if (!_isGroupable(current)) {
        rows.add(MessageRow(current));
        i++;
        continue;
      }

      final run = <MessageModel>[current];
      var j = i + 1;
      while (j < messages.length) {
        final next = messages[j];
        if (!_isGroupable(next)) break;
        if (next.sender.id != current.sender.id) break;
        if (next.timestamp.difference(run.last.timestamp).abs() > _window) break;
        run.add(next);
        j++;
      }

      rows.add(MediaGroupRow(run));
      i = j;
    }
    return rows;
  }
}
