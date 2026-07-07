import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/app_media_cache.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/theme_helper.dart';
import '../../../core/widgets/music_sticker_row.dart';
import '../content_preview_draft.dart';
import '../../../core/widgets/natural_aspect_image.dart';
import '../create_content_screen.dart';

/// Feed-faithful preview card (local files) for post / reel / story / long video.
class ContentPreviewDisplay extends ConsumerWidget {
  final ContentPreviewDraft draft;

  const ContentPreviewDisplay({super.key, required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PreviewAuthorHeader(author: draft.author),
        _PreviewMedia(draft: draft),
        if (draft.hasMusicLine &&
            (draft.type == ContentType.post ||
                draft.type == ContentType.reel ||
                draft.type == ContentType.story))
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: MusicStickerRow(
              previewUrl: draft.musicPreviewUrl,
              musicName: draft.musicName,
              musicTitle: draft.musicTitle,
              padding: const EdgeInsets.only(top: 4),
            ),
          ),
        if (draft.displayCaption.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Text(
              draft.displayCaption.trim(),
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        if (draft.location != null || draft.taggedUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (draft.location != null && draft.location!.isNotEmpty)
                  _chip(context, Icons.location_on_outlined, draft.location!),
                for (final t in draft.taggedUsers.take(4))
                  _chip(context, Icons.alternate_email, t),
              ],
            ),
          ),
      ],
    );

    return isDark
        ? card
        : ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.35),
                ),
              ),
              child: card,
            ),
          );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ThemeHelper.getSurfaceColor(context).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ThemeHelper.getAccentColor(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: ThemeHelper.getTextSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewAuthorHeader extends StatelessWidget {
  final UserModel author;

  const _PreviewAuthorHeader({required this.author});

  @override
  Widget build(BuildContext context) {
    final name = author.displayName.isNotEmpty
        ? author.displayName
        : (author.username.isNotEmpty ? author.username : 'You');
    final avatar = author.avatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ClipOval(
            child: avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    cacheManager: AppMediaCache.feedMedia,
                    errorWidget: (_, __, ___) => _avatarFallback(context),
                  )
                : _avatarFallback(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Preview',
                  style: TextStyle(
                    color: ThemeHelper.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      color: ThemeHelper.getSurfaceColor(context),
      child: Icon(
        CupertinoIcons.person_crop_circle,
        color: ThemeHelper.getTextSecondary(context),
        size: 22,
      ),
    );
  }
}

class _PreviewMedia extends StatelessWidget {
  final ContentPreviewDraft draft;

  const _PreviewMedia({required this.draft});

  @override
  Widget build(BuildContext context) {
    switch (draft.type) {
      case ContentType.post:
        return _buildPostPreview(context);
      case ContentType.reel:
        return _buildReelPreview(context);
      case ContentType.story:
        return _buildStoryPreview(context);
      case ContentType.longVideo:
        return _buildLongVideoPreview(context);
      case ContentType.live:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPostPreview(BuildContext context) {
    if (draft.postVideo != null) {
      return _MediaFrame(
        aspectRatio: 4 / 5,
        child: _videoOrImage(
          cover: draft.postVideoCover,
          video: draft.postVideo,
        ),
      );
    }
    if (draft.postImages.isEmpty) {
      return const SizedBox.shrink();
    }
    if (draft.postImages.length == 1) {
      return _MediaFrame(
        aspectRatio: 4 / 5,
        child: Image.file(draft.postImages.first, fit: BoxFit.cover),
      );
    }
    return _MediaFrame(
      aspectRatio: 4 / 5,
      child: PageView.builder(
        itemCount: draft.postImages.length,
        itemBuilder: (_, i) => Image.file(
          draft.postImages[i],
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildReelPreview(BuildContext context) {
    return _MediaFrame(
      aspectRatio: 9 / 16,
      maxHeight: MediaQuery.sizeOf(context).height * 0.52,
      child: _videoOrImage(cover: draft.reelCover, video: draft.reelVideo),
    );
  }

  Widget _buildStoryPreview(BuildContext context) {
    if (draft.storyMedia.isEmpty) return const SizedBox.shrink();
    final first = draft.storyMedia.first;
    if (first.isVideo) {
      return StoryPhonePreviewFrame(
        maxWidth: 220,
        maxHeight: MediaQuery.sizeOf(context).height * 0.52,
        innerChild: _videoOrImage(cover: null, video: first.file),
      );
    }
    return StoryPhonePreviewFrame(
      imageFile: first.file,
      maxWidth: 220,
      maxHeight: MediaQuery.sizeOf(context).height * 0.52,
    );
  }

  Widget _buildLongVideoPreview(BuildContext context) {
    return _MediaFrame(
      aspectRatio: 16 / 9,
      child: _videoOrImage(
        cover: draft.longVideoCover,
        video: draft.longVideoFile,
      ),
    );
  }

  Widget _videoOrImage({File? cover, File? video}) {
    if (cover != null && cover.path.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(cover, fit: BoxFit.cover),
          const _PlayBadge(),
        ],
      );
    }
    if (video != null && video.path.isNotEmpty) {
      return const Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Color(0xFF0D0D0D)),
          _PlayBadge(),
        ],
      );
    }
    return const ColoredBox(color: Color(0xFF0D0D0D));
  }
}

class _MediaFrame extends StatelessWidget {
  final double aspectRatio;
  final double? maxHeight;
  final double? maxWidth;
  final bool centered;
  final double borderRadius;
  final Widget child;

  const _MediaFrame({
    required this.aspectRatio,
    required this.child,
    this.maxHeight,
    this.maxWidth,
    this.centered = false,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget media = AspectRatio(aspectRatio: aspectRatio, child: child);
    if (maxHeight != null) {
      media = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: media,
      );
    }
    if (maxWidth != null) {
      media = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: media,
      );
    }
    if (borderRadius > 0) {
      media = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: media,
      );
    }
    if (centered) {
      media = Center(child: media);
    }
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: centered ? 0 : 0,
        vertical: centered ? 8 : 0,
      ),
      child: media,
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}
