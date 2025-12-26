import 'user_model.dart';
import 'message_model.dart';

/// Chat conversation model for recent messages list
class ChatConversationModel {
  final String id;
  final UserModel user; // For 1-to-1 chat
  final List<UserModel>? participants; // For group chat
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final MessageModel lastMessage;
  final int unreadCount;
  final DateTime lastMessageTime;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatConversationModel({
    required this.id,
    required this.user,
    this.participants,
    this.isGroup = false,
    this.groupName,
    this.groupAvatar,
    required this.lastMessage,
    this.unreadCount = 0,
    required this.lastMessageTime,
    this.isOnline = false,
    this.lastSeen,
  });
}


