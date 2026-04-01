import 'user_model.dart';

/// Chat message model
class MessageModel {
  final String id;
  /// Server-side message id (when available). For optimistic messages, this is null until send succeeds.
  final String? serverId;
  final UserModel sender;
  final String text;
  final String? mediaUrl;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final MessageSendStatus status;

  MessageModel({
    required this.id,
    this.serverId,
    required this.sender,
    required this.text,
    this.mediaUrl,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.status = MessageSendStatus.sent,
  });
}

enum MessageType {
  text,
  image,
  video,
  audio,
}

enum MessageSendStatus {
  sending,
  sent,
  failed,
}


