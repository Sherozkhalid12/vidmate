class VideoEngineLogger {
  VideoEngineLogger._();
  static const bool _enabled = true;
  static const bool _engine = true;
  static const bool _errors = true;
  static const bool _prefetch = false;

  static void engine(String msg) {
    if (_enabled && _engine) _log('ENG', msg);
  }

  static void error(String msg) {
    if (_enabled && _errors) _log('ERR', msg);
  }

  static void prefetch(String msg) {
    if (_enabled && _prefetch) _log('PRE', msg);
  }

  static void _log(String tag, String msg) {
    // ignore: avoid_print
    print('@@VIDEOENGINE@@ [VE][$tag] $msg');
  }
}
