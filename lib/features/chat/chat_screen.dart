import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/message_model.dart';

/// Messenger-style chat screen
class ChatScreen extends StatefulWidget {
  final UserModel? user;

  const ChatScreen({
    super.key,
    this.user,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  final UserModel _currentUser = MockDataService.mockUsers[0];
  late UserModel _chatUser;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _chatUser = widget.user ?? MockDataService.mockUsers[1];
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    setState(() {
      _messages.addAll(MockDataService.getMockMessages(_chatUser.id));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: _currentUser,
      text: _messageController.text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
    );

    setState(() {
      _messages.add(message);
    });

    _messageController.clear();
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    // Simulate typing indicator
    setState(() {
      _isTyping = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            MessageModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: _chatUser,
              text: 'Thanks for your message!',
              timestamp: DateTime.now(),
              isRead: false,
            ),
          );
        });
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                ClipOval(
                  child: Image.network(
                    _chatUser.avatarUrl,
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
                if (_chatUser.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.backgroundColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeHelper.getAccentColor(context).withOpacity(0.5), // Theme-aware shadow
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
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
                  Text(
                    _chatUser.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _chatUser.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: _chatUser.isOnline
                          ? ThemeHelper.getAccentColor(context) // Theme-aware accent color
                          : context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video call feature coming soon'),
                  backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.call_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Voice call feature coming soon'),
                  backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildMessageBubble(_messages[index]),
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
                IconButton(
                  icon: Icon(Icons.add_circle_outline),
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
                              leading: Icon(
                                Icons.photo,
                                color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                              ),
                              title: Text('Photo', style: TextStyle(color: context.textPrimary)),
                              onTap: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Photo sharing coming soon'),
                                    backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.videocam,
                                color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                              ),
                              title: Text('Video', style: TextStyle(color: context.textPrimary)),
                              onTap: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Video sharing coming soon'),
                                    backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.location_on,
                                color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                              ),
                              title: Text('Location', style: TextStyle(color: context.textPrimary)),
                              onTap: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Location sharing coming soon'),
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
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    borderRadius: BorderRadius.circular(24),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: context.textMuted),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isMe = message.sender.id == _currentUser.id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            ClipOval(
              child: Image.network(
                message.sender.avatarUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 32,
                    height: 32,
                    color: context.surfaceColor,
                    child: Icon(
                      Icons.person,
                      color: context.textSecondary,
                      size: 16,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              backgroundColor: isMe
                  ? ThemeHelper.getAccentColor(context).withOpacity(0.2) // Theme-aware accent with opacity
                  : context.surfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == MessageType.image && message.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message.mediaUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: context.surfaceColor,
                            child: Icon(
                              Icons.broken_image,
                              color: context.textMuted,
                            ),
                          );
                        },
                      ),
                    ),
                  if (message.text.isNotEmpty) ...[
                    if (message.type == MessageType.image) const SizedBox(height: 8),
                    Text(
                      message.text,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 16,
              color: message.isRead
                  ? ThemeHelper.getAccentColor(context) // Theme-aware accent color
                  : context.textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipOval(
            child: Image.network(
              _chatUser.avatarUrl,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 32,
                  height: 32,
                  color: context.surfaceColor,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GlassCard(
            padding: const EdgeInsets.all(12),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animatedValue = ((value + delay) % 1.0);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: context.textMuted.withOpacity(
              0.3 + (animatedValue * 0.7),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted && _isTyping) {
          setState(() {});
        }
      },
    );
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
}

