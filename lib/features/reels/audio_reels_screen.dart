import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/comments_bottom_sheet.dart';
import '../../core/widgets/share_bottom_sheet.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../core/models/user_model.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/post_model.dart';

/// Full-screen reels filtered by same audio (Instagram-style "Original sound" flow).
/// Design matches app style; uses generic "Original sound" labels to avoid copyright.
class AudioReelsScreen extends ConsumerStatefulWidget {
  final String audioId;
  final String audioName;
  final List<PostModel> reels;
  final int initialIndex;

  const AudioReelsScreen({
    super.key,
    required this.audioId,
    required this.audioName,
    required this.reels,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<AudioReelsScreen> createState() => _AudioReelsScreenState();
}

class _AudioReelsScreenState extends ConsumerState<AudioReelsScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<String, bool> _likedPosts = {};
  final Map<String, int> _likeCounts = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex.clamp(0, widget.reels.length - 1));
    _currentIndex = widget.initialIndex.clamp(0, widget.reels.length - 1);
    for (var reel in widget.reels) {
      _likedPosts[reel.id] = reel.isLiked;
      _likeCounts[reel.id] = reel.likes;
    }
    _initializeVideo(_currentIndex);
    if (_currentIndex + 1 < widget.reels.length) _initializeVideo(_currentIndex + 1);
    if (_currentIndex + 2 < widget.reels.length) _initializeVideo(_currentIndex + 2);
    if (_currentIndex - 1 >= 0) _initializeVideo(_currentIndex - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initializeVideo(int index) {
    if (index < 0 || index >= widget.reels.length) return;
    if (_controllers.containsKey(index)) return;
    final reel = widget.reels[index];
    if (reel.videoUrl == null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(reel.videoUrl!))..setLooping(true);
    _controllers[index] = controller;
    controller.initialize().then((_) {
      if (!mounted || !_controllers.containsKey(index)) return;
      if (index == _currentIndex) {
        try { controller.play(); } catch (_) {}
      }
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() {});
    });
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= widget.reels.length) return;
    for (var c in _controllers.values) {
      if (c.value.isInitialized && c.value.isPlaying) try { c.pause(); } catch (_) {}
    }
    if (_controllers.containsKey(_currentIndex) && _currentIndex != index) {
      try {
        final old = _controllers[_currentIndex]!;
        old.pause();
        old.dispose();
        _controllers.remove(_currentIndex);
      } catch (_) {}
    }
    setState(() { _currentIndex = index; });
    _initializeVideo(index);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_controllers.containsKey(index)) return;
      final c = _controllers[index]!;
      if (c.value.isInitialized && !c.value.isPlaying) try { c.play(); } catch (_) {}
    });
    if (index + 1 < widget.reels.length) _initializeVideo(index + 1);
    if (index + 2 < widget.reels.length) _initializeVideo(index + 2);
    if (index - 1 >= 0) _initializeVideo(index - 1);
    final toRemove = <int>[];
    _controllers.forEach((key, c) {
      if ((key - index).abs() > 3) {
        try { c.pause(); c.dispose(); } catch (_) {}
        toRemove.add(key);
      }
    });
    for (var k in toRemove) _controllers.remove(k);
  }

  void _showReelMoreMenu(BuildContext context, PostModel reel) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(child: const Text('Report'), onPressed: () => Navigator.pop(ctx)),
          CupertinoActionSheetAction(child: const Text('Copy Link'), onPressed: () => Navigator.pop(ctx)),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final reels = widget.reels;
    if (reels.isEmpty) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: ThemeHelper.getBackgroundColor(context),
          foregroundColor: ThemeHelper.getTextPrimary(context),
          elevation: 0,
          title: Text(
            widget.audioName,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_off_rounded, size: 48, color: ThemeHelper.getTextMuted(context)),
              const SizedBox(height: 16),
              Text(
                'No reels with this audio',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.audioName,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: reels.length,
        physics: const ClampingScrollPhysics(),
        itemBuilder: (context, index) {
          if (index < 0 || index >= reels.length) return Container(color: Colors.black);
          return _buildReelItem(reels[index], index);
        },
      ),
    );
  }

  Widget _buildReelItem(PostModel reel, int index) {
    final controller = _controllers[index];
    final isPlaying = controller?.value.isPlaying ?? false;
    final isInitialized = controller?.value.isInitialized ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && isInitialized)
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: Stack(
              children: [
                if (reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty)
                  Center(
                    child: CachedNetworkImage(
                      imageUrl: reel.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                ),
              ],
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: CachedNetworkImageProvider(reel.author.avatarUrl),
                            backgroundColor: Colors.grey[800],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  reel.author.username,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final posts = ref.watch(postsListProvider);
                              final post = posts.firstWhere(
                                (p) => p.author.id == reel.author.id,
                                orElse: () => posts.first,
                              );
                              final isFollowing = post.author.id == reel.author.id ? post.author.isFollowing : reel.author.isFollowing;
                              return GestureDetector(
                                onTap: () => ref.read(postsProvider.notifier).toggleFollow(reel.author.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isFollowing ? Colors.transparent : Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isFollowing ? Colors.white.withOpacity(0.5) : Colors.white,
                                      width: isFollowing ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    isFollowing ? 'Following' : 'Follow',
                                    style: TextStyle(color: isFollowing ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              reel.audioName ?? 'Original sound - ${reel.author.username}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reel.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _action(
                      Icons.favorite,
                      count: _likeCounts[reel.id] ?? reel.likes,
                      isActive: _likedPosts[reel.id] ?? reel.isLiked,
                      onTap: () {
                        setState(() {
                          final cur = _likedPosts[reel.id] ?? reel.isLiked;
                          final cnt = _likeCounts[reel.id] ?? reel.likes;
                          _likedPosts[reel.id] = !cur;
                          _likeCounts[reel.id] = cur ? (cnt - 1).clamp(0, 999999) : cnt + 1;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _action(
                      Icons.comment,
                      count: reel.comments,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => CommentsBottomSheet(postId: reel.id),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => ShareBottomSheet(postId: reel.id, videoUrl: reel.videoUrl, imageUrl: reel.imageUrl),
                        );
                      },
                      child: Column(
                        children: [
                          Transform.rotate(angle: -0.785398, child: const Icon(Icons.send, color: Colors.white, size: 28)),
                          const SizedBox(height: 4),
                          Text(_formatCount(reel.shares), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _action(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      onTap: () {
                        if (controller != null) {
                          if (isPlaying) controller.pause(); else controller.play();
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 8,
          top: 0,
          bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.reels.length, (i) {
              return Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(
                  color: i == _currentIndex
                      ? ThemeHelper.getAccentColor(context)
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: GestureDetector(
            onTap: () => _showReelMoreMenu(context, reel),
            child: const Icon(Icons.more_vert, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _action(
    IconData icon, {
    int? count,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Icon(
            icon,
            color: isActive ? Colors.red : Colors.white,
            size: 28,
          ),
        ),
        if (count != null) ...[
          const SizedBox(height: 4),
          Text(
            _formatCount(count),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
