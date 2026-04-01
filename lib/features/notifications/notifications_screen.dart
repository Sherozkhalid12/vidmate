import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/notifications_provider_riverpod.dart';
import '../../services/notifications/notifications_service.dart';
import '../../core/widgets/glass_card.dart';
import '../profile/profile_screen.dart';

/// Notifications screen with activity feed
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Load from API on first open; keep existing list for subsequent opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(notificationsProvider);
      if (!state.isLoading && state.notifications.isEmpty) {
        ref.read(notificationsProvider.notifier).loadNotifications();
      }
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
    final state = ref.watch(notificationsProvider);
    final notifications = state.notifications;
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
            onPressed: notifications.isEmpty
                ? null
                : () {
                    ref
                        .read(notificationsProvider.notifier)
                        .markAllAsRead();
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
        child: state.isLoading && notifications.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : notifications.isEmpty
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
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
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

  Widget _buildNotificationCard(NotificationItem notification) {
    final user = ref
        .read(notificationsProvider.notifier)
        .buildUserPlaceholder(notification);
    final type = notification.type;
    final isRead = notification.isRead;
    final text = notification.body.isNotEmpty
        ? notification.body
        : notification.title;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(user: user),
          ),
        );
        ref
            .read(notificationsProvider.notifier)
            .markAsRead(notification.id);
      },
      child: Row(
          children: [
            // Profile image on the left
            ClipOval(
              child: user.avatarUrl.isNotEmpty
                  ? Image.network(
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
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: ThemeHelper.getSurfaceColor(context),
                      child: Icon(
                        Icons.person,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                    ),
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
                    _formatTime(notification.createdAt),
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

