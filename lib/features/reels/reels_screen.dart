import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/comments_bottom_sheet.dart';
import '../../core/widgets/share_bottom_sheet.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/follow_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../../services/posts/posts_service.dart';
import '../../core/models/user_model.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/reels_provider_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/utils/create_content_visibility.dart';
import '../../core/utils/share_link_helper.dart';
import 'audio_detail_screen.dart';
import 'audio_reels_screen.dart';

/// Reels screen with full-screen vertical swipe videos.
/// When [prependedReel] is set (from home feed), this reel is shown first, then the rest from API.
/// When [initialPostId] is set, finds that reel in the list and opens at it. Shows back button when opened as a route.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key, this.initialPostId, this.prependedReel});

  final String? initialPostId;
  /// When set, this reel is shown first (tapped video from home), then reels from API. Takes precedence over initialPostId.
  final PostModel? prependedReel;

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<String, bool> _savedReels = {}; // Track saved/bookmarked reels
  bool _hasAppliedInitialPostId = false;

  @override
  void initState() {
    super.initState();
    createContentVisibleNotifier.addListener(_onCreateContentVisibilityChanged);
  }

  void _onCreateContentVisibilityChanged() {
    if (createContentVisibleNotifier.value) {
      _pauseAndDisposeAllVideos();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    createContentVisibleNotifier.removeListener(_onCreateContentVisibilityChanged);
    _pageController.dispose();
    _pauseAndDisposeAllVideos();
    super.dispose();
  }

  /// Pause and dispose all reel videos (e.g. when opening AudioDetailScreen or CreateContentScreen)
  void _pauseAndDisposeAllVideos() {
    for (var entry in _controllers.entries.toList()) {
      try {
        final controller = entry.value;
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
        controller.dispose();
      } catch (_) {}
      _controllers.remove(entry.key);
    }
  }

  void _initVideosForList(List<PostModel> reels) {
    _initializeVideo(0, reels);
    if (reels.length > 1) _initializeVideo(1, reels);
    if (reels.length > 2) _initializeVideo(2, reels);
  }

  void _initializeVideo(int index, List<PostModel> reels) {
    if (index < 0 || index >= reels.length) return;
    if (_controllers.containsKey(index)) {
      if (index == _currentIndex && _controllers[index]!.value.isInitialized) {
        if (!_controllers[index]!.value.isPlaying) {
          try {
            _controllers[index]!.play();
          } catch (e) {}
        }
      }
      return;
    }

    final reel = reels[index];
    if (reel.videoUrl != null) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(reel.videoUrl!),
      )..setLooping(true);

      _controllers[index] = controller;

      // Initialize asynchronously without blocking UI
      controller.initialize().then((_) {
        if (mounted && _controllers.containsKey(index)) {
          // Only play if this is still the current index
          if (index == _currentIndex) {
            try {
              controller.play();
            } catch (e) {
              // Ignore play errors
            }
          }
          if (mounted) {
            setState(() {});
          }
        }
      }).catchError((error) {
        // Handle error silently, UI will show loading state
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onPageChanged(int index, List<PostModel> reels) {
    if (index < 0 || index >= reels.length) return;

    // Pause ALL videos first (YouTube/Instagram style - only one plays at a time)
    for (var entry in _controllers.entries) {
      final controller = entry.value;
      if (controller.value.isInitialized && controller.value.isPlaying) {
        try {
          controller.pause();
        } catch (e) {
          // Ignore errors during pause
        }
      }
    }

    // Dispose previous video controller to free resources immediately
    if (_controllers.containsKey(_currentIndex) && _currentIndex != index) {
      try {
        final oldController = _controllers[_currentIndex];
        if (oldController != null) {
          oldController.removeListener(() {});
          if (oldController.value.isInitialized) {
            oldController.pause();
          }
          oldController.dispose();
          _controllers.remove(_currentIndex);
        }
      } catch (e) {
        // Ignore errors during disposal
      }
    }

    setState(() {
      _currentIndex = index;
    });

    _initializeVideo(index, reels);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _controllers.containsKey(index)) {
        final controller = _controllers[index]!;
        if (controller.value.isInitialized && !controller.value.isPlaying) {
          try {
            controller.play();
          } catch (e) {}
        }
      }
    });

    if (index + 1 < reels.length) _initializeVideo(index + 1, reels);
    if (index + 2 < reels.length) _initializeVideo(index + 2, reels);
    if (index - 1 >= 0) _initializeVideo(index - 1, reels);

    final disposeThreshold = 3;
    final keysToRemove = <int>[];
    _controllers.forEach((key, controller) {
      if ((key - index).abs() > disposeThreshold) {
        try {
          controller.removeListener(() {});
          if (controller.value.isInitialized) {
            controller.pause();
          }
          controller.dispose();
          keysToRemove.add(key);
        } catch (e) {
          // Ignore errors during disposal
          keysToRemove.add(key);
        }
      }
    });
    for (var key in keysToRemove) {
      _controllers.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reelsFromProvider = ref.watch(reelsListProvider);
    final isLoading = ref.watch(reelsLoadingProvider);
    final error = ref.watch(reelsErrorProvider);
    final prependedReel = widget.prependedReel;
    final initialPostId = widget.initialPostId;

    // Combined list: prepended reel first (tapped from home), then reels from API
    final reels = prependedReel != null
        ? [prependedReel, ...reelsFromProvider.where((r) => r.id != prependedReel.id)]
        : reelsFromProvider;

    final isPushedRoute = prependedReel != null || initialPostId != null;

    // When opened with prependedReel: start at 0 (tapped video) once. Else when initialPostId: jump to that index once.
    if (reels.isNotEmpty && !_hasAppliedInitialPostId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hasAppliedInitialPostId = true;
        int targetIndex = 0;
        if (prependedReel != null) {
          targetIndex = 0;
        } else if (initialPostId != null) {
          final idx = reels.indexWhere((r) => r.id == initialPostId);
          if (idx >= 0) targetIndex = idx;
        }
        if (_pageController.hasClients && targetIndex < reels.length) {
          _pageController.jumpToPage(targetIndex);
          _onPageChanged(targetIndex, reels);
        }
      });
    }

    if (isLoading && reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: ThemeHelper.getAccentColor(context)),
        ),
      );
    }
    if (error != null && reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error,
                style: TextStyle(color: ThemeHelper.getTextSecondary(context), fontSize: 14, decoration: TextDecoration.none),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(reelsProvider.notifier).refresh(),
                child: Text('Retry', style: TextStyle(color: ThemeHelper.getAccentColor(context), decoration: TextDecoration.none)),
              ),
            ],
          ),
        ),
      );
    }
    if (reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No reels yet',
            style: TextStyle(color: ThemeHelper.getTextSecondary(context), fontSize: 16, decoration: TextDecoration.none),
          ),
        ),
      );
    }

    if (reels.isNotEmpty && _controllers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && reels.isNotEmpty) _initVideosForList(reels);
      });
    }

    final content = Scaffold(
      backgroundColor: Colors.black,
      body: DefaultTextStyle(
        style: TextStyle(decoration: TextDecoration.none),
        child: RefreshIndicator(
          onRefresh: () => ref.read(reelsProvider.notifier).refresh(),
          color: Colors.white,
          backgroundColor: Colors.black54,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (index) => _onPageChanged(index, reels),
            itemCount: reels.length,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, index) {
              if (index < 0 || index >= reels.length) {
                return Container(color: Colors.black);
              }
              return _buildReelItem(reels[index], index);
            },
          ),
        ),
      ),
    );

    if (isPushedRoute) {
      return Stack(
        children: [
          content,
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      );
    }
    return content;
  }

  Widget _buildReelItem(PostModel reel, int index) {
    final controller = _controllers[index];
    final isPlaying = controller?.value.isPlaying ?? false;
    final isInitialized = controller?.value.isInitialized ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player with smooth loading
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
                // Show thumbnail if available
                if (reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty)
                  Center(
                    child: CachedNetworkImage(
                      imageUrl: reel.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                // Loading overlay
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                        // Removed "Loading..." text as per requirements
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Overlay UI
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left side - Author info and caption
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
                            backgroundImage: reel.author.avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(reel.author.avatarUrl)
                                : null,
                            backgroundColor: Colors.grey[800],
                            onBackgroundImageError: reel.author.avatarUrl.isNotEmpty
                                ? (exception, stackTrace) {}
                                : null,
                            child: reel.author.avatarUrl.isEmpty
                                ? Icon(Icons.person, color: Colors.grey[600], size: 22)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  reel.author.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Follow button - hide when author is current user
                          Consumer(
                            builder: (context, ref, child) {
                              final currentUser = ref.watch(currentUserProvider);
                              if (currentUser?.id == reel.author.id) {
                                return const SizedBox.shrink();
                              }
                              final followState = ref.watch(followProvider);
                              final followOverrides = ref.watch(followStateProvider);
                              final posts = ref.watch(postsListProvider);
                              PostModel? post;
                              try {
                                post = posts.firstWhere((p) => p.author.id == reel.author.id);
                              } catch (_) {}
                              final overrideStatus =
                                  followOverrides[reel.author.id];
                              final isFollowing =
                                  overrideStatus ==
                                          FollowRelationshipStatus.following ||
                                      (overrideStatus == null &&
                                          (followState.followingIds.isNotEmpty
                                              ? followState.followingIds
                                                  .contains(reel.author.id)
                                              : (post?.author.isFollowing ??
                                                  reel.author.isFollowing)));
                              final isPending = overrideStatus ==
                                      FollowRelationshipStatus.pending ||
                                  (overrideStatus == null &&
                                      followState.outgoingPendingRequests
                                          .containsKey(reel.author.id));
                              return GestureDetector(
                                onTap: () {
                                  ref.read(followProvider.notifier).toggleFollow(reel.author.id);
                                },
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
                                    isFollowing
                                        ? 'Following'
                                        : (isPending ? 'Requested' : 'Follow'),
                                    style: TextStyle(
                                      color: isFollowing ? Colors.white : Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Audio row (Instagram-style) - tappable to see reels with same audio
                      if (reel.audioName != null || reel.isVideo)
                        GestureDetector(
                          onTap: () {
                            // Pause and dispose ALL reel videos before navigating (stops audio when CreateContentScreen is opened)
                            _pauseAndDisposeAllVideos();
                            if (mounted) setState(() {});
                            final audioId = reel.audioId ?? 'original_${reel.author.id}';
                            final audioName = reel.audioName ?? 'Original sound - ${reel.author.username}';
                            final reelsList = ref.read(reelsListProvider);
                            final sameAudioReels = reelsList.where((r) => (r.audioId ?? 'original_${r.author.id}') == audioId).toList();
                            if (sameAudioReels.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AudioDetailScreen(
                                  audioId: audioId,
                                  audioName: audioName,
                                  reels: sameAudioReels,
                                ),
                              ),
                            ).then((_) {
                              // Re-initialize current video when returning from audio/create content screen
                              if (mounted) {
                                final reelsList = ref.read(reelsListProvider);
                                _initializeVideo(_currentIndex, reelsList);
                                if (_currentIndex + 1 < reelsList.length) _initializeVideo(_currentIndex + 1, reelsList);
                                if (_currentIndex + 2 < reelsList.length) _initializeVideo(_currentIndex + 2, reelsList);
                              }
                            });
                          },
                          child: Row(
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
                        ),
                      const SizedBox(height: 8),
                      Text(
                        reel.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          // Caption on dark overlay - use white for visibility in both modes
                          color: Colors.white,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right side - Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reel.author.allowLikes) ...[
                          _buildActionButton(
                          icon: Icons.favorite,
                          count: ref.watch(reelLikeCountProvider(reel.id)),
                          isActive: ref.watch(reelLikedProvider(reel.id)),
                          onTap: () {
                            ref.read(reelsProvider.notifier).toggleLikeWithApi(reel.id);
                          },
                        ),
                      const SizedBox(height: 14),
                    ],
                    if (reel.author.allowComments) ...[
                      _buildActionButton(
                        icon: Icons.comment,
                        count: reel.comments,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => CommentsBottomSheet(postId: reel.id),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (reel.author.allowShares) ...[
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ShareBottomSheet(
                              postId: reel.id,
                              videoUrl: reel.videoUrl,
                              imageUrl: reel.effectiveThumbnailUrl,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Transform.rotate(
                              angle: -0.785398,
                              child: Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCount(reel.shares),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildActionButton(
                      icon: (_savedReels[reel.id] ?? false) ? Icons.star : Icons.star_border,
                      onTap: () {
                        setState(() {
                          _savedReels[reel.id] = !(_savedReels[reel.id] ?? false);
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildActionButton(
                      icon: isPlaying ? Icons.pause : Icons.play_arrow,
                      onTap: () {
                        if (controller != null) {
                          if (isPlaying) {
                            controller.pause();
                          } else {
                            controller.play();
                          }
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
        // Three-dot menu (vertical) top right
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: GestureDetector(
            onTap: () => _showReelMoreMenu(context, reel),
            child: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  void _showReelMoreMenu(BuildContext context, PostModel reel) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Report'),
            onPressed: () async {
              final currentUserId = ref.read(authProvider).currentUser?.id ?? '';
              Navigator.pop(context);

              final result = await PostsService().reportPost(
                postId: reel.id,
                currentUserId: currentUserId,
                postAuthorId: reel.author.id,
              );

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.success ? 'Reported' : (result.errorMessage ?? 'Report failed'),
                  ),
                  backgroundColor: result.success
                      ? ThemeHelper.getAccentColor(context)
                      : ThemeHelper.getSurfaceColor(context),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Copy Link'),
            onPressed: () {
              final link = ShareLinkHelper.build(
                contentId: reel.id,
                thumbnailUrl: reel.effectiveThumbnailUrl,
              );
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Link copied!',
                    style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                  ),
                  backgroundColor:
                      ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
                ),
              );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    int? count,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Column(
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
