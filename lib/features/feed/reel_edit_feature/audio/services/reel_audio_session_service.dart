import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Configures platform audio session for reel-editor preview vs normal playback.
class ReelAudioSessionService {
  ReelAudioSessionService._();
  static final ReelAudioSessionService instance = ReelAudioSessionService._();

  bool _mixableConfigured = false;

  /// Mixable session so video + music preview can play together in the editor.
  Future<void> ensureMixablePlayback() async {
    if (_mixableConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
      _mixableConfigured = true;
    } catch (e) {
      debugPrint('ReelAudioSessionService mixable: $e');
    }
  }

  /// Standard media playback for feeds / long videos after leaving the editor.
  Future<void> restoreDefaultPlayback() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.movie,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
      _mixableConfigured = false;
    } catch (e) {
      debugPrint('ReelAudioSessionService restore: $e');
    }
  }
}
