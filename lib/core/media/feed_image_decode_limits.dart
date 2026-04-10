import 'package:flutter/widgets.dart';

/// Caps in-memory decode size for feed thumbnails (avoids 4K bitmaps × many tiles).
const int kFeedMemCacheMaxWidthPx = 720;
const int kFeedMemCacheMaxHeightPx = 960;

({int w, int h}) feedMemCacheDimensions(Size logicalSize, double dpr) {
  final rw =
      (logicalSize.width * dpr).round().clamp(1, kFeedMemCacheMaxWidthPx);
  final rh =
      (rw * 1.35).round().clamp(1, kFeedMemCacheMaxHeightPx);
  return (w: rw, h: rh);
}
