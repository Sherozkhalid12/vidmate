import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/chat_message_bubble.dart';
import '../../core/models/chat_conversation_api.dart';

/// Generic API result wrapper (when shape varies by endpoint).
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  ApiResult({
    required this.success,
    this.data,
    this.errorMessage,
  });
}

/// Result of send message API.
class SendMessageResult {
  final bool success;
  final ChatMessageBubble? chat;
  final String? errorMessage;

  SendMessageResult({
    required this.success,
    this.chat,
    this.errorMessage,
  });
}

/// Result of get user chat (messages) API.
class GetUserChatResult {
  final bool success;
  final String? conversationId;
  final List<ChatMessageBubble> messages;
  final String? errorMessage;

  GetUserChatResult({
    required this.success,
    this.conversationId,
    this.messages = const [],
    this.errorMessage,
  });
}

/// Result of get conversations API.
class GetConversationsResult {
  final bool success;
  final List<ChatConversationItem> conversations;
  final String? errorMessage;

  GetConversationsResult({
    required this.success,
    this.conversations = const [],
    this.errorMessage,
  });
}

/// Chat API service. Uses Dio with auth token.
class ChatService {
  static const String _tokenKey = 'auth_token';
  final Dio _dio = DioClient.instance;

  static String _normalizeGroupId(String? groupId) {
    final id = (groupId ?? '').trim();
    if (id.isEmpty) return '';
    if (id.startsWith('group:')) {
      final parts = id.split(':');
      return parts.isNotEmpty ? parts.last.trim() : id.substring('group:'.length).trim();
    }
    return id;
  }

