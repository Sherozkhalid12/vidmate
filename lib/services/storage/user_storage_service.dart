import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/message_model.dart';
import '../../core/models/post_model.dart';
import '../../core/models/user_preferences_model.dart';
import '../notifications/notifications_service.dart';

class UserStorageService {
  UserStorageService._();
  static final UserStorageService instance = UserStorageService._();

  static const String _currentUserIdKey = 'storage.currentUserId';
  static const String _userMapPrefix = 'storage.user.map.';
  static const String _seenPostIdsPrefix = 'storage.seen.posts.';
  static const String _seenReelIdsPrefix = 'storage.seen.reels.';
  static const String _seenLongVideoIdsPrefix = 'storage.seen.longVideos.';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> setCurrentUserId(String userId) async {
    final prefs = await _prefs;
    await prefs.setString(_currentUserIdKey, userId);
  }

  Future<String?> getCurrentUserId() async {
    final prefs = await _prefs;
    return prefs.getString(_currentUserIdKey);
  }

  Future<void> clearCurrentUserContext() async {
    final prefs = await _prefs;
    await prefs.remove(_currentUserIdKey);
  }

  Future<String?> _resolveUserId([String? userId]) async {
    if (userId != null && userId.isNotEmpty) return userId;
    return getCurrentUserId();
  }

  Future<Map<String, dynamic>> _readUserMap(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_userMapPrefix$userId');
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeUserMap(String userId, Map<String, dynamic> value) async {
    final prefs = await _prefs;
    await prefs.setString('$_userMapPrefix$userId', jsonEncode(value));
  }

  Future<Map<String, dynamic>?> getCurrentUserMap([String? userId]) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return null;
    final map = await _readUserMap(uid);
    return map.isEmpty ? null : map;
  }

  Future<void> saveCurrentUserProfile(
    Map<String, dynamic> userJson, {
    String? userId,
  }) async {
    final uid = userId ?? (userJson['_id'] ?? userJson['id'])?.toString();
    if (uid == null || uid.isEmpty) return;
    await setCurrentUserId(uid);
    final map = await _readUserMap(uid);
    map['user'] = userJson;
    map['logout'] = false;
    await _writeUserMap(uid, map);
  }

