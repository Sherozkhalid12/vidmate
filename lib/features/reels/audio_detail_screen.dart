import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/models/post_model.dart';
import '../feed/create_content_screen.dart';
import 'audio_reels_screen.dart';

/// Screen to preview an audio and use it for your own reel.
/// Shows a beautiful audio widget at top, grid of reels using this audio below,
/// and "Use" opens Create Content (Reel) with this audio selected.
class AudioDetailScreen extends StatelessWidget {
  final String audioId;
  final String audioName;
  final List<PostModel> reels;

  const AudioDetailScreen({
    super.key,
    required this.audioId,
    required this.audioName,
    required this.reels,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: ThemeHelper.getTextPrimary(context), size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Audio',
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Beautiful audio widget at top
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _AudioCard(
                audioName: audioName,
                onUse: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateContentScreen(
                        initialType: ContentType.reel,
                        selectedAudioId: audioId,
                        selectedAudioName: audioName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Reels with this audio',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          // Grid of reels
          reels.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No reels with this audio yet.',
                        style: TextStyle(
                          color: ThemeHelper.getTextMuted(context),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final reel = reels[index];
                        return _ReelGridTile(
                          reel: reel,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AudioReelsScreen(
                                  audioId: audioId,
                                  audioName: audioName,
                                  reels: reels,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: reels.length,
                    ),
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
          ),
        ),
      ),
    );
  }
}

class _AudioCard extends StatelessWidget {
  final String audioName;
  final VoidCallback onUse;

  const _AudioCard({required this.audioName, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final accent = ThemeHelper.getAccentColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final textMuted = ThemeHelper.getTextMuted(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.15),
            surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: accent,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original sound',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      audioName,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onUse,
              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: const Text('Use this audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: ThemeHelper.getOnAccentColor(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelGridTile extends StatelessWidget {
  final PostModel reel;
  final VoidCallback onTap;

  const _ReelGridTile({required this.reel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = reel.thumbnailUrl ?? reel.imageUrl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: ThemeHelper.getSurfaceColor(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Center(
                    child: Icon(
                      Icons.videocam,
                      color: ThemeHelper.getTextMuted(context),
                      size: 32,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Center(
                    child: Icon(
                      Icons.videocam,
                      color: ThemeHelper.getTextMuted(context),
                      size: 32,
                    ),
                  ),
                )
              else
                Center(
                  child: Icon(
                    Icons.videocam,
                    color: ThemeHelper.getTextMuted(context),
                    size: 32,
                  ),
                ),
              // Gradient overlay at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                    ),
                  ),
                ),
              ),
              // Play icon
              Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 36,
                ),
              ),
              // Like count if desired
              if (reel.likes > 0)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(reel.likes),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
