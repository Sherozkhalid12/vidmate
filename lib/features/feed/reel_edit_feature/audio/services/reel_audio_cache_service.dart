import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads remote preview audio to a temp file for editing and FFmpeg export.
class ReelAudioCacheService {
  ReelAudioCacheService._();
  static final ReelAudioCacheService instance = ReelAudioCacheService._();

  final Map<String, String> _urlToPath = {};

  static Map<String, String>? _previewHeadersForUrl(String url) {
    final lower = url.toLowerCase();
    if (!lower.contains('dzcdn.net') && !lower.contains('deezer.com')) {
      return null;
    }
    return const {
      'Referer': 'https://www.deezer.com/',
      'Origin': 'https://www.deezer.com',
      'Accept': 'audio/mpeg, audio/*;q=0.9, */*;q=0.8',
    };
  }

  Future<String?> ensureLocalFile({
    required String url,
    required String clipId,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('file://')) {
      return trimmed.replaceFirst('file://', '');
    }
    if (trimmed.startsWith('/') || (Platform.isWindows && trimmed.contains(':\\'))) {
      return trimmed;
    }

    final cached = _urlToPath[trimmed];
    if (cached != null && await File(cached).exists()) return cached;

    final dir = await getTemporaryDirectory();
    final safeId = clipId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final outPath = '${dir.path}/reel_audio_$safeId.mp3';

    if (await File(outPath).exists()) {
      _urlToPath[trimmed] = outPath;
      return outPath;
    }

    final headers = _previewHeadersForUrl(trimmed);
    final response = await http.get(Uri.parse(trimmed), headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    await File(outPath).writeAsBytes(response.bodyBytes);
    _urlToPath[trimmed] = outPath;
    return outPath;
  }

  Future<void> clearClip(String clipId) async {
    final dir = await getTemporaryDirectory();
    final safeId = clipId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final path = '${dir.path}/reel_audio_$safeId.mp3';
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