  Future<void> markLoggedOut({String? userId}) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final map = await _readUserMap(uid);
    map['logout'] = true;
    map['logoutAt'] = DateTime.now().toIso8601String();
    await _writeUserMap(uid, map);
  }

  Future<void> savePreferences(
    UserPreferencesModel preferences, {
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final map = await _readUserMap(uid);
    map['preferences'] = preferences.toJson();
    map['preferencesUpdatedAt'] = DateTime.now().toIso8601String();
    await _writeUserMap(uid, map);
  }

  Future<UserPreferencesModel> getPreferences({String? userId}) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return const UserPreferencesModel();
    final map = await _readUserMap(uid);
    final json = map['preferences'];
    return UserPreferencesModel.fromJson(
      json is Map<String, dynamic> ? json : null,
    );
  }

  Future<void> cacheLatestNotifications(
    List<NotificationItem> notifications, {
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final map = await _readUserMap(uid);
    final trimmed = notifications.take(5).map((n) {
      return {
        'id': n.id,
        'userId': n.userId,
        'fromUserId': n.fromUserId,
        'title': n.title,
        'body': n.body,
        'type': n.type,
        'data': n.data,
        'isRead': n.isRead,
        'createdAt': n.createdAt.toIso8601String(),
        'updatedAt': n.updatedAt.toIso8601String(),
      };
    }).toList();
    map['latestNotifications'] = trimmed;
    await _writeUserMap(uid, map);
  }

  Future<List<NotificationItem>> getLatestNotifications({String? userId}) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return const [];
    final map = await _readUserMap(uid);
    final list = map['latestNotifications'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> cacheLastMessagesForChat(
    String peerUserId,
    List<MessageModel> messages, {
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty || peerUserId.isEmpty) return;
    final map = await _readUserMap(uid);
    final chats = Map<String, dynamic>.from(
      map['chatMessages'] as Map? ?? <String, dynamic>{},
    );
    chats[peerUserId] = messages.take(20).map((m) {
      return {
        'id': m.id,
        'sender': {
          'id': m.sender.id,
          'username': m.sender.username,
          'displayName': m.sender.displayName,
          'avatarUrl': m.sender.avatarUrl,
        },
        'text': m.text,
        'mediaUrl': m.mediaUrl,
        'timestamp': m.timestamp.toIso8601String(),
        'isRead': m.isRead,
        'type': m.type.name,
      };
    }).toList();
    map['chatMessages'] = chats;
    await _writeUserMap(uid, map);
  }

  Future<List<Map<String, dynamic>>> getCachedMessagesForChat(
    String peerUserId, {
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty || peerUserId.isEmpty) return const [];
    final map = await _readUserMap(uid);
    final chats = map['chatMessages'];
    if (chats is! Map) return const [];
    final messages = chats[peerUserId];
    if (messages is! List) return const [];
    return messages
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> cacheUnseenFeed({
    required List<PostModel> posts,
    String? userId,
  }) async {
    await _cacheUnseenContent(
      section: 'posts',
      seenKeyPrefix: _seenPostIdsPrefix,
      items: posts,
      userId: userId,
    );
  }

  Future<void> cacheUnseenReels({
    required List<PostModel> reels,
    String? userId,
  }) async {
    await _cacheUnseenContent(
      section: 'reels',
      seenKeyPrefix: _seenReelIdsPrefix,
      items: reels,
      userId: userId,
    );
  }

  Future<void> cacheUnseenLongVideos({
    required List<PostModel> videos,
    String? userId,
  }) async {
    await _cacheUnseenContent(
      section: 'longVideos',
      seenKeyPrefix: _seenLongVideoIdsPrefix,
      items: videos,
      userId: userId,
    );
  }

  Future<void> _cacheUnseenContent({
    required String section,
    required String seenKeyPrefix,
    required List<PostModel> items,
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final seen = await _getSeenIds(seenKeyPrefix, uid);
    final unseen = items.where((p) => !seen.contains(p.id)).take(10).toList();
    final map = await _readUserMap(uid);
    map[section] = unseen.map(_postToMap).toList();
    map['${section}UpdatedAt'] = DateTime.now().toIso8601String();
    await _writeUserMap(uid, map);
  }

  Future<List<Map<String, dynamic>>> getCachedUnseenPosts({
    String? userId,
  }) =>
      _getCachedSection('posts', userId: userId);

  Future<List<Map<String, dynamic>>> getCachedUnseenReels({
    String? userId,
  }) =>
      _getCachedSection('reels', userId: userId);

  Future<List<Map<String, dynamic>>> getCachedUnseenLongVideos({
    String? userId,
  }) =>
      _getCachedSection('longVideos', userId: userId);

  Future<List<Map<String, dynamic>>> _getCachedSection(
    String key, {
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return const [];
    final map = await _readUserMap(uid);
    final list = map[key];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> markPostSeen(String postId, {String? userId}) async {
    await _markSeen(_seenPostIdsPrefix, postId, userId: userId);
  }

  Future<void> markReelSeen(String reelId, {String? userId}) async {
    await _markSeen(_seenReelIdsPrefix, reelId, userId: userId);
  }

  Future<void> markLongVideoSeen(String videoId, {String? userId}) async {
    await _markSeen(_seenLongVideoIdsPrefix, videoId, userId: userId);
  }

  Future<void> _markSeen(
    String keyPrefix,
    String contentId, {
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty || contentId.isEmpty) return;
    final prefs = await _prefs;
    final key = '$keyPrefix$uid';
    final list = prefs.getStringList(key) ?? <String>[];
    if (list.contains(contentId)) return;
    list.add(contentId);
    final trimmed = list.length > 500 ? list.sublist(list.length - 500) : list;
    await prefs.setStringList(key, trimmed);
  }

  Future<Set<String>> _getSeenIds(String keyPrefix, String userId) async {
    final prefs = await _prefs;
    return (prefs.getStringList('$keyPrefix$userId') ?? const []).toSet();
  }

  Map<String, dynamic> _postToMap(PostModel p) {
    return {
      'id': p.id,
      'author': {
        'id': p.author.id,
        'username': p.author.username,
        'displayName': p.author.displayName,
        'avatarUrl': p.author.avatarUrl,
      },
      'imageUrl': p.imageUrl,
      'imageUrls': p.imageUrls,
      'videoUrl': p.videoUrl,
      'thumbnailUrl': p.thumbnailUrl,
      'caption': p.caption,
      'createdAt': p.createdAt.toIso8601String(),
      'likes': p.likes,
      'comments': p.comments,
      'shares': p.shares,
      'isLiked': p.isLiked,
      'isVideo': p.isVideo,
      'postType': p.postType,
    };
  }

  void runInBackground(Future<void> Function() task) {
    unawaited(Future<void>(() async {
      try {
        await task();
      } catch (_) {}
    }));
  }
}