  static bool _looksLikeVideoPath(String path) {
    final p = path.trim().toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.mkv') ||
        p.endsWith('.webm') ||
        p.endsWith('.3gp');
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<ApiResult<T>> _withAuth<T>(Future<T> Function() fn) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return ApiResult(success: false, errorMessage: 'Not authenticated');
    }
    DioClient.setAuthToken(token);
    try {
      final data = await fn();
      return ApiResult(success: true, data: data);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ??
                  e.response?.data['error'] ??
                  'Request failed')
              .toString()
          : 'Request failed';
      return ApiResult(success: false, errorMessage: msg);
    } catch (e) {
      return ApiResult(success: false, errorMessage: e.toString());
    }
  }

  static String _pickError(Map<String, dynamic>? data, String fallback) {
    final err = data?['message'] ?? data?['error'] ?? fallback;
    return err.toString();
  }

  /// POST send message. Body: receiverId, message.
  Future<SendMessageResult> sendMessage({
    String? receiverId,
    String? groupId,
    /// Preferred key for normal messages.
    String? text,
    /// Backward compatible alias used across existing UI.
    String? message,
    /// Optional explicit type: text|image|video|media|post|deleted.
    String? messageType,
    /// URL-based attachments (backend spec).
    List<ChatAttachment> attachments = const [],
    /// Optional URL arrays (backend spec).
    List<String> images = const [],
    List<String> videos = const [],
    List<String> mediaFilePaths = const [],
    String? postId,
    String? postLink,
  }) async {
    text ??= message;
    final normalizedReceiverId = (receiverId ?? '').trim();
    final normalizedGroupId = _normalizeGroupId(groupId);
    final hasReceiver = normalizedReceiverId.isNotEmpty;
    final hasGroup = normalizedGroupId.isNotEmpty;
    final targetOk = hasReceiver ^ hasGroup;
    final hasText = text != null && text.trim().isNotEmpty;
    final hasMedia = mediaFilePaths.isNotEmpty ||
        attachments.isNotEmpty ||
        images.where((e) => e.trim().isNotEmpty).isNotEmpty ||
        videos.where((e) => e.trim().isNotEmpty).isNotEmpty;
    final hasPost = (postId != null && postId.isNotEmpty) ||
        (postLink != null && postLink.isNotEmpty);

    if (!targetOk || (!hasText && !hasMedia && !hasPost)) {
      return SendMessageResult(
        success: false,
        errorMessage: 'Invalid input',
      );
    }

    String effectiveType() {
      final explicit = (messageType ?? '').trim();
      if (explicit.isNotEmpty) return explicit;
      final hasPost = (postId != null && postId.isNotEmpty) ||
          (postLink != null && postLink.isNotEmpty);
      if (hasPost) return 'post';
      final hasUrlImages = images.any((e) => e.trim().isNotEmpty);
      final hasUrlVideos = videos.any((e) => e.trim().isNotEmpty);
      if (attachments.isNotEmpty || hasUrlImages || hasUrlVideos || mediaFilePaths.isNotEmpty) {
        final attTypes = attachments.map((e) => e.mediaType).toSet();
        if (attTypes.contains('video') || hasUrlVideos) return 'video';
        if (attTypes.contains('image') || hasUrlImages) return 'image';
        if (mediaFilePaths.isNotEmpty) {
          final lower = mediaFilePaths
              .where((p) => p.trim().isNotEmpty)
              .map((p) => p.toLowerCase())
              .toList();
          final looksVideo = lower.any((p) =>
              p.endsWith('.mp4') ||
              p.endsWith('.mov') ||
              p.endsWith('.mkv') ||
              p.endsWith('.webm') ||
              p.endsWith('.3gp'));
          return looksVideo ? 'video' : 'image';
        }
        return 'media';
      }
      return 'text';
    }

    final auth = await _withAuth(() async {
      final hasFiles = mediaFilePaths.isNotEmpty;

      final payload = <String, dynamic>{
        if (hasReceiver) 'receiverId': normalizedReceiverId,
        if (hasGroup) 'groupId': normalizedGroupId,
        // Backend spec: `message` + `messageType` (keep `text` for backward compatibility).
        if (hasText) 'message': text!.trim(),
        if (hasText) 'text': text!.trim(),
        'messageType': effectiveType(),
        if (attachments.isNotEmpty) 'attachments': attachments.map((e) => e.toJson()).toList(),
        if (images.any((e) => e.trim().isNotEmpty)) 'images': images,
        if (videos.any((e) => e.trim().isNotEmpty)) 'videos': videos,
        if (postId != null && postId.isNotEmpty) 'postId': postId,
        if (postLink != null && postLink.isNotEmpty) 'postLink': postLink,
      };

      final Response response;
      if (hasFiles) {
        // Build multipart manually to ensure target fields (receiverId/groupId) are always sent.
        //
        // Backend spec supports `images[]` / `videos[]` in /chat/send body. For multipart uploads,
        // send picked media under those keys so the backend can parse them consistently.
        final form = FormData();
        if (hasReceiver) form.fields.add(MapEntry('receiverId', normalizedReceiverId));
        if (hasGroup) form.fields.add(MapEntry('groupId', normalizedGroupId));
        if (hasText) {
          final trimmed = text!.trim();
          form.fields.add(MapEntry('message', trimmed));
          form.fields.add(MapEntry('text', trimmed));
        }
        form.fields.add(MapEntry('messageType', effectiveType()));
        if (postId != null && postId.isNotEmpty) form.fields.add(MapEntry('postId', postId));
        if (postLink != null && postLink.isNotEmpty) form.fields.add(MapEntry('postLink', postLink));
        for (final p in mediaFilePaths) {
          final path = p.trim();
          if (path.isEmpty) continue;
          final key = _looksLikeVideoPath(path) ? 'videos' : 'images';
          form.files.add(MapEntry(key, await MultipartFile.fromFile(path)));
        }
        response = await _dio.post(
          ApiConstants.chatSend,
          data: form,
          queryParameters: {
            if (hasReceiver) 'receiverId': normalizedReceiverId,
            if (hasGroup) 'groupId': normalizedGroupId,
          },
          options: Options(contentType: 'multipart/form-data'),
        );
      } else {
        response = await _dio.post(
          ApiConstants.chatSend,
          data: payload,
          options: Options(contentType: Headers.jsonContentType),
        );
      }

      return response.data;
    });

    if (!auth.success) {
      return SendMessageResult(success: false, errorMessage: auth.errorMessage);
    }

    final data = auth.data is Map<String, dynamic>
        ? auth.data as Map<String, dynamic>
        : (auth.data is Map ? Map<String, dynamic>.from(auth.data as Map) : null);

    if (data == null || data['success'] != true) {
      return SendMessageResult(
        success: false,
        errorMessage: _pickError(data, 'Failed to send message'),
      );
    }

    final chatRaw = data['chat'];
    final chatJson = chatRaw is Map<String, dynamic>
        ? chatRaw
        : (chatRaw is Map ? Map<String, dynamic>.from(chatRaw) : null);
    if (chatJson == null) {
      return SendMessageResult(success: false, errorMessage: 'No chat in response');
    }

    return SendMessageResult(success: true, chat: ChatMessageBubble.fromJson(chatJson));
  }

  /// POST /share-post – send a post share message (when user taps “Share Post in Chat”).
  Future<ApiResult<Map<String, dynamic>>> sharePost({
    required String postIdOrLink,
    String? receiverId,
    String? groupId,
    String? message,
  }) async {
    final targetOk = (receiverId != null && receiverId.isNotEmpty) ||
        (groupId != null && groupId.isNotEmpty);
    if (postIdOrLink.trim().isEmpty || !targetOk) {
      return ApiResult(success: false, errorMessage: 'Invalid input');
    }

    return _withAuth(() async {
      final response = await _dio.post(
        ApiConstants.chatSharePost,
        data: {
          if (postIdOrLink.startsWith('http')) 'postLink': postIdOrLink.trim() else 'postId': postIdOrLink.trim(),
          if (receiverId != null && receiverId.isNotEmpty) 'receiverId': receiverId,
          if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
      if (map['success'] != true) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: _pickError(map, 'Failed to share post'),
        );
      }
      return map;
    });
  }

  /// POST /resolve-post – resolves a pasted post link/id into preview data for rich composer.
  Future<ApiResult<Map<String, dynamic>>> resolvePostPreview({
    String? postLink,
    String? postId,
  }) async {
    if ((postLink == null || postLink.trim().isEmpty) &&
        (postId == null || postId.trim().isEmpty)) {
      return ApiResult(success: false, errorMessage: 'Invalid input');
    }

    return _withAuth(() async {
      final response = await _dio.post(
        ApiConstants.chatResolvePost,
        data: {
          if (postLink != null && postLink.trim().isNotEmpty) 'postLink': postLink.trim(),
          if (postId != null && postId.trim().isNotEmpty) 'postId': postId.trim(),
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
      if (map['success'] != true) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: _pickError(map, 'Failed to resolve post'),
        );
      }
      final postRaw = map['post'];
      final post = postRaw is Map<String, dynamic>
          ? postRaw
          : (postRaw is Map ? Map<String, dynamic>.from(postRaw) : <String, dynamic>{});
      return post;
    });
  }

  /// POST /forward – forward an existing message to a user or group.
  Future<ApiResult<Map<String, dynamic>>> forwardMessage({
    required String messageId,
    String? receiverId,
    String? groupId,
  }) async {
    final targetOk = (receiverId != null && receiverId.isNotEmpty) ||
        (groupId != null && groupId.isNotEmpty);
    if (messageId.trim().isEmpty || !targetOk) {
      return ApiResult(success: false, errorMessage: 'Invalid input');
    }

    return _withAuth(() async {
      final response = await _dio.post(
        ApiConstants.chatForward,
        data: {
          'messageId': messageId.trim(),
          if (receiverId != null && receiverId.isNotEmpty) 'receiverId': receiverId,
          if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
      if (map['success'] != true) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: _pickError(map, 'Failed to forward message'),
        );
      }
      return map;
    });
  }

  /// POST /delete – delete message (for me or for everyone).
  Future<ApiResult<Map<String, dynamic>>> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    if (messageId.trim().isEmpty) {
      return ApiResult(success: false, errorMessage: 'Invalid input');
    }

    return _withAuth(() async {
      final response = await _dio.post(
        ApiConstants.chatDelete,
        data: {
          'messageId': messageId.trim(),
          'deleteForEveryone': deleteForEveryone,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
      if (map['success'] != true) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: _pickError(map, 'Failed to delete message'),
        );
      }
      return map;
    });
  }

  /// POST /group/create – create a new group with name and participant ids.
  Future<ApiResult<Map<String, dynamic>>> createGroup({
    required String name,
    String? image,
    String? description,
    required List<String> participantIds,
  }) async {
    final cleaned = participantIds.where((e) => e.trim().isNotEmpty).toList();
    if (name.trim().isEmpty || cleaned.isEmpty) {
      return ApiResult(success: false, errorMessage: 'Invalid input');
    }

    return _withAuth(() async {
      final response = await _dio.post(
        ApiConstants.chatGroupCreate,
        data: {
          'name': name.trim(),
          if (image != null && image.trim().isNotEmpty) 'image': image.trim(),
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
          'participantIds': cleaned,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
      if (map['success'] != true) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: _pickError(map, 'Failed to create group'),
        );
      }
      return map;
    });
  }

  /// GET /group/:groupId/messages – load group chat messages history.
  Future<ApiResult<Map<String, dynamic>>> getGroupMessages(
    String groupId, {
    int limit = 20,
    int skip = 0,
  }) async {
    if (groupId.trim().isEmpty) {
      return ApiResult(success: false, errorMessage: 'Invalid group id');
    }

    return _withAuth(() async {
      final response = await _dio.get(
        ApiConstants.chatGroupMessages(groupId.trim()),
        queryParameters: {'limit': limit, 'skip': skip},
      );
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
      if (map['success'] != true) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: _pickError(map, 'Failed to load group messages'),
        );
      }
      return map;
    });
  }

  /// GET messages for conversation with [userId]. Returns conversationId and messages.
  /// [limit] and [skip] for pagination (e.g. first page limit=20 skip=0, next page skip=20).
  Future<GetUserChatResult> getUserChat(String userId, {int limit = 20, int skip = 0}) async {
    if (userId.isEmpty) {
      return GetUserChatResult(success: false, errorMessage: 'Invalid user id');
    }

    final auth = await _withAuth(() async {
      final response = await _dio.get(
        ApiConstants.chatMessages(userId),
        queryParameters: {'limit': limit, 'skip': skip},
      );
      return response.data;
    });

    if (!auth.success) {
      return GetUserChatResult(success: false, errorMessage: auth.errorMessage);
    }

    final data = auth.data is Map<String, dynamic>
        ? auth.data as Map<String, dynamic>
        : (auth.data is Map ? Map<String, dynamic>.from(auth.data as Map) : null);

    if (data == null || data['success'] != true) {
      return GetUserChatResult(success: false, errorMessage: _pickError(data, 'Failed to load messages'));
    }

    final conversationId = data['conversationId']?.toString();
    final list = data['messages'];
    final messages = <ChatMessageBubble>[];
    if (list is List) {
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          messages.add(ChatMessageBubble.fromJson(e));
        } else if (e is Map) {
          messages.add(ChatMessageBubble.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    return GetUserChatResult(
      success: true,
      conversationId: conversationId,
      messages: messages,
    );
  }

  /// GET all conversations for current user.
  Future<GetConversationsResult> getConversations() async {
    final auth = await _withAuth(() async {
      final response = await _dio.get(ApiConstants.chatConversations);
      return response.data;
    });

    if (!auth.success) {
      return GetConversationsResult(success: false, errorMessage: auth.errorMessage);
    }

    final data = auth.data is Map<String, dynamic>
        ? auth.data as Map<String, dynamic>
        : (auth.data is Map ? Map<String, dynamic>.from(auth.data as Map) : null);

    if (data == null || data['success'] != true) {
      return GetConversationsResult(success: false, errorMessage: _pickError(data, 'Failed to load conversations'));
    }

    final list = data['conversations'];
    final conversations = <ChatConversationItem>[];
    if (list is List) {
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          conversations.add(ChatConversationItem.fromJson(e));
        } else if (e is Map) {
          conversations.add(ChatConversationItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return GetConversationsResult(success: true, conversations: conversations);
  }

  /// GET /shareable-users – users for share sheet (following + recent chats, sorted by recency).
  Future<ApiResult<List<Map<String, dynamic>>>> getShareableUsers() async {
    return _withAuth(() async {
      final response = await _dio.get(ApiConstants.chatShareableUsers);
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
      if (map['success'] != true) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: _pickError(map, 'Failed to load shareable users'),
        );
      }
      final users = map['users'];
      if (users is! List) return <Map<String, dynamic>>[];
      return users
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }
}
