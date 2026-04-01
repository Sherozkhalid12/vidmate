class AgoraConstants {
  AgoraConstants._();

  /// Agora App ID used by calls + livestream.
  ///
  /// Backend currently returns this for the caller via `/calls/agora/token`, but
  /// socket events like `calls:accepted` do not include it. We keep a fallback
  /// here so the receiver can still initialize the Agora engine.
  static const String appId = '56977746faf14b46bbe35f6d18eaa04a';
}

