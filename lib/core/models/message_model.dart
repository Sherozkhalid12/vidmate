import 'user_model.dart';

/// Chat message model
class MessageModel {
  final String id;
  final UserModel sender;
  final String text;
  final String? mediaUrl;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;

  MessageModel({
    required this.id,
    required this.sender,
    required this.text,
    this.mediaUrl,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
  });
}

enum MessageType {
  text,
  image,
  video,
  audio,
}


