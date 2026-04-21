import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../music/music_library_cache_service.dart';

/// WorkManager / background isolate entry: HTTP + SharedPreferences only.
///
/// Do not add audio plugins or other platform-channel APIs here.
class MusicPrefetchRunner {
  static Future<bool> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await MusicLibraryCacheService.instance.syncBrowseFromNetwork();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MusicPrefetch] $e');
        debugPrint('$st');
      }
    }
    return true;
  }
}
