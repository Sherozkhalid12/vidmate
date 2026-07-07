import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_bubble.dart';
import '../models/message_model.dart';
import '../providers/shared_post_preview_resolver_provider_riverpod.dart';
import '../utils/shared_post_navigation.dart';
import '../utils/theme_helper.dart';
import '../utils/video_thumbnail_helper.dart';
import '../media/app_media_cache.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

/// Tappable preview for a shared post / reel / long video in chat.
class SharedPostMessageBubble extends ConsumerWidget {
  final MessageModel message;
  final BorderRadius borderRadius;

  const SharedPostMessageBubble({
    super.key,
    required this.message,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  String? _thumbUrl(PostPreview? preview) {
    if (preview != null) {
      final t = preview.effectiveThumbnailUrl;
      if (t != null && t.isNotEmpty) return t;
      if (preview.effectiveVideoUrl.isNotEmpty) {
        return VideoThumbnailHelper.thumbnailFromVideoUrl(
          preview.effectiveVideoUrl,
        );
      }
    }
    final m = message.mediaUrl?.trim() ?? '';
    if (m.isNotEmpty && !_looksLikeVideoUrl(m)) return m;
    return null;
  }

  bool _looksLikeVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.webm') ||
        lower.contains('/playlist.');
  }

  _SharedContentKind _kind(PostPreview? preview) {
    if (preview != null) {
      final t = preview.type.toLowerCase();
      if (t == 'reel') return _SharedContentKind.reel;
      if (t == 'longvideo' || t == 'long_video') {
        return _SharedContentKind.longVideo;
      }
      if (preview.effectiveVideoUrl.isNotEmpty) return _SharedContentKind.reel;
    }
    if (message.type == MessageType.video) return _SharedContentKind.reel;
    return _SharedContentKind.post;
  }

  String _label(_SharedContentKind kind) {
    switch (kind) {
      case _SharedContentKind.reel:
        return 'Reel';
      case _SharedContentKind.longVideo:
        return 'Video';
      case _SharedContentKind.post:
        return 'Post';
    }
  }

  IconData _labelIcon(_SharedContentKind kind) {
    switch (kind) {
      case _SharedContentKind.reel:
        return Icons.play_circle_outline_rounded;
      case _SharedContentKind.longVideo:
        return Icons.movie_outlined;
      case _SharedContentKind.post:
        return Icons.grid_on_rounded;
    }
  }

  double get _cardWidth => 252;

  double _cardHeight(_SharedContentKind kind) {
    switch (kind) {
      case _SharedContentKind.reel:
        return 380;
      case _SharedContentKind.longVideo:
        return 148;
      case _SharedContentKind.post:
        return 300;
    }
  }

  String? _authorLine(PostPreview? preview) {
    final fromPreview = preview?.user;
    if (fromPreview != null) {
      for (final key in ['username', 'displayName', 'name']) {
        final v = fromPreview[key]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v.startsWith('@') ? v : '@$v';
      }
    }
    final sender = message.sender.username.trim();
    if (sender.isNotEmpty) return sender.startsWith('@') ? sender : '@$sender';
    final name = message.sender.displayName.trim();
    if (name.isNotEmpty) return name;
    return null;
  }

  String? _captionLine(PostPreview? preview) {
    final text = message.text.trim();
    if (text.isNotEmpty) return text;
    final cap = preview?.caption.trim() ?? '';
    return cap.isNotEmpty ? cap : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var preview = message.sharedPostPreview;
    final postId = message.sharedPostId ?? preview?.id ?? '';

    final needsResolve =
        postId.isNotEmpty && (_thumbUrl(preview) == null || preview == null);
    if (needsResolve) {
      final resolved = ref.watch(sharedPostPreviewResolverProvider(postId));
      preview = resolved.asData?.value ?? preview;
    }

    final kind = _kind(preview);
    final thumb = _thumbUrl(preview);
    final author = _authorLine(preview);
    final caption = _captionLine(preview);
    final showPlay = kind != _SharedContentKind.post;
    final cardHeight = _cardHeight(kind);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          openSharedPostFromChat(
            context,
            ref,
            postId: postId,
            preview: preview,
          );
        },
        borderRadius: borderRadius,
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
            width: _cardWidth,
            height: cardHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb != null)
                  CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    cacheManager: AppMediaCache.feedMedia,
                    fadeInDuration: const Duration(milliseconds: 220),
                    errorWidget: (_, __, ___) => _placeholder(context, kind),
                  )
                else
                  _placeholder(context, kind),
                if (showPlay)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.85,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: caption != null ? 120 : 88,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _TypeChip(label: _label(kind), icon: _labelIcon(kind)),
                ),
                if (showPlay)
                  Center(
                    child: _FrostedPlayButton(
                      size: kind == _SharedContentKind.longVideo ? 40 : 48,
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (author != null)
                        Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      if (caption != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12,
                            height: 1.25,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, _SharedContentKind kind) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ThemeHelper.getSurfaceColor(context),
            ThemeHelper.getSurfaceColor(context).withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _labelIcon(kind),
          size: 40,
          color: ThemeHelper.getTextMuted(context),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

enum _SharedContentKind { reel, longVideo, post }

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.95)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrostedPlayButton extends StatelessWidget {
  const _FrostedPlayButton({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white.withValues(alpha: 0.95),
            size: size * 0.58,
          ),
        ),
      ),
    );
  }
}
