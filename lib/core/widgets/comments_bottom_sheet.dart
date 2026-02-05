import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';

/// Enhanced Comments bottom sheet widget with modern, beautiful UI
class CommentsBottomSheet extends StatefulWidget {
  final String postId;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet>
    with SingleTickerProviderStateMixin {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  final List<Map<String, dynamic>> _comments = [];
  final Set<String> _likedComments = {};
  late AnimationController _sendButtonController;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _commentController.addListener(() {
      if (_commentController.text.isNotEmpty && !_sendButtonController.isCompleted) {
        _sendButtonController.forward();
      } else if (_commentController.text.isEmpty) {
        _sendButtonController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _sendButtonController.dispose();
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
    _focusNode.unfocus();

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text('Comment posted!'),
          ],
        ),
        backgroundColor: ThemeHelper.getAccentColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleLike(Map<String, dynamic> comment) {
    final commentId = comment['id'] as String;
    setState(() {
      if (_likedComments.contains(commentId)) {
        _likedComments.remove(commentId);
        comment['likes'] = (comment['likes'] as int) - 1;
      } else {
        _likedComments.add(commentId);
        comment['likes'] = (comment['likes'] as int) + 1;
      }
    });
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
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: ThemeHelper.getTextMuted(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Simple header row with title and down-arrow close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Simple down arrow to close sheet
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Comments',
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_comments.length} replies',
                          style: TextStyle(
                            color: ThemeHelper.getTextMuted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // balance space opposite IconButton
                ],
              ),
            ),
            // Comments list
            Expanded(
              child: _comments.isEmpty
                  ? _buildEmptyState()
                  : AnimationLimiter(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 400),
                            child: SlideAnimation(
                              verticalOffset: 30.0,
                              child: FadeInAnimation(
                                child: _buildCommentItem(comment, index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            // Enhanced input bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThemeHelper.getSurfaceColor(context).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: ThemeHelper.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No comments yet',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your thoughts!',
            style: TextStyle(
              color: ThemeHelper.getTextMuted(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: ThemeHelper.getBackgroundColor(context),
        border: Border(
          top: BorderSide(
            color: ThemeHelper.getBorderColor(context).withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ThemeHelper.getAccentColor(context)
                          .withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      MockDataService.mockUsers[0].avatarUrl,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                ThemeHelper.getAccentColor(context),
                                ThemeHelper.getAccentColor(context)
                                    .withOpacity(0.6),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            color: ThemeHelper.getOnAccentColor(context),
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ThemeHelper.getSecondaryBackgroundColor(context),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Clean, theme-aware input field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 130),
                child: TextField(
                  controller: _commentController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 15,
                    height: 1.4,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: ThemeHelper.getSurfaceColor(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: ThemeHelper.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: ThemeHelper.getBorderColor(context).withOpacity(0.8),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: ThemeHelper.getAccentColor(context),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addComment(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Animated send button (no glass, just accent)
            AnimatedBuilder(
              animation: _sendButtonController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.9 + (_sendButtonController.value * 0.1),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _commentController.text.isEmpty
                          ? ThemeHelper.getSurfaceColor(context)
                          : ThemeHelper.getAccentColor(context),
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _commentController.text.isEmpty
                            ? null
                            : _addComment,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Icon(
                            Icons.send_rounded,
                            color: _commentController.text.isEmpty
                                ? ThemeHelper.getTextMuted(context)
                                : ThemeHelper.getOnAccentColor(context),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, int index) {
    final user = comment['user'] as UserModel;
    final commentId = comment['id'] as String;
    final isLiked = _likedComments.contains(commentId);
    final isNew = index == 0 && DateTime.now().difference(comment['timestamp'] as DateTime).inSeconds < 5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with badge for new comments
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isNew
                            ? ThemeHelper.getAccentColor(context)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        user.avatarUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  ThemeHelper.getSurfaceColor(context),
                                  ThemeHelper.getSurfaceColor(context)
                                      .withOpacity(0.7),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              color: ThemeHelper.getTextSecondary(context),
                              size: 24,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getAccentColor(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ThemeHelper.getSecondaryBackgroundColor(
                                context),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 10,
                          color: ThemeHelper.getOnAccentColor(context),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User name and timestamp
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: ThemeHelper.getTextMuted(context)
                                .withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(comment['timestamp'] as DateTime),
                          style: TextStyle(
                            color: ThemeHelper.getTextMuted(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Comment text
                    Text(
                      comment['text'] as String,
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        // Like button
                        GestureDetector(
                          onTap: () => _toggleLike(comment),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                size: 16,
                                color: isLiked
                                    ? ThemeHelper.getAccentColor(context)
                                    : ThemeHelper.getTextMuted(context),
                              ),
                              if (comment['likes'] > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${comment['likes']}',
                                  style: TextStyle(
                                    color: isLiked
                                        ? ThemeHelper.getAccentColor(context)
                                        : ThemeHelper.getTextMuted(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Reply button
                        GestureDetector(
                          onTap: () {
                            _focusNode.requestFocus();
                            _commentController.text = '@${user.displayName} ';
                            _commentController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: _commentController.text.length),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply_rounded,
                                size: 16,
                                color: ThemeHelper.getTextMuted(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  color: ThemeHelper.getTextMuted(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: ThemeHelper.getBorderColor(context).withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}