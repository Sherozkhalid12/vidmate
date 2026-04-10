import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/message_model.dart';
import '../../core/models/chat_conversation_api.dart';
import '../../core/models/music_model.dart';
import 'hive_content_store.dart';
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
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final seen = await _getSeenIds(_seenPostIdsPrefix, uid);
    final unseen = posts.where((p) => !seen.contains(p.id)).take(10).toList();
    final map = await _readUserMap(uid);
    map['posts'] = unseen.map(_postToMap).toList();
    map['postsUpdatedAt'] = DateTime.now().toIso8601String();
    await _writeUserMap(uid, map);
    final fullMaps = posts.map(_postToMap).toList();
    try {
      if (HiveContentStore.instance.isReady) {
        await HiveContentStore.instance.savePosts(fullMaps);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[UserStorage] cacheUnseenFeed Hive write failed: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> cacheUnseenReels({
    required List<PostModel> reels,
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final seen = await _getSeenIds(_seenReelIdsPrefix, uid);
    final unseen = reels.where((p) => !seen.contains(p.id)).take(10).toList();
    final map = await _readUserMap(uid);
    map['reels'] = unseen.map(_postToMap).toList();
    map['reelsUpdatedAt'] = DateTime.now().toIso8601String();
    await _writeUserMap(uid, map);
    try {
      if (HiveContentStore.instance.isReady) {
        await HiveContentStore.instance.saveReels(reels.map(_postToMap).toList());
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[UserStorage] cacheUnseenReels Hive write failed: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> cacheUnseenLongVideos({
    required List<PostModel> videos,
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final seen = await _getSeenIds(_seenLongVideoIdsPrefix, uid);
    final unseen = videos.where((p) => !seen.contains(p.id)).take(10).toList();
    final map = await _readUserMap(uid);
    map['longVideos'] = unseen.map(_postToMap).toList();
    map['longVideosUpdatedAt'] = DateTime.now().toIso8601String();
    await _writeUserMap(uid, map);
    try {
      if (HiveContentStore.instance.isReady) {
        await HiveContentStore.instance.saveLongVideos(videos.map(_postToMap).toList());
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[UserStorage] cacheUnseenLongVideos Hive write failed: $e');
        debugPrint('$st');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getCachedUnseenPosts({
    String? userId,
  }) async {
    try {
      if (HiveContentStore.instance.isReady) {
        final fromHive = HiveContentStore.instance.postsMaps;
        if (fromHive.isNotEmpty) return fromHive;
      }
    } catch (_) {}
    return _getCachedSection('posts', userId: userId);
  }

  Future<List<Map<String, dynamic>>> getCachedUnseenReels({
    String? userId,
  }) async {
    try {
      if (HiveContentStore.instance.isReady) {
        final fromHive = HiveContentStore.instance.reelsMaps;
        if (fromHive.isNotEmpty) return fromHive;
      }
    } catch (_) {}
    return _getCachedSection('reels', userId: userId);
  }

  Future<List<Map<String, dynamic>>> getCachedUnseenLongVideos({
    String? userId,
  }) async {
    try {
      if (HiveContentStore.instance.isReady) {
        final fromHive = HiveContentStore.instance.longVideosMaps;
        if (fromHive.isNotEmpty) return fromHive;
      }
    } catch (_) {}
    return _getCachedSection('longVideos', userId: userId);
  }

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

  Future<int?> getDominantColorArgb(String postId) async {
    try {
      return HiveContentStore.instance.getDominantColorArgb(postId);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDominantColorArgb(String postId, int argb) async {
    try {
      await HiveContentStore.instance.setDominantColorArgb(postId, argb);
    } catch (_) {}
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

  static const String _conversationsCacheKey = 'conversationsCacheV1';
  static const String _musicLibraryCacheKey = 'musicLibraryCacheV1';

  /// Cached chat list for instant tray (current user only).
  Future<void> cacheConversationsSnapshot({
    required List<ChatConversationItem> items,
    required Set<String> unreadConversationIds,
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final map = await _readUserMap(uid);
    map[_conversationsCacheKey] = {
      'items': items.map((e) => e.toJson()).toList(),
      'unreadIds': unreadConversationIds.toList(),
    };
    await _writeUserMap(uid, map);
  }

  Future<({List<ChatConversationItem> items, Set<String> unreadIds})>
      getCachedConversationsSnapshot({String? userId}) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) {
      return (items: const <ChatConversationItem>[], unreadIds: <String>{});
    }
    final map = await _readUserMap(uid);
    final raw = map[_conversationsCacheKey];
    if (raw is! Map) {
      return (items: const <ChatConversationItem>[], unreadIds: <String>{});
    }
    final list = raw['items'];
    final unreadRaw = raw['unreadIds'];
    final items = <ChatConversationItem>[];
    if (list is List) {
      for (final e in list) {
        if (e is! Map) continue;
        try {
          items.add(ChatConversationItem.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
    final unread = unreadRaw is List
        ? unreadRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet()
        : <String>{};
    return (items: items, unreadIds: unread);
  }

  /// First page of music list (same user prefs bucket as rest of app data).
  Future<void> cacheMusicLibraryPage1({
    required List<MusicModel> tracks,
    required int total,
    required int page,
    required bool hasMore,
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return;
    final map = await _readUserMap(uid);
    map[_musicLibraryCacheKey] = {
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'total': total,
      'page': page,
      'hasMore': hasMore,
    };
    await _writeUserMap(uid, map);
  }

  Future<({List<MusicModel> tracks, int total, int page, bool hasMore})?>
      getCachedMusicLibraryPage1({String? userId}) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty) return null;
    final map = await _readUserMap(uid);
    final raw = map[_musicLibraryCacheKey];
    if (raw is! Map) return null;
    final list = raw['tracks'];
    if (list is! List) return null;
    final tracks = <MusicModel>[];
    for (final e in list) {
      if (e is! Map) continue;
      try {
        tracks.add(MusicModel.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    final total = (raw['total'] is num) ? (raw['total'] as num).toInt() : 0;
    final page = (raw['page'] is num) ? (raw['page'] as num).toInt() : 1;
    final hasMore = raw['hasMore'] == true;
    return (tracks: tracks, total: total, page: page, hasMore: hasMore);
  }

  String _profilePostsKey(String profileUserId) =>
      'profilePosts_${profileUserId.trim()}';

  Future<void> cacheProfileUserPosts(
    String profileUserId,
    List<PostModel> posts, {
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty || profileUserId.trim().isEmpty) return;
    final map = await _readUserMap(uid);
    map[_profilePostsKey(profileUserId)] =
        posts.map(_postToMap).toList();
    await _writeUserMap(uid, map);
  }

  Future<List<PostModel>> getCachedProfileUserPosts(
    String profileUserId, {
    String? userId,
  }) async {
    final uid = await _resolveUserId(userId);
    if (uid == null || uid.isEmpty || profileUserId.trim().isEmpty) {
      return const [];
    }
    final map = await _readUserMap(uid);
    final raw = map[_profilePostsKey(profileUserId)];
    if (raw is! List) return const [];
    final out = <PostModel>[];
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        out.add(PostModel.fromCachedMap(Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    return out;
  }

  Map<String, dynamic> _postToMap(PostModel p) {
    return {
      'id': p.id,
      'author': {
        'id': p.author.id,
        'username': p.author.username,
        'displayName': p.author.displayName,
        'avatarUrl': p.author.avatarUrl,
        'verified': p.author.verified,
        'privateAccount': p.author.privateAccount,
        'showActivityStatus': p.author.showActivityStatus,
        'allowComments': p.author.allowComments,
        'allowLikes': p.author.allowLikes,
        'allowShares': p.author.allowShares,
        'allowStoryReplies': p.author.allowStoryReplies,
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
      if (p.videoDuration != null) 'videoDurationMs': p.videoDuration!.inMilliseconds,
      if (p.audioId != null) 'audioId': p.audioId,
      if (p.audioName != null) 'audioName': p.audioName,
      if (p.blurHash != null) 'blurHash': p.blurHash,
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
