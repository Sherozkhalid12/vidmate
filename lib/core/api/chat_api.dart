import 'dart:io';
import 'api_base.dart';

/// Chat/Messaging API service
class ChatApi extends ApiBase {
  // Get chat list
  Future<Map<String, dynamic>> getChatList() async {
    return await get('/chats');
  }

  // Get chat messages
  Future<Map<String, dynamic>> getMessages(String chatId, {int page = 1}) async {
    return await get(
      '/chats/$chatId/messages',
      queryParams: {'page': page.toString()},
    );
  }

  // Send text message
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String text,
  }) async {
    return await post(
      '/chats/$chatId/messages',
      {'text': text, 'type': 'text'},
    );
  }

  // Send media message
  Future<Map<String, dynamic>> sendMediaMessage({
    required String chatId,
    required File mediaFile,
    required String type, // 'image' or 'video'
  }) async {
    return await postMultipart(
      '/chats/$chatId/messages/media',
      mediaFile.path,
      'media',
      fields: {'type': type},
    );
  }

  // Mark message as read
  Future<Map<String, dynamic>> markAsRead(String chatId, String messageId) async {
    return await post('/chats/$chatId/messages/$messageId/read', {});
  }

  // Get online status
  Future<Map<String, dynamic>> getOnlineStatus(String userId) async {
    return await get('/users/$userId/online-status');
  }

  // Get last seen
  Future<Map<String, dynamic>> getLastSeen(String userId) async {
    return await get('/users/$userId/last-seen');
  }

  // Create or get chat
  Future<Map<String, dynamic>> createChat(String userId) async {
    return await post('/chats', {'userId': userId});
  }
}


