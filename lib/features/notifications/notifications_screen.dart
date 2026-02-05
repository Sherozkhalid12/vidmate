import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';
import '../profile/profile_screen.dart';

/// Notifications screen with activity feed
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notifications.addAll(MockDataService.getMockNotifications());
    });
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    // Use semantic colors where appropriate, theme-aware accent for others
    switch (type) {
      case 'like':
        return AppColors.warning; // Keep semantic color for likes
      case 'comment':
        return ThemeHelper.getAccentColor(context); // Theme-aware accent color
      case 'follow':
        return ThemeHelper.getAccentColor(context); // Theme-aware accent color
      default:
        return ThemeHelper.getAccentColor(context); // Theme-aware accent color
    }
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
        foregroundColor: ThemeHelper.getTextPrimary(context),
        iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
        titleTextStyle: TextStyle(
          color: ThemeHelper.getTextPrimary(context),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: Text('Notifications'),
        shape: Border(
          bottom: BorderSide(
            color: ThemeHelper.getBorderColor(context).withOpacity(0.5),
            width: 0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var notification in _notifications) {
                  notification['isRead'] = true;
                }
              });
            },
            child: Text(
              'Mark all as read',
              style: TextStyle(
                color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
              ),
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: ThemeHelper.getTextMuted(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildNotificationCard(notification),
                      ),
                    ),
                  );
                },
              ),
            ),
        ),
    ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final user = notification['user'] as UserModel;
    final type = notification['type'] as String;
    final isRead = notification['isRead'] as bool;
    final text = notification['text'] as String;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(user: user),
          ),
        );
        setState(() {
          notification['isRead'] = true;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Profile image on the left
            ClipOval(
              child: Image.network(
                user.avatarUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    height: 50,
                    color: ThemeHelper.getSurfaceColor(context),
                    child: Icon(
                      Icons.person,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            // Notification type icon (right of image, left of text)
            Icon(
              _getNotificationIcon(type),
              color: _getNotificationColor(type),
              size: 28,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: user.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' $text'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification['timestamp'] as DateTime),
                    style: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ThemeHelper.getAccentColor(context),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
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


