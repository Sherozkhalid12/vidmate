import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';

/// Notification model for API integration.
class NotificationItem {
  final String id;
  final String userId;
  final String fromUserId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.fromUserId,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      fromUserId: (json['fromUserId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{},
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      userId: userId,
      fromUserId: fromUserId,
      title: title,
      body: body,
      type: type,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class NotificationsResult {
  final bool success;
  final List<NotificationItem> notifications;
  final String? errorMessage;

  NotificationsResult({
    required this.success,
    this.notifications = const [],
    this.errorMessage,
  });

  factory NotificationsResult.failure(String message) =>
      NotificationsResult(success: false, errorMessage: message);

  factory NotificationsResult.success(List<NotificationItem> list) =>
      NotificationsResult(success: true, notifications: list);
}

class NotificationOperationResult {
  final bool success;
  final NotificationItem? notification;
  final String? errorMessage;

  NotificationOperationResult({
    required this.success,
    this.notification,
    this.errorMessage,
  });

  factory NotificationOperationResult.failure(String message) =>
      NotificationOperationResult(success: false, errorMessage: message);

  factory NotificationOperationResult.success([NotificationItem? item]) =>
      NotificationOperationResult(success: true, notification: item);
}

/// Notifications API service using shared Dio client.
class NotificationsService {
  final Dio _dio = DioClient.instance;

  Future<NotificationsResult> getNotifications() async {
    try {
      final response = await _dio.get(ApiConstants.notificationsList);
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        return NotificationsResult.failure(
          data is Map<String, dynamic>
              ? (data['message']?.toString() ?? 'Failed to load notifications')
              : 'Failed to load notifications',
        );
      }
      final rawList = data['notifications'];
      if (rawList is! List) {
        return NotificationsResult.success(const []);
      }
      final list = <NotificationItem>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          try {
            list.add(NotificationItem.fromJson(item));
          } catch (_) {}
        }
      }
      return NotificationsResult.success(list);
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? 'Failed to load notifications')
          : 'Failed to load notifications';
      return NotificationsResult.failure(msg.toString());
    } on TimeoutException catch (_) {
      return NotificationsResult.failure('Notifications request timed out');
    } catch (e) {
      return NotificationsResult.failure(e.toString());
    }
  }

  Future<NotificationOperationResult> markAsRead(String id) async {
    try {
      final response =
          await _dio.patch(ApiConstants.notificationMarkRead(id));
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        return NotificationOperationResult.failure(
          data is Map<String, dynamic>
              ? (data['message']?.toString() ?? 'Failed to mark notification')
              : 'Failed to mark notification',
        );
      }
      final notifJson = data['notification'];
      if (notifJson is Map<String, dynamic>) {
        try {
          final item = NotificationItem.fromJson(notifJson);
          return NotificationOperationResult.success(item);
        } catch (_) {}
      }
      return NotificationOperationResult.success();
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? 'Failed to mark notification')
          : 'Failed to mark notification';
      return NotificationOperationResult.failure(msg.toString());
    } on TimeoutException catch (_) {
      return NotificationOperationResult.failure('Request timed out');
    } catch (e) {
      return NotificationOperationResult.failure(e.toString());
    }
  }

  Future<NotificationOperationResult> markAllAsRead() async {
    try {
      final response =
          await _dio.patch(ApiConstants.notificationsMarkAllRead);
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        return NotificationOperationResult.failure(
          data is Map<String, dynamic>
              ? (data['message']?.toString() ?? 'Failed to mark notifications')
              : 'Failed to mark notifications',
        );
      }
      return NotificationOperationResult.success();
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map
          ? (d['message'] ?? d['error'] ?? 'Failed to mark notifications')
          : 'Failed to mark notifications';
      return NotificationOperationResult.failure(msg.toString());
    } on TimeoutException catch (_) {
      return NotificationOperationResult.failure('Request timed out');
    } catch (e) {
      return NotificationOperationResult.failure(e.toString());
    }
  }
}

