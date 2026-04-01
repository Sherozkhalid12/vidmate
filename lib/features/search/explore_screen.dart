import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/utils/theme_helper.dart';
import '../../core/providers/reels_provider_riverpod.dart';
import '../../core/models/post_model.dart';
import '../reels/reels_screen.dart';
import 'search_screen.dart';

/// Explore screen (for now: shows all reels in a staggered grid).
class ExploreScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;
  final double? bottomPadding;

  const ExploreScreen({super.key, this.onBackToHome, this.bottomPadding});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  static Color _alpha(Color c, double opacity) =>
      c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final reels = ref.watch(reelsListProvider);
    final loading = ref.watch(reelsLoadingProvider);
    final error = ref.watch(reelsErrorProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
          children: [
            // Top bar with back button and search
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: _alpha(ThemeHelper.getBorderColor(context), 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // iOS-style back button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (widget.onBackToHome != null) {
                        widget.onBackToHome!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.back,
                          color: ThemeHelper.getAccentColor(context),
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search bar
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchScreen(
                              bottomPadding: widget.bottomPadding,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ThemeHelper.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.search,
                              color: ThemeHelper.getTextSecondary(context),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Search',
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading && reels.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ThemeHelper.getAccentColor(context),
                      ),
                    )
                  : error != null && reels.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ThemeHelper.getTextMuted(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: ThemeHelper.getAccentColor(context),
                          onRefresh: () =>
                              ref.read(reelsProvider.notifier).refresh(),
                          child: _buildExploreGrid(reels),
                        ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildExploreGrid(List<PostModel> reels) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: (widget.bottomPadding ?? 0),
      ),
      child: MasonryGridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        itemCount: reels.length,
        itemBuilder: (context, index) {
          final reel = reels[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildExploreItem(reel),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExploreItem(PostModel reel) {
    final thumb = reel.effectiveThumbnailUrl ?? reel.thumbnailUrl ?? '';
    final likes = reel.likes;
    // Views are not currently present in PostModel/ReelModelApi; show 0 until backend provides it.
    final views = 0;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReelsScreen(initialPostId: reel.id)),
        );
      },
      child: AspectRatio(
        // Fixed ratio prevents Masonry/Sliver sizing assertion crashes.
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                // Distinct underscore names avoid duplicate identifier error.
                errorWidget: (_, __, ___) => Container(
                  color: ThemeHelper.getSurfaceColor(context),
                ),
              )
            else
              Container(
                color: ThemeHelper.getSurfaceColor(context),
              ),

            // Bottom-half overlay (modern gradient)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _alpha(Colors.black, 0.0),
                        _alpha(Colors.black, 0.0),
                        _alpha(Colors.black, 0.35),
                        _alpha(Colors.black, 0.75),
                      ],
                      stops: const [0.0, 0.45, 0.70, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom metrics (no containers)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  _metricInline(
                    icon: Icons.favorite_rounded,
                    value: _formatCount(likes),
                  ),
                  const SizedBox(width: 12),
                  _metricInline(
                    icon: Icons.remove_red_eye_rounded,
                    value: _formatCount(views),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricInline({required IconData icon, required String value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _alpha(Colors.white, 0.92)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: _alpha(Colors.white, 0.92),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: _alpha(Colors.black, 0.55),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
