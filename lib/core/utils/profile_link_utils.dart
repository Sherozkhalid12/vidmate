/// Extracts and normalizes a profile bio link for in-app WebView.
String? profileLinkDisplayText(String? bio, String username) {
  final url = profileLinkUrl(bio, username);
  if (url == null) return null;
  return profileLinkDomain(url);
}

/// Returns a fully qualified https URL only when the bio contains an explicit link.
String? profileLinkUrl(String? bio, String username) {
  if (bio == null || bio.trim().isEmpty) return null;

  final fromBio = _firstUrlInText(bio);
  if (fromBio != null) return _normalizeUrl(fromBio);

  return null;
}

/// Bio text with any embedded URL removed so the link is not shown twice.
String? profileBioText(String? bio) {
  if (bio == null || bio.trim().isEmpty) return null;

  final urlMatch = _firstUrlInText(bio);
  if (urlMatch == null) return bio.trim();

  var text = bio.replaceFirst(urlMatch, '').trim();
  text = text.replaceAll(RegExp(r'^[\s,·\-–—|]+'), '');
  text = text.replaceAll(RegExp(r'[\s,·\-–—|]+$'), '');
  return text.isEmpty ? null : text;
}

String profileLinkDomain(String url) {
  try {
    var host = Uri.parse(url).host;
    if (host.startsWith('www.')) host = host.substring(4);
    if (host.isNotEmpty) return host;
  } catch (_) {}
  return url
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'^www\.'), '')
      .split('/')
      .first;
}

String? _firstUrlInText(String text) {
  final pattern = RegExp(
    r'(https?://[^\s]+)|((?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?)',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(text.trim());
  return match?.group(0);
}

String _normalizeUrl(String raw) {
  var url = raw.trim();
  if (url.endsWith('.') || url.endsWith(',') || url.endsWith(')')) {
    url = url.substring(0, url.length - 1);
  }
  final lower = url.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return url;
  }
  if (lower.startsWith('www.')) {
    return 'https://$url';
  }
  return 'https://$url';
}
