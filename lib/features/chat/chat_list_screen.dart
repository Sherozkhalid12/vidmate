import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/chat_conversation_model.dart';
import '../../core/models/message_model.dart';
import 'chat_screen.dart';

/// Chat list screen showing recent conversations
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final List<ChatConversationModel> _conversations = [];

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to ensure the widget is fully built before calling setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadConversations();
      }
    });
  }

  void _loadConversations() {
    if (!mounted) return;
    
    // Mock conversations from recent messages
    final users = MockDataService.mockUsers;
    
    final newConversations = <ChatConversationModel>[];
    
    // Create conversations from mock data
    for (var i = 0; i < users.length - 1; i++) {
      final user = users[i + 1]; // Skip current user
      final conversationMessages = MockDataService.getMockMessages(user.id);
      final lastMessage = conversationMessages.isNotEmpty
          ? conversationMessages.last
          : MessageModel(
              id: '1',
              sender: user,
              text: 'Start a conversation',
              timestamp: DateTime.now(),
            );
      
      newConversations.add(
        ChatConversationModel(
          id: user.id,
          user: user,
          lastMessage: lastMessage,
          lastMessageTime: lastMessage.timestamp,
          unreadCount: i < 2 ? i + 1 : 0, // First 2 have unread
          isOnline: user.isOnline,
        ),
      );
    }
    
    // Sort by last message time
    newConversations.sort((a, b) =>
        b.lastMessageTime.compareTo(a.lastMessageTime));
    
    if (mounted) {
      setState(() {
        _conversations.clear();
        _conversations.addAll(newConversations);
      });
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: context.backgroundGradient,
      ),
      child: Column(
        children: [
          AppBar(
          title: Text('Messages'),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Search conversations feature coming soon'),
                    backgroundColor: context.surfaceColor,
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.add_circle_outline),
              onSelected: (value) {
                if (value == 'one_to_one') {
                  // Navigate to user selection for one-to-one chat
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Select a user to start chatting'),
                      backgroundColor: context.surfaceColor,
                    ),
                  );
                } else if (value == 'group') {
                  // Navigate to group chat creation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Create group chat feature coming soon'),
                      backgroundColor: context.surfaceColor,
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'one_to_one',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('New Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'group',
                  child: Row(
                    children: [
                      Icon(Icons.group_add),
                      SizedBox(width: 8),
                      Text('New Group'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        Expanded(
          child: _conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: context.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildConversationItem(_conversations[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
        ),
      ],
      ),
    );
  }

  Widget _buildConversationItem(ChatConversationModel conversation) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(user: conversation.user),
          ),
        );
      },
      child: Row(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              ClipOval(
                child: Image.network(
                  conversation.user.avatarUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      color: context.surfaceColor,
                      child: Icon(
                        Icons.person,
                        color: context.textSecondary,
                        size: 30,
                      ),
                    );
                  },
                ),
              ),
              if (conversation.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: context.buttonColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.backgroundGradient.colors.first,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.buttonColor.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.user.displayName,
                        style: TextStyle(
                          color: conversation.unreadCount > 0
                              ? context.textPrimary
                              : context.textSecondary,
                          fontSize: 16,
                          fontWeight: conversation.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(conversation.lastMessageTime),
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.lastMessage.text.isEmpty
                            ? conversation.lastMessage.type == MessageType.image
                                ? '📷 Photo'
                                : conversation.lastMessage.type == MessageType.video
                                    ? '🎥 Video'
                                    : 'Media'
                            : conversation.lastMessage.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: conversation.unreadCount > 0
                              ? context.textPrimary
                              : context.textMuted,
                          fontSize: 14,
                          fontWeight: conversation.unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (conversation.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.buttonColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : conversation.unreadCount.toString(),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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

