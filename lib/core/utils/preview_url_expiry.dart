/// Signed CDN preview URLs (e.g. Deezer) embed an `exp` Unix time after which
/// the CDN returns 403. Used by WorkManager prefetch and the Add Music screen.
bool isPreviewUrlExpired(String url) {
  if (url.trim().isEmpty) return true;
  try {
    final uri = Uri.parse(url);
    String? expStr = uri.queryParameters['exp'];
    if (expStr == null || expStr.isEmpty) {
      final hdnea = uri.queryParameters['hdnea'] ?? '';
      final match = RegExp(r'exp=(\d+)').firstMatch(hdnea);
      expStr = match?.group(1);
    }
    if (expStr == null || expStr.isEmpty) return true;
    final expiry = int.tryParse(expStr);
    if (expiry == null) return true;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= expiry;
  } catch (_) {
    return true;
  }
}
