import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/models/post_model.dart';
import '../video/video_player_screen.dart';
import '../profile/profile_screen.dart';
import 'providers/long_videos_provider.dart';

/// Long Videos Page - YouTube-style video feed with Riverpod state management
class LongVideosScreen extends ConsumerStatefulWidget {
  const LongVideosScreen({super.key});

  @override
  ConsumerState<LongVideosScreen> createState() => _LongVideosScreenState();
}

class _LongVideosScreenState extends ConsumerState<LongVideosScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      final notifier = ref.read(longVideosProvider.notifier);
      notifier.loadMoreVideos();
    }
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M views';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K views';
    }
    return '$views views';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final videosState = ref.watch(longVideosProvider);
    final videos = ref.watch(longVideosListProvider);
    final isLoading = ref.watch(longVideosLoadingProvider);
    final error = ref.watch(longVideosErrorProvider);

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Header
            _buildHeader(),
            // Video Feed
            Expanded(
              child: error != null && videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading videos',
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(longVideosProvider.notifier).loadVideos(refresh: true);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : isLoading && videos.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(
                            color: ThemeHelper.getAccentColor(context),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await ref
                                .read(longVideosProvider.notifier)
                                .loadVideos(refresh: true);
                          },
                          color: ThemeHelper.getAccentColor(context),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: videos.length + (isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == videos.length) {
                                // Loading indicator at the bottom
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return _buildVideoCard(videos[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ThemeHelper.getBackgroundColor(context),
        border: Border(
          bottom: BorderSide(
            color: ThemeHelper.getBorderColor(context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // App Logo/Name
          Text(
            'VidConnect',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(PostModel video) {
    final views = video.likes * 10; // Convert likes to views for display
    final formattedViews = _formatViews(views);
    final timeAgo = _formatTimeAgo(video.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      color: ThemeHelper.getBackgroundColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Profile Picture - Clickable
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(user: video.author),
                      ),
                    );
                  },
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: video.author.avatarUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 40,
                        height: 40,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ThemeHelper.getAccentColor(context),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 40,
                        height: 40,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Icon(
                          Icons.person,
                          color: ThemeHelper.getTextSecondary(context),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User Name and Views - Clickable
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(user: video.author),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.author.displayName,
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$formattedViews • $timeAgo',
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Follow Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeHelper.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Follow',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Video Player/Thumbnail
          _buildVideoPlayer(video),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildVideoPlayer(PostModel video) {
    final videoUrl = video.videoUrl;
    
    if (videoUrl == null) {
      return Container(
        width: double.infinity,
        height: 220,
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(
          Icons.video_library,
          color: ThemeHelper.getTextSecondary(context),
          size: 48,
        ),
      );
    }

    // Show thumbnail only - no play icon overlay
    return GestureDetector(
      onTap: () {
        // Navigate to Main Video Player Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: videoUrl,
              title: video.caption,
              author: video.author,
              post: video,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: video.thumbnailUrl ?? video.imageUrl ?? '',
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: 220,
              color: ThemeHelper.getSurfaceColor(context),
              child: Center(
                child: CircularProgressIndicator(
                  color: ThemeHelper.getAccentColor(context),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity,
              height: 220,
              color: ThemeHelper.getSurfaceColor(context),
              child: Icon(
                Icons.video_library,
                color: ThemeHelper.getTextSecondary(context),
                size: 48,
              ),
            ),
          ),
          // Duration badge only
          if (video.videoDuration != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(video.videoDuration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}

