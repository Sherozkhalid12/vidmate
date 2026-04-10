import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/media/app_media_cache.dart';
import '../../core/models/post_model.dart';
import '../posts/long_video_service.dart';
import '../posts/posts_service.dart';
import '../posts/reels_service.dart';
import '../posts/stories_service.dart';
import '../storage/hive_content_store.dart';
import '../storage/user_storage_service.dart';

class ContentPrefetchWorkmanager {
  static const String periodicTaskName = 'content_prefetch_periodic';
  static const String onDemandTaskName = 'content_prefetch_on_demand';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    // Never use isInDebugMode: true — Android shows a system notification for every
    // worker run/failure (e.g. 👷 content_prefetch_on_demand), which users see as spam.
    await Workmanager().initialize(_callbackDispatcher, isInDebugMode: false);
    _initialized = true;
  }

  static Future<void> schedule() async {
    await Workmanager().registerPeriodicTask(
      periodicTaskName,
      periodicTaskName,
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> triggerNow() async {
    await Workmanager().registerOneOffTask(
      '${onDemandTaskName}_${DateTime.now().millisecondsSinceEpoch}',
      onDemandTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  @pragma('vm:entry-point')
  static void _callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await HiveContentStore.instance.init();

        final postsResult = await PostsService().getPosts();
        if (postsResult.success && postsResult.posts.isNotEmpty) {
          final posts = postsResult.posts
              .map((p) => PostModel.fromApiPost(
                    p.post,
                    p.author ?? PostModel.authorPlaceholder(p.post.userId),
                  ))
              .toList();
          await UserStorageService.instance.cacheUnseenFeed(posts: posts);
        }
        if (!postsResult.success) {
          await _warmGuestEndpoints();
        }

        final reelsResult = await ReelsService().getReels();
        if (reelsResult.success && reelsResult.reels.isNotEmpty) {
          final reels = reelsResult.reels.map((r) => PostModel.fromReel(r)).toList();
          await UserStorageService.instance.cacheUnseenReels(reels: reels);
          // Warm first 3 reel thumbnails on disk to reduce first-open grey/loading perception.
          for (final r in reels.take(3)) {
            final u = (r.effectiveThumbnailUrl ?? r.thumbnailUrl ?? '').trim();
            if (u.isEmpty) continue;
            try {
              await AppMediaCache.reelsThumbnails.downloadFile(u);
            } catch (_) {}
          }
        }

        final longResult = await LongVideoService().getLongVideos();
        if (longResult.success && longResult.videos.isNotEmpty) {
          final videos = longResult.videos.map((v) => PostModel.fromLongVideo(v)).toList();
          await UserStorageService.instance.cacheUnseenLongVideos(videos: videos);
        }

        // Stories are fetched in background so API/session stays warm.
        await StoriesService().getStories();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[Workmanager][prefetch] $e');
          debugPrint('$st');
        }
      }
      return Future.value(true);
    });
  }

  static Future<void> _warmGuestEndpoints() async {
    final dio = DioClient.instance;
    final endpoints = <String>[
      ApiConstants.postList,
      ApiConstants.reelList,
      ApiConstants.storyList,
      ApiConstants.longVideoList,
    ];
    for (final endpoint in endpoints) {
      try {
        await dio.get(
          endpoint,
          options: Options(
            headers: const {'Cache-Control': 'no-cache'},
            extra: const {'noCache': true},
          ),
        );
      } catch (_) {
        // Not authenticated/publicly blocked endpoints are expected for guests.
      }
    }
  }
}
