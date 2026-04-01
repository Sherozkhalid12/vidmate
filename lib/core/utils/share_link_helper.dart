class ShareLinkPayload {
  final String? contentId;
  final String? thumbnailUrl;

  const ShareLinkPayload({
    this.contentId,
    this.thumbnailUrl,
  });
}

/// Builds a share link that can be pasted into chat.
///
/// Format:
/// `vidmate://share/<contentId>?thumb=<thumbnailUrl>`
///
/// The chat UI parses this to render the thumbnail preview.
class ShareLinkHelper {
  static String build({
    required String contentId,
    required String? thumbnailUrl,
  }) {
    final uri = Uri(
      scheme: 'vidmate',
      host: 'share',
      path: '/$contentId',
      queryParameters: thumbnailUrl != null && thumbnailUrl.isNotEmpty
          ? {'thumb': thumbnailUrl}
          : const {},
    );
    return uri.toString();
  }

  /// Parses [text] if it matches a `vidmate://share/<contentId>` link.
  static ShareLinkPayload parse(String text) {
    try {
      final t = text.trim();
      if (!t.startsWith('vidmate://share/')) return const ShareLinkPayload();
      final uri = Uri.tryParse(t);
      if (uri == null) return const ShareLinkPayload();
      if (uri.scheme != 'vidmate' || uri.host != 'share') {
        return const ShareLinkPayload();
      }

      final segments = uri.pathSegments;
      if (segments.isEmpty) return const ShareLinkPayload();

      final contentId = segments.firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final thumb = uri.queryParameters['thumb'];
      final decodedThumb =
          thumb != null && thumb.isNotEmpty ? Uri.decodeComponent(thumb) : null;

      return ShareLinkPayload(
        contentId: contentId.isEmpty ? null : contentId,
        thumbnailUrl: decodedThumb,
      );
    } catch (_) {
      return const ShareLinkPayload();
    }
  }
}

