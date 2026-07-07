import 'chat_message_bubble.dart';
import 'message_attachment.dart';
import 'user_model.dart';

/// Chat message model
class MessageModel {
  final String id;
  /// Server-side message id (when available). For optimistic messages, this is null until send succeeds.
  final String? serverId;
  final UserModel sender;
  final String text;
  final String? mediaUrl;
  final List<MessageAttachment> attachments;
  final DateTime timestamp;
  final bool isRead;
  final List<String> readBy;
  final MessageType type;
  final MessageSendStatus status;
  /// Set when [type] is [MessageType.sharedPost].
  final String? sharedPostId;
  final PostPreview? sharedPostPreview;

  MessageModel({
    required this.id,
    this.serverId,
    required this.sender,
    required this.text,
    this.mediaUrl,
    this.attachments = const [],
    required this.timestamp,
    this.isRead = false,
    this.readBy = const [],
    this.type = MessageType.text,
    this.status = MessageSendStatus.sent,
    this.sharedPostId,
    this.sharedPostPreview,
  });

  bool get isSharedPost =>
      type == MessageType.sharedPost ||
      (sharedPostId != null && sharedPostId!.isNotEmpty);

  bool get hasMedia =>
      attachments.isNotEmpty ||
      (mediaUrl != null && mediaUrl!.isNotEmpty && (type == MessageType.image || type == MessageType.video));

  bool get isMediaOnly => hasMedia && text.trim().isEmpty && !isSharedPost;

  List<MessageAttachment> get effectiveAttachments {
    if (attachments.isNotEmpty) return attachments;
    if (mediaUrl != null && mediaUrl!.trim().isNotEmpty) {
      return [
        MessageAttachment(
          url: mediaUrl!,
          mediaType: type == MessageType.video ? 'video' : 'image',
        ),
      ];
    }
    return const [];
  }

  MessageModel copyWith({
    String? id,
    String? serverId,
    UserModel? sender,
    String? text,
    String? mediaUrl,
    List<MessageAttachment>? attachments,
    DateTime? timestamp,
    bool? isRead,
    List<String>? readBy,
    MessageType? type,
    MessageSendStatus? status,
    String? sharedPostId,
    PostPreview? sharedPostPreview,
  }) {
    return MessageModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readBy: readBy ?? this.readBy,
      type: type ?? this.type,
      status: status ?? this.status,
      sharedPostId: sharedPostId ?? this.sharedPostId,
      sharedPostPreview: sharedPostPreview ?? this.sharedPostPreview,
    );
  }
}

enum MessageType {
  text,
  image,
  video,
  audio,
  sharedPost,
}

enum MessageSendStatus {
  sending,
  sent,
  failed,
}
