class LongVideoLogger {
  LongVideoLogger._();

  // Master switch — set false for release builds
  static const bool _enabled = true;

  // Category switches
  static const bool _lifecycle = true; // controller init/dispose/handoff
  static const bool _autoplay = true; // dominant changes, dwell, arm/disarm
  static const bool _pool = true; // warm/release pool operations
  static const bool _handoff = true; // feed→embedded→feed transfers
  static const bool _resolution = true; // quality/resolution switches
  static const bool _errors = true; // all error paths
  static const bool _events = false; // BetterPlayer event spam (OFF by default)
  static const bool _eviction = false; // release timer firing (OFF by default)
  static const bool _prefetch = false; // HLS prefetch calls (OFF by default)

  static void lifecycle(String msg) {
    if (_enabled && _lifecycle) _log('LIFE', msg);
  }

  static void autoplay(String msg) {
    if (_enabled && _autoplay) _log('AUTO', msg);
  }

  static void pool(String msg) {
    if (_enabled && _pool) _log('POOL', msg);
  }

  static void handoff(String msg) {
    if (_enabled && _handoff) _log('HAND', msg);
  }

  static void resolution(String msg) {
    if (_enabled && _resolution) _log('RESO', msg);
  }

  static void error(String msg) {
    if (_enabled && _errors) _log('ERR', msg);
  }

  static void event(String msg) {
    if (_enabled && _events) _log('EVT', msg);
  }

  static void eviction(String msg) {
    if (_enabled && _eviction) _log('EVICT', msg);
  }

  static void prefetch(String msg) {
    if (_enabled && _prefetch) _log('PRE', msg);
  }

  static void _log(String tag, String msg) {
    // ignore: avoid_print
    print('@@LONGVIDEO@@ [LV][$tag] $msg');
  }
}
