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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: ThemeHelper.getBackgroundColor(context),
      child: Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeHelper.getSurfaceColor(context).withOpacity(isDark ? 0.4 : 0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: ThemeHelper.getBorderColor(context).withOpacity(0.5),
            width: 0.5,
          ),
        ),
        iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ThemeHelper.getBorderColor(context),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                    _chatUser.avatarUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 44,
                        height: 44,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Icon(
                          Icons.person,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                      );
                    },
                  ),
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
                          color: ThemeHelper.getSurfaceColor(context),
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
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _chatUser.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: _chatUser.isOnline
                          ? ThemeHelper.getAccentColor(context)
                          : ThemeHelper.getTextMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam_outlined, color: ThemeHelper.getTextPrimary(context)),
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
            icon: Icon(Icons.call_outlined, color: ThemeHelper.getTextPrimary(context)),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: Column(
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
          // Modern sleek input bar
          _buildModernInputBar(),
        ],
        ),
      ),
    ),
    );
  }

  Widget _buildModernInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        decoration: BoxDecoration(
          color: isDark
              ? ThemeHelper.getSecondaryBackgroundColor(context)
              : ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: ThemeHelper.getBorderColor(context).withOpacity(0.3),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: isDark ? 16 : 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach button
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: ThemeHelper.getAccentColor(context),
                size: 28,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: ThemeHelper.getSurfaceColor(context),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ThemeHelper.getBorderColor(context),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildAttachmentOption(Icons.photo, 'Photo'),
                        _buildAttachmentOption(Icons.videocam, 'Video'),
                        _buildAttachmentOption(Icons.location_on, 'Location'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            // TextField in pill-shaped container
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark
                      ? ThemeHelper.getBackgroundColor(context).withOpacity(0.6)
                      : ThemeHelper.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ThemeHelper.getBorderColor(context).withOpacity(isDark ? 0.4 : 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                      blurRadius: isDark ? 4 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 16,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: ThemeHelper.getAccentGradient(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.getAccentColor(context).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: ThemeHelper.getOnAccentColor(context),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ThemeHelper.getAccentColor(context).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: ThemeHelper.getAccentColor(context), size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: ThemeHelper.getTextPrimary(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$label sharing coming soon',
              style: TextStyle(color: ThemeHelper.getOnAccentColor(context)),
            ),
            backgroundColor: ThemeHelper.getAccentColor(context),
          ),
        );
      },
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
                    color: ThemeHelper.getSurfaceColor(context),
                    child: Icon(
                      Icons.person,
                      color: ThemeHelper.getTextSecondary(context),
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
                  : ThemeHelper.getSurfaceColor(context),
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
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              Icons.broken_image,
                              color: ThemeHelper.getTextMuted(context),
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
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
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
                  : ThemeHelper.getTextMuted(context),
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
                  color: ThemeHelper.getSurfaceColor(context),
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
            color: ThemeHelper.getTextMuted(context).withOpacity(
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

