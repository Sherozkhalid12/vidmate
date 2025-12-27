import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/story_model.dart';

/// Full-screen story viewer with swipe gestures
class StoriesViewerScreen extends StatefulWidget {
  final int initialIndex;

  const StoriesViewerScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<StoriesViewerScreen> createState() => _StoriesViewerScreenState();
}

class _StoriesViewerScreenState extends State<StoriesViewerScreen> {
  late PageController _pageController;
  late List<StoryModel> _stories;
  int _currentIndex = 0;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _stories = MockDataService.getMockStories();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _startProgress();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startProgress() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _progress = 1.0;
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _nextStory();
          }
        });
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _progress = 0.0;
    });
    _startProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < screenWidth / 2) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // Story content
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _stories.length,
              itemBuilder: (context, index) {
                final story = _stories[index];
                return _buildStoryContent(story);
              },
            ),
            // Top bar with progress indicators
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    // Progress bars
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: List.generate(_stories.length, (index) {
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Stack(
                                children: [
                                  if (index == _currentIndex)
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 100),
                                      width: MediaQuery.of(context).size.width *
                                          _progress /
                                          _stories.length,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.storyRingGradient,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // User info and actions
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipOval(
                            child: Image.network(
                              _stories[_currentIndex].author.avatarUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 40,
                                  height: 40,
                                  color: context.surfaceColor,
                                  child: Icon(
                                    Icons.person,
                                    color: context.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _stories[_currentIndex].author.displayName,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_formatTime(_stories[_currentIndex].createdAt)}',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.more_vert),
                            color: context.textPrimary,
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: context.secondaryBackgroundColor,
                                builder: (context) => Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Icon(Icons.person_remove, color: AppColors.warning),
                                        title: Text('Mute', style: TextStyle(color: context.textPrimary)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Mute feature coming soon'),
                                              backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.block, color: AppColors.warning),
                                        title: Text('Block', style: TextStyle(color: context.textPrimary)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Block feature coming soon'),
                                              backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            color: context.textPrimary,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom actions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: context.borderColor,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Send message',
                              hintStyle: TextStyle(color: context.textMuted),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: ThemeHelper.getAccentGradient(context), // Theme-aware accent gradient
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send,
                          color: context.textPrimary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(StoryModel story) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(story.mediaUrl),
          fit: BoxFit.cover,
          onError: (exception, stackTrace) {},
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

