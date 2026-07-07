import '../utils/video_thumbnail_helper.dart';

/// API chat message (returned by send/share/forward/history APIs).
class ChatMessageBubble {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String groupId;
  final String message;
  final String messageType;
  final List<ChatAttachment> attachments;
  final String sharedPostId;
  final PostPreview? sharedPostData;
  final String forwardedFrom;
  final List<String> readBy;
  final List<String> deletedFor;
  final bool isDeletedForEveryone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String senderProfilePicture;
  final ChatSenderPreview? sender;

  ChatMessageBubble({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.groupId,
    required this.message,
    required this.messageType,
    this.attachments = const [],
    this.sharedPostId = '',
    this.sharedPostData,
    this.forwardedFrom = '',
    this.readBy = const [],
    this.deletedFor = const [],
    this.isDeletedForEveryone = false,
    required this.createdAt,
    required this.updatedAt,
    this.version = 0,
    this.senderProfilePicture = '',
    this.sender,
  });

  static String _str(dynamic v) => v?.toString() ?? '';

  static DateTime _date(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    final parsed = DateTime.tryParse(v.toString());
    return parsed ?? DateTime.now();
  }

  static List<String> _strList(dynamic v) {
    if (v == null || v is! List) return const [];
    return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }

  static bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static List<ChatAttachment> _attachments(dynamic v) {
    if (v is! List) return const [];
    final out = <ChatAttachment>[];
    for (final e in v) {
      if (e is Map<String, dynamic>) {
        out.add(ChatAttachment.fromJson(e));
      } else if (e is Map) {
        out.add(ChatAttachment.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  factory ChatMessageBubble.fromJson(Map<String, dynamic> json) {
    final messageType = _str(json['messageType'] ?? json['type'] ?? 'text');
    final message = _str(json['message'] ?? json['text'] ?? json['content']);
    final id = _str(json['_id'] ?? json['id'] ?? json['messageId']);
    final sharedPostDataJson = json['sharedPostData'];
    final senderJson = json['sender'];

    return ChatMessageBubble(
      id: id.isNotEmpty ? id : 'socket-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _str(json['conversationId'] ?? json['conversation_id']),
      senderId: _str(json['senderId'] ?? json['sender_id'] ?? json['from']),
      receiverId: _str(json['receiverId'] ?? json['receiver_id']),
      groupId: _str(json['groupId'] ?? json['group_id']),
      message: message,
      messageType: messageType.isNotEmpty ? messageType : 'text',
      attachments: _attachments(json['attachments']),
      sharedPostId: _str(json['sharedPostId']),
      sharedPostData: sharedPostDataJson is Map<String, dynamic>
          ? PostPreview.fromJson(sharedPostDataJson)
          : (sharedPostDataJson is Map
              ? PostPreview.fromJson(Map<String, dynamic>.from(sharedPostDataJson))
              : null),
      forwardedFrom: _str(json['forwardedFrom']),
      readBy: _strList(json['readBy'] ?? json['read_by']),
      deletedFor: _strList(json['deletedFor']),
      isDeletedForEveryone: _bool(json['isDeletedForEveryone']),
      createdAt: _date(json['createdAt'] ?? json['created_at'] ?? json['timestamp']),
      updatedAt: _date(json['updatedAt'] ?? json['updated_at'] ?? json['createdAt'] ?? json['created_at']),
      version: _int(json['__v']),
      senderProfilePicture: _str(
        json['senderProfilePicture'] ??
            json['sender_profile_picture'] ??
            json['senderPhoto'] ??
            json['senderAvatar'] ??
            json['senderImage'],
      ),
      sender: senderJson is Map<String, dynamic>
          ? ChatSenderPreview.fromJson(senderJson)
          : (senderJson is Map
              ? ChatSenderPreview.fromJson(Map<String, dynamic>.from(senderJson))
              : null),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'receiverId': receiverId,
        'groupId': groupId,
        'message': message,
        'messageType': messageType,
        if (attachments.isNotEmpty) 'attachments': attachments.map((e) => e.toJson()).toList(),
        if (sharedPostId.isNotEmpty) 'sharedPostId': sharedPostId,
        if (sharedPostData != null) 'sharedPostData': sharedPostData!.toJson(),
        if (forwardedFrom.isNotEmpty) 'forwardedFrom': forwardedFrom,
        'readBy': readBy,
        if (deletedFor.isNotEmpty) 'deletedFor': deletedFor,
        'isDeletedForEveryone': isDeletedForEveryone,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        '__v': version,
        if (senderProfilePicture.isNotEmpty) 'senderProfilePicture': senderProfilePicture,
        if (sender != null) 'sender': sender!.toJson(),
      };
}

class ChatAttachment {
  final String mediaType; // image|video
  final String url;

  const ChatAttachment({
    required this.mediaType,
    required this.url,
  });

  static String _str(dynamic v) => v?.toString() ?? '';

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      mediaType: _str(json['mediaType'] ?? json['type']),
      url: _str(json['url'] ?? json['link']),
    );
  }

  Map<String, dynamic> toJson() => {
        'mediaType': mediaType,
        'url': url,
      };
}

class ChatSenderPreview {
  final String id;
  final String username;
  final String profilePicture;

  const ChatSenderPreview({
    required this.id,
    required this.username,
    required this.profilePicture,
  });

  static String _str(dynamic v) => v?.toString() ?? '';

  factory ChatSenderPreview.fromJson(Map<String, dynamic> json) {
    return ChatSenderPreview(
      id: _str(json['id'] ?? json['_id']),
      username: _str(json['username'] ?? json['name'] ?? json['displayName']),
      profilePicture: _str(
        json['profilePicture'] ??
            json['profile_picture'] ??
            json['avatarUrl'] ??
            json['avatar'] ??
            json['image'] ??
            json['photo'] ??
            json['picture'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'profilePicture': profilePicture,
      };
}

/// Post preview returned by `/resolve-post` and embedded in `sharedPostData`.
class PostPreview {
  final String id;
  final String userId;
  final String caption;
  final List<String> images;
  final String video;
  final String thumbnailUrl;
  final String music;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final DateTime? createdAt;
  final String type;
  final Map<String, dynamic>? user;

  const PostPreview({
    required this.id,
    required this.userId,
    required this.caption,
    this.images = const [],
    this.video = '',
    this.thumbnailUrl = '',
    this.music = '',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.createdAt,
    this.type = '',
    this.user,
  });

  static String _str(dynamic v) => v?.toString() ?? '';
  static int _int(dynamic v) => v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);

  static DateTime? _dateOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return DateTime.tryParse(s);
  }

  static List<String> _strList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }

  String get effectiveVideoUrl {
    final v = video.trim();
    if (v.isNotEmpty) return v;
    return '';
  }

  String? get effectiveThumbnailUrl {
    final typeLower = type.toLowerCase();
    final isLongVideo =
        typeLower == 'longvideo' || typeLower == 'long_video';
    final isReel = typeLower == 'reel';
    final thumb = thumbnailUrl.trim();
    final generated = effectiveVideoUrl.isNotEmpty
        ? VideoThumbnailHelper.thumbnailFromVideoUrl(effectiveVideoUrl)
        : null;

    if (isLongVideo) {
      if (thumb.isNotEmpty) return thumb;
      if (images.isNotEmpty) return images.first;
      return generated;
    }

    if (isReel || effectiveVideoUrl.isNotEmpty) {
      if (thumb.isNotEmpty && !thumb.contains('/posts/videos/')) {
        return thumb;
      }
      if (generated != null && generated.isNotEmpty) return generated;
      if (thumb.isNotEmpty) return thumb;
    }

    if (thumb.isNotEmpty) return thumb;
    if (images.isNotEmpty) return images.first;
    return null;
  }

  factory PostPreview.fromJson(Map<String, dynamic> json) {
    final nested = json['post'];
    final source = nested is Map<String, dynamic>
        ? nested
        : (nested is Map ? Map<String, dynamic>.from(nested) : json);

    final vid = _str(
      source['video'] ??
          source['videoUrl'] ??
          source['video_url'] ??
          source['videoMasterUrl'] ??
          source['mediaUrl'],
    );
    final thumb = _str(
      source['thumbnailUrl'] ??
          source['thumbnail'] ??
          source['cover'] ??
          source['coverImage'] ??
          source['thumb'],
    );
    final imageList = _strList(source['images']);
    final singleImage = _str(source['imageUrl'] ?? source['image']);
    final images = imageList.isNotEmpty
        ? imageList
        : (singleImage.isNotEmpty ? [singleImage] : const <String>[]);

    return PostPreview(
      id: _str(source['id'] ?? source['_id'] ?? json['id'] ?? json['_id']),
      userId: _str(source['userId'] ?? source['user_id']),
      caption: _str(source['caption']),
      images: images,
      video: vid,
      thumbnailUrl: thumb,
      music: _str(source['music']),
      likesCount: _int(source['likesCount'] ?? source['likes']),
      commentsCount: _int(source['commentsCount'] ?? source['comments']),
      sharesCount: _int(source['sharesCount'] ?? source['shares']),
      createdAt: _dateOrNull(source['createdAt']),
      type: _str(source['type'] ?? source['postType']),
      user: source['user'] is Map<String, dynamic>
          ? source['user'] as Map<String, dynamic>
          : (source['user'] is Map
              ? Map<String, dynamic>.from(source['user'] as Map)
              : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'caption': caption,
        'images': images,
        'video': video,
        if (thumbnailUrl.isNotEmpty) 'thumbnailUrl': thumbnailUrl,
        'music': music,
        'likesCount': likesCount,
        'commentsCount': commentsCount,
        'sharesCount': sharesCount,
        'createdAt': createdAt?.toIso8601String(),
        'type': type,
        'user': user,
      };
}
