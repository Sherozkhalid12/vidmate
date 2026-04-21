import 'package:flutter/foundation.dart';

import 'music_preview_player.dart';

/// One shared preview player for feed + stories so only one track plays at a time.
///
/// Not used from WorkManager isolates.
class AttachedMusicPreview extends ChangeNotifier {
  AttachedMusicPreview._();

  static final AttachedMusicPreview instance = AttachedMusicPreview._();

  late final MusicPreviewPlayer _player = MusicPreviewPlayer(
    onIsPlayingChanged: (_) => instance.notifyListeners(),
  );

  bool get isPlaying => _player.isPlaying;

  String? get currentUrl => _player.currentUrl;

  bool isPlayingUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return false;
    return _player.isPlaying && (_player.currentUrl == u);
  }

  Future<void> toggleSticker(String url) => _player.toggle(url);

  Future<void> playFromStart(String url) => _player.playPreview(url);

  Future<void> stop() => _player.stop();
}
