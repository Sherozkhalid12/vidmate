import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../media/app_media_cache.dart';

/// Opens a full-screen profile photo viewer (pinch-zoom).
Future<void> openProfilePhotoViewer(
  BuildContext context, {
  required String imageUrl,
  String? displayName,
}) {
  final url = imageUrl.trim();
  if (url.isEmpty) return Future.value();

  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ProfilePhotoViewerPage(
          imageUrl: url,
          displayName: displayName,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ProfilePhotoViewerPage extends StatelessWidget {
  const _ProfilePhotoViewerPage({
    required this.imageUrl,
    this.displayName,
  });

  final String imageUrl;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.black87),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                cacheManager: AppMediaCache.feedMedia,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.person,
                  color: Colors.white54,
                  size: 96,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (displayName != null && displayName!.trim().isNotEmpty)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    displayName!.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
