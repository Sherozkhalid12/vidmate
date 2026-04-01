import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../../services/notifications/notifications_service.dart';
import '../../services/storage/user_storage_service.dart';

class NotificationsState {
  final List<NotificationItem> notifications;
  final bool isLoading;
  final bool isMarkingAll;
  final String? error;

  NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.isMarkingAll = false,
    this.error,
  });

  int get unreadCount =>
      notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
    bool? isMarkingAll,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isMarkingAll: isMarkingAll ?? this.isMarkingAll,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod notifier for notifications list and unread badge.
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier() : super(NotificationsState());

  final NotificationsService _service = NotificationsService();

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (state.isLoading) return;
    if (state.notifications.isNotEmpty && !forceRefresh) return;

    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _service.getNotifications();
    if (!result.success) {
      final cached = await UserStorageService.instance.getLatestNotifications();
      if (cached.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          notifications: cached,
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: result.errorMessage ?? 'Failed to load notifications',
      );
      return;
    }
    // Sort newest first
    final list = List<NotificationItem>.from(result.notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(
      isLoading: false,
      notifications: list,
    );
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance.cacheLatestNotifications(list);
    });
  }

  /// Optimistically mark a single notification as read.
  Future<void> markAsRead(String id) async {
    final idx = state.notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final previous = state.notifications[idx];
    if (previous.isRead) return;

    final updatedList = List<NotificationItem>.from(state.notifications);
    updatedList[idx] = previous.copyWith(isRead: true);
    state = state.copyWith(notifications: updatedList);

    final result = await _service.markAsRead(id);
    if (!result.success) {
      // revert
      updatedList[idx] = previous;
      state = state.copyWith(notifications: updatedList);
      return;
    }
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance
          .cacheLatestNotifications(state.notifications);
    });
  }

  /// Optimistically mark all as read.
  Future<void> markAllAsRead() async {
    if (state.isMarkingAll || state.notifications.isEmpty) return;
    state = state.copyWith(isMarkingAll: true);
    final previous = state.notifications;
    final updated = previous
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();
    state = state.copyWith(notifications: updated);

    final result = await _service.markAllAsRead();
    if (!result.success) {
      state = state.copyWith(
        notifications: previous,
        isMarkingAll: false,
      );
      return;
    }
    state = state.copyWith(isMarkingAll: false);
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance
          .cacheLatestNotifications(state.notifications);
    });
  }

  /// Append a new notification from socket, keeping list sorted.
  void appendFromSocket(NotificationItem item) {
    final existingIndex =
        state.notifications.indexWhere((n) => n.id == item.id);
    List<NotificationItem> list;
    if (existingIndex != -1) {
      list = List<NotificationItem>.from(state.notifications);
      list[existingIndex] = item;
    } else {
      list = [item, ...state.notifications];
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(notifications: list);
    UserStorageService.instance.runInBackground(() async {
      await UserStorageService.instance
          .cacheLatestNotifications(state.notifications);
    });
  }

  /// Convenience: map notification to a lightweight user model for UI only.
  UserModel buildUserPlaceholder(NotificationItem n) {
    final data = n.data;
    final Map<String, dynamic>? fromUser = data['fromUser'] is Map
        ? Map<String, dynamic>.from(data['fromUser'] as Map)
        : (data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : null);

    String pickString(List<dynamic> candidates) {
      for (final c in candidates) {
        if (c == null) continue;
        final v = c.toString().trim();
        if (v.isNotEmpty && v != 'null') return v;
      }
      return '';
    }

    final display = pickString([
      fromUser?['displayName'],
      fromUser?['name'],
      data['displayName'],
      data['name'],
      n.title,
      'Someone',
    ]);

    final username = pickString([
      fromUser?['username'],
      data['username'],
      n.fromUserId,
      'user',
    ]);

    final id = pickString([
      fromUser?['id'],
      fromUser?['_id'],
      data['userId'],
      data['fromUserId'],
      n.fromUserId,
    ]);

    final avatarUrl = pickString([
      fromUser?['profilePicture'],
      fromUser?['avatarUrl'],
      fromUser?['profilePic'],
      data['profilePicture'],
      data['avatarUrl'],
      data['profilePic'],
    ]);

    return UserModel(
      id: id,
      username: username,
      displayName: display,
      avatarUrl: avatarUrl,
    );
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
        (ref) => NotificationsNotifier());

