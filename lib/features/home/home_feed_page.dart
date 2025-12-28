import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/video_tile.dart';
import '../../core/widgets/instagram_post_card.dart';
import '../../core/widgets/ad_banner.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/post_model.dart';
import '../search/explore_screen.dart';
import '../search/search_screen.dart';
import '../video/video_player_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';

/// Home Feed Page - displays the main feed with posts
class HomeFeedPage extends StatefulWidget {
  final double bottomPadding;

  const HomeFeedPage({super.key, required this.bottomPadding});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  final ScrollController _scrollController = ScrollController();
  final List<PostModel> _posts = [];
  bool _isLoading = false;
  String _sortBy = 'latest';

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadPosts() {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        var newPosts = List<PostModel>.from(MockDataService.getMockPosts());

        if (_sortBy == 'popular') {
          newPosts.sort((a, b) => b.likes.compareTo(a.likes));
        } else {
          newPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        setState(() {
          _posts.addAll(newPosts);
          _isLoading = false;
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading) {
        _loadPosts();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gradient is applied at MainScreen root, so no need to duplicate here
    // Just use transparent container to let gradient show through
    return SafeArea(
      bottom: false, // Bottom nav handles safe area
      child: Column(
        children: [
          // App Bar
          _buildAppBar(),
          // Scrollable content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _posts.clear();
                });
                _loadPosts();
              },
              color: context.buttonColor,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Posts feed
                  if (_isLoading && _posts.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: context.buttonColor,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: widget.bottomPadding),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            // Show ad every 5 posts
                            if (index > 0 && index % 5 == 0 && index < _posts.length) {
                              return const AdBanner(
                                height: 60,
                                adType: 'banner',
                              );
                            }
                            
                            // Adjust post index for ads
                            final postIndex = index - (index ~/ 5);
                            
                            if (postIndex < _posts.length) {
                              return AnimationConfiguration.staggeredList(
                                position: postIndex,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: _buildPostCard(_posts[postIndex]),
                                  ),
                                ),
                              );
                            } else if (_isLoading) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: context.buttonColor,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          childCount: _posts.length + (_posts.length ~/ 5) + (_isLoading ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // App logo
          Text(
            'VidConnect',
            style: TextStyle(
              color: ThemeHelper.getAccentColor(context),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  ExploreScreen(),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ThemeHelper.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ThemeHelper.getBorderColor(context),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search,
                      size: 18,
                      color: ThemeHelper.getTextMuted(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Search',
                        style: TextStyle(
                          color: ThemeHelper.getTextMuted(context),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatListScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Transform.rotate(
                angle: -0.785398, // -45 degrees in radians (pointing upward-right like Instagram)
                child: Icon(
                  Icons.send,
                  color: ThemeHelper.getTextPrimary(context),
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    ThemeHelper.getAccentColor(context),
                    ThemeHelper.getAccentColor(context).withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Icon(
                Icons.person,
                size: 18,
                color: ThemeHelper.getOnAccentColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    if (!post.isVideo || post.imageUrl != null) {
      return InstagramPostCard(post: post);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: VideoTile(
        thumbnailUrl: post.thumbnailUrl ?? post.imageUrl ?? '',
        title: post.caption,
        channelName: post.author.displayName,
        channelAvatar: post.author.avatarUrl,
        views: post.likes * 10,
        likes: post.likes,
        comments: post.comments,
        duration: post.videoDuration,
        onTap: () {
          if (post.isVideo) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videoUrl: post.videoUrl!,
                  title: post.caption,
                  author: post.author,
                  post: post,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

