class ReelsLogger {
  ReelsLogger._();
  static const bool _enabled = true;
  static const bool _lifecycle = true;
  static const bool _pool = true;
  static const bool _errors = true;
  // These are OFF to reduce noise
  static const bool _events = false;
  static const bool _eviction = false;

  static void lifecycle(String msg) {
    if (_enabled && _lifecycle) _log('LIFE', msg);
  }
  static void life(String msg) {
    if (_enabled && _lifecycle) _log('LIFE', msg);
  }
  static void pool(String msg) {
    if (_enabled && _pool) _log('POOL', msg);
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
  static void _log(String tag, String msg) {
    // ignore: avoid_print
    print('@@REELS@@ [REELS][$tag] $msg');
  }
}
