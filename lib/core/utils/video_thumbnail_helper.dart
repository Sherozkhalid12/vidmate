/// Derives a thumbnail URL from a video (e.g. HLS) URL for fast display.
/// Backend can optionally return thumbnailUrl for guaranteed thumbnails.
class VideoThumbnailHelper {
  VideoThumbnailHelper._();

  /// Returns a candidate thumbnail URL from a video URL (e.g. CloudFront HLS).
  /// Common pattern: .../videos/xxx/playlist.m3u8 -> .../videos/xxx/thumbnail.jpg
  static String? thumbnailFromVideoUrl(String videoUrl) {
    if (videoUrl.isEmpty) return null;
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return null;
    final path = uri.path;
    if (path.endsWith('/playlist.m3u8') || path.endsWith('playlist.m3u8')) {
      final base = path.replaceFirst(RegExp(r'/playlist\.m3u8$'), '');
      return '${uri.scheme}://${uri.host}$base/thumbnail.jpg';
    }
    if (path.endsWith('.m3u8')) {
      final base = path.replaceFirst(RegExp(r'\.m3u8$'), '');
      return '${uri.scheme}://${uri.host}$base-thumbnail.jpg';
    }
    return null;
  }
}
