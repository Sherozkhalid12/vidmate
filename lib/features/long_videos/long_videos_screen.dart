import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/post_model.dart';
import '../video/video_player_screen.dart';
import '../profile/profile_screen.dart';

/// Long Videos Page - YouTube-style video feed
class LongVideosScreen extends StatefulWidget {
  const LongVideosScreen({super.key});

  @override
  State<LongVideosScreen> createState() => _LongVideosScreenState();
}

class _LongVideosScreenState extends State<LongVideosScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<PostModel> _videos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadVideos() {
    setState(() {
      _isLoading = true;
    });

    // Get only video posts
    final allPosts = MockDataService.getMockPosts();
    final videoPosts = allPosts.where((p) => p.isVideo).toList();
    
    // Add more mock videos for better feed
    final additionalVideos = List.generate(10, (index) {
      final userIndex = index % MockDataService.mockUsers.length;
      return PostModel(
        id: 'video_${index + 10}',
        author: MockDataService.mockUsers[userIndex],
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        thumbnailUrl: 'https://picsum.photos/800/450?random=${index + 100}',
        caption: 'Amazing video content ${index + 1}',
        createdAt: DateTime.now().subtract(Duration(hours: index)),
        likes: (index + 1) * 1000,
        comments: (index + 1) * 50,
        shares: (index + 1) * 20,
        isLiked: false,
        videoDuration: Duration(minutes: index % 10 + 1, seconds: (index * 7) % 60),
        isVideo: true,
      );
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _videos.clear();
          _videos.addAll(videoPosts);
          _videos.addAll(additionalVideos);
          _isLoading = false;
        });
      }
    });
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
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Header - matching image design
            _buildHeader(),
            // Video Feed
            Expanded(
              child: _isLoading && _videos.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ThemeHelper.getAccentColor(context),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _loadVideos();
                      },
                      color: ThemeHelper.getAccentColor(context),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          return _buildVideoCard(_videos[index]);
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
          const Spacer(),
          // Search icon (optional, can be removed)
          Icon(
            Icons.search,
            color: ThemeHelper.getTextSecondary(context),
            size: 24,
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
          // Video Thumbnail
          GestureDetector(
            onTap: () {
              if (video.videoUrl != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoUrl: video.videoUrl!,
                      title: video.caption,
                      author: video.author,
                      post: video,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              children: [
                // Thumbnail Image
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
                // Play Button Overlay
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                // Video Duration Badge
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
          ),
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
}

