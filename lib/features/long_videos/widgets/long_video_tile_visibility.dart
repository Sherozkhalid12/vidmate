import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../providers/long_video_autoplay_manager.dart';

/// Reports [visibleFraction] to [longVideoAutoplayManagerProvider] and removes
/// the id on dispose (Section 3).
class LongVideoTileVisibility extends ConsumerStatefulWidget {
  final String videoId;
  final Widget child;

  const LongVideoTileVisibility({
    super.key,
    required this.videoId,
    required this.child,
  });

  @override
  ConsumerState<LongVideoTileVisibility> createState() =>
      _LongVideoTileVisibilityState();
}

class _LongVideoTileVisibilityState extends ConsumerState<LongVideoTileVisibility> {
  final GlobalKey _tileRenderKey = GlobalKey();

  @override
  void dispose() {
    ref.read(longVideoAutoplayManagerProvider.notifier).removeVideo(widget.videoId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('lv_tile_${widget.videoId}'),
      onVisibilityChanged: (info) {
        // 0.4.x VisibilityInfo has no global bounds; anchor from the tile RenderBox.
        var verticalAnchorNorm = 0.5;
        if (mounted) {
          final ro =
              _tileRenderKey.currentContext?.findRenderObject() as RenderBox?;
          if (ro != null && ro.hasSize && ro.attached) {
            final mq = MediaQuery.of(context);
            final top = mq.padding.top;
            final usableH = (mq.size.height - top).clamp(1.0, double.infinity);
            final centerY =
                ro.localToGlobal(Offset.zero).dy + ro.size.height / 2;
            verticalAnchorNorm =
                ((centerY - top) / usableH).clamp(0.0, 1.0);
          }
        }
        ref.read(longVideoAutoplayManagerProvider.notifier).reportVisibility(
              widget.videoId,
              info.visibleFraction,
              verticalAnchorNorm: verticalAnchorNorm,
            );
      },
      child: KeyedSubtree(
        key: _tileRenderKey,
        child: widget.child,
      ),
    );
  }
}
