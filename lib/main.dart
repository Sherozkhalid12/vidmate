import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider_riverpod.dart';
import 'core/providers/auth_provider_riverpod.dart';
import 'core/providers/socket_provider_riverpod.dart';
import 'core/providers/calls_provider_riverpod.dart';
import 'features/splash/splash_screen.dart';
import 'features/calls/call_screen.dart';
import 'services/notifications/push_notifications_service.dart';
import 'services/background/content_prefetch_workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/storage/hive_content_store.dart';
import 'features/long_videos/providers/long_video_playback_provider.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();
bool _callScreenOpen = false;

/// [WidgetsFlutterBinding.ensureInitialized] and [runApp] must run in the **same**
/// [Zone]. Do not use `async main()` + [runZonedGuarded] around only [runApp] — that
/// triggers "Zone mismatch" in debug. Keep binding init + [runApp] inside one zone.
void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Long-form feeds + long-video thumbnails: larger cache reduces tab-switch
    // thumbnail reloads; cap bytes to limit pressure on low-RAM devices.
    PaintingBinding.instance.imageCache
      ..maximumSize = 200
      ..maximumSizeBytes = 96 << 20;

    _configureLogging();

    PushNotificationsService.setScaffoldMessengerKey(scaffoldMessengerKey);

    // Async: Firebase default app + background handler + Hive must complete before [runApp]
    // so [FirebaseMessaging.instance] and Hive cache are valid when listeners fire.
    unawaited(_bootAndRun());
  }, (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[Startup] Uncaught error: $error');
      debugPrint(stackTrace.toString());
    }
  });
}

/// Firebase core + Hive in parallel, then [runApp], then permissions + FCM foreground pipeline.
Future<void> _bootAndRun() async {
  await Future.wait([
    _ensureFirebaseCoreSafe(),
    _initHiveSafely(),
    _initWorkmanagerSafely(),
  ]);

  final container = ProviderContainer();
  container.read(longVideoPlaybackProvider.notifier).clearCurrentlyPlaying();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );

  unawaited(_bootstrapSafely());
}

Future<void> _initWorkmanagerSafely() async {
  try {
    await ContentPrefetchWorkmanager.initialize();
    await ContentPrefetchWorkmanager.clearQueuedTasksOnStartup();
    await ContentPrefetchWorkmanager.schedule();
    // We intentionally avoid triggerNow() during startup.
  } catch (e, st) {
    _logStartupError('workmanager_init', e, st);
  }
}

Future<void> _ensureFirebaseCoreSafe() async {
  try {
    await PushNotificationsService.ensureCoreBeforeRunApp();
  } catch (e, st) {
    _logStartupError('firebase_core', e, st);
  }
}

Future<void> _initHiveSafely() async {
  try {
    await HiveContentStore.instance.init();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[Startup] Hive init failed: $e');
      debugPrint('$st');
    }
  }
}

/// After first frame: OS permissions + FCM foreground listeners (token sync, onMessage).
Future<void> _bootstrapSafely() async {
  try {
    await _requestStartupPermissions();
  } catch (e, st) {
    _logStartupError('permissions', e, st);
  }

  try {
    await PushNotificationsService.instance.attachForegroundPipeline();
  } catch (e, st) {
    _logStartupError('push_notifications', e, st);
  }
}

void _logStartupError(String step, Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    debugPrint('[Startup][$step] $error');
    debugPrint(stackTrace.toString());
  }
}

Future<void> _requestStartupPermissions() async {
  try {
    // Request in a single batch for faster resolution on Android.
    await [
      Permission.camera,
      Permission.microphone,
      Permission.notification, // Required for FCM on Android 13+
      Permission.bluetoothConnect, // Required by Agora on Android 12+
    ].request();
  } catch (e) {
    // Permissions failing at this stage must not crash the app.
    // The individual screens will handle denied states gracefully.
    if (kDebugMode) debugPrint('[Permissions] Startup request failed: $e');
  }
}

/// Configure logging — suppress all debug prints in release builds.
void _configureLogging() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Connect socket when user is logged in, disconnect on logout.
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null) {
        ref.read(socketConnectionProvider.notifier).ensureConnection();
        PushNotificationsService.instance.syncDeviceTokenWithBackend();
      } else {
        ref.read(socketConnectionProvider.notifier).disconnect();
        PushNotificationsService.instance.removeDeviceTokenFromBackend();
      }
    });

    // Global call UI router: opens CallScreen for incoming/outgoing/in-call states.
    ref.listen<CallsState>(callsProvider, (prev, next) {
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;

      final shouldShow = next.status == CallUiStatus.incoming ||
          next.status == CallUiStatus.startingOutgoing ||
          next.status == CallUiStatus.inCall ||
          next.status == CallUiStatus.ending;

      if (shouldShow && !_callScreenOpen) {
        _callScreenOpen = true;
        nav
            .push(
          MaterialPageRoute(
            settings: const RouteSettings(name: CallScreen.routeName),
            fullscreenDialog: true,
            builder: (_) => const _RouteAwareWrapper(
              name: CallScreen.routeName,
              child: CallScreen(),
            ),
          ),
        )
            .whenComplete(() {
          _callScreenOpen = false;
        });
      }
    });

    final isDarkMode = ref.watch(isDarkModeProvider);
    ref.watch(currentThemeProvider);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        title: 'VidConnect',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: scaffoldMessengerKey,
        navigatorKey: appNavigatorKey,
        navigatorObservers: [routeObserver],
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: child,
      ),
      child: const _RouteAwareWrapper(
        name: 'SplashScreen',
        child: SplashScreen(),
      ),
    );
  }
}

class _RouteAwareWrapper extends StatefulWidget {
  final String name;
  final Widget child;
  const _RouteAwareWrapper({required this.name, required this.child});

  @override
  State<_RouteAwareWrapper> createState() => _RouteAwareWrapperState();
}

class _RouteAwareWrapperState extends State<_RouteAwareWrapper>
    with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {}

  @override
  void didPopNext() {}

  @override
  Widget build(BuildContext context) => widget.child;
}
