import 'api_base.dart';

/// Notification API service
class NotificationApi extends ApiBase {
  // Get notifications
  Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    return await get(
      '/notifications',
      queryParams: {'page': page.toString()},
    );
  }

  // Mark notification as read
  Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    return await post('/notifications/$notificationId/read', {});
  }

  // Mark all as read
  Future<Map<String, dynamic>> markAllAsRead() async {
    return await post('/notifications/read-all', {});
  }

  // Delete notification
  Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    return await delete('/notifications/$notificationId');
  }

  // Get notification settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    return await get('/notifications/settings');
  }

  // Update notification settings
  Future<Map<String, dynamic>> updateNotificationSettings({
    bool? likesEnabled,
    bool? commentsEnabled,
    bool? followsEnabled,
    bool? messagesEnabled,
  }) async {
    return await put(
      '/notifications/settings',
      {
        if (likesEnabled != null) 'likesEnabled': likesEnabled,
        if (commentsEnabled != null) 'commentsEnabled': commentsEnabled,
        if (followsEnabled != null) 'followsEnabled': followsEnabled,
        if (messagesEnabled != null) 'messagesEnabled': messagesEnabled,
      },
    );
  }
}


