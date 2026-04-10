import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../firebase_options.dart';

class PushNotificationPayload {
  final String? title;
  final String? body;
  final String? dataPostId;

  const PushNotificationPayload({
    this.title,
    this.body,
    this.dataPostId,
  });

  factory PushNotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    final dataPostId = message.data['postId']?.toString() ?? message.data['post_id']?.toString();
    return PushNotificationPayload(
      title: title,
      body: body,
      dataPostId: dataPostId,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate: we still need Firebase + local notifications init.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await PushNotificationsService._initLocalNotificationsStatic();
  await PushNotificationsService._showLocalNotificationStatic(
    PushNotificationPayload.fromRemoteMessage(message),
  );
}

class PushNotificationsService {
  static final PushNotificationsService instance =
      PushNotificationsService._internal();

  PushNotificationsService._internal();

  static bool _backgroundHandlerRegistered = false;
  static bool _foregroundPipelineAttached = false;

  static GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;

  static void setScaffoldMessengerKey(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldMessengerKey = key;
  }

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _localNotificationsInitialized = false;

  static Future<void> _initLocalNotificationsStatic() async {
    if (_localNotificationsInitialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(
      settings: settings,
      // No callbacks needed for background; the notification will show as system UI.
      onDidReceiveNotificationResponse: (_) {},
    );

    _localNotificationsInitialized = true;
  }

  static Future<void> _showLocalNotificationStatic(
    PushNotificationPayload payload,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Notifications',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: payload.title ?? 'Notification',
      body: payload.body ?? '',
      notificationDetails: details,
      payload: payload.dataPostId,
    );
  }

  static void _showInAppSnackbar(PushNotificationPayload payload) {
    final key = _scaffoldMessengerKey;
    if (key == null) return;
    final title = payload.title ?? 'Notification';
    final body = payload.body ?? '';

    final messenger = key.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: _BeautifulNotificationSnackBar(title: title, body: body),
      ),
    );
  }

  final Dio _dio = DioClient.instance;
  static const String _tokenKey = 'auth_token';
  static const String _lastRegisteredFcmTokenKey = 'last_fcm_token';

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Must run before [runApp] (same zone as binding init). Registers the default app
  /// and the background isolate handler so [FirebaseMessaging.instance] is valid later.
  static Future<void> ensureCoreBeforeRunApp() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    if (!_backgroundHandlerRegistered) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _backgroundHandlerRegistered = true;
    }
  }

  /// Local notifications + permission + foreground/refresh listeners. Safe to call after [runApp].
  Future<void> attachForegroundPipeline() async {
    if (_foregroundPipelineAttached) return;
    if (Firebase.apps.isEmpty) {
      await ensureCoreBeforeRunApp();
    }

    await _initLocalNotificationsStatic();

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      final payload = PushNotificationPayload.fromRemoteMessage(message);
      _showInAppSnackbar(payload);
      await _showLocalNotificationStatic(payload);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final payload = PushNotificationPayload.fromRemoteMessage(message);
      _showInAppSnackbar(payload);
    });

    messaging.onTokenRefresh.listen((newToken) async {
      await _syncTokenWithBackend(newToken);
    });

    _foregroundPipelineAttached = true;
  }

  /// Full init: core (before UI) + foreground pipeline. Prefer [ensureCoreBeforeRunApp] +
  /// [attachForegroundPipeline] from [main] for correct ordering.
  Future<void> initialize() async {
    await ensureCoreBeforeRunApp();
    await attachForegroundPipeline();
  }

  /// Call when user logs in (or app starts) to register FCM token.
  Future<void> syncDeviceTokenWithBackend() async {
    if (Firebase.apps.isEmpty) {
      await ensureCoreBeforeRunApp();
    }
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _syncTokenWithBackend(token);
  }

  Future<void> _syncTokenWithBackend(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastRegisteredFcmTokenKey);
    if (last == token) return;

    final authToken = await _getAuthToken();
    if (authToken == null || authToken.isEmpty) return;

    try {
      DioClient.setAuthToken(authToken);
      final response = await _dio.post(
        ApiConstants.authSetDeviceToken,
        data: {'deviceToken': token},
      );

      final data = response.data;
      final success = data is Map && data['success'] == true;
      if (success) {
        await prefs.setString(_lastRegisteredFcmTokenKey, token);
      }
    } catch (_) {
      // Fail silently; token will be retried on next sync.
    }
  }

  /// Call when user logs out to remove token association on the backend.
  Future<void> removeDeviceTokenFromBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastRegisteredFcmTokenKey);
    if (last == null || last.isEmpty) return;

    final authToken = await _getAuthToken();
    if (authToken == null || authToken.isEmpty) return;

    try {
      DioClient.setAuthToken(authToken);
      await _dio.post(
        ApiConstants.authRemoveDeviceToken,
        data: {'deviceToken': last},
      );
      await prefs.remove(_lastRegisteredFcmTokenKey);
    } catch (_) {
      // Fail silently.
    }
  }
}

class _BeautifulNotificationSnackBar extends StatelessWidget {
  final String title;
  final String body;

  const _BeautifulNotificationSnackBar({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.28)),
            ),
            child: Icon(Icons.notifications, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.9),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

