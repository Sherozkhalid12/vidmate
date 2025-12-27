import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';

/// Comments screen for posts
class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _commentController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _loadComments() {
    // Mock comments
    setState(() {
      _comments.addAll([
        {
          'id': '1',
          'user': MockDataService.mockUsers[1],
          'text': 'This is amazing! 🔥',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
          'likes': 12,
        },
        {
          'id': '2',
          'user': MockDataService.mockUsers[2],
          'text': 'Love it!',
          'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
          'likes': 5,
        },
        {
          'id': '3',
          'user': MockDataService.mockUsers[3],
          'text': 'Great content!',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)),
          'likes': 8,
        },
      ]);
    });
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _comments.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'user': MockDataService.mockUsers[0],
        'text': _commentController.text.trim(),
        'timestamp': DateTime.now(),
        'likes': 0,
      });
    });

    _commentController.clear();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Comments'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Comments list
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildCommentItem(comment),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: context.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: Image.network(
                    MockDataService.mockUsers[0].avatarUrl,
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
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    borderRadius: BorderRadius.circular(24),
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: context.textMuted),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final user = comment['user'] as UserModel;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.network(
              user.avatarUrl,
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
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(
                        text: user.displayName,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' ${comment['text']}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatTime(comment['timestamp'] as DateTime),
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          final currentLikes = comment['likes'] as int;
                          comment['likes'] = currentLikes + 1;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Liked comment'),
                            backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Text(
                        'Like',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${comment['likes']} likes',
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

