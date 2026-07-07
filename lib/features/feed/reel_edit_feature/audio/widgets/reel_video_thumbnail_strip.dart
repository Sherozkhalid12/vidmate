import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reel_video_thumbnails_provider.dart';

class ReelVideoThumbnailStrip extends ConsumerWidget {
  const ReelVideoThumbnailStrip({
    super.key,
    required this.videoPath,
    required this.durationSec,
    required this.pixelsPerSecond,
    required this.width,
  });

  final String videoPath;
  final double durationSec;
  final double pixelsPerSecond;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbsAsync = ref.watch(
      reelVideoThumbnailsProvider(
        ReelVideoThumbnailsRequest(
          videoPath: videoPath,
          durationSec: durationSec,
        ),
      ),
    );

    return thumbsAsync.when(
      loading: () => _placeholderStrip(),
      error: (_, __) => _placeholderStrip(),
      data: (frames) {
        if (frames.isEmpty) return _placeholderStrip();
        return SizedBox(
          width: width,
          height: 28,
          child: Row(
            children: [
              for (var i = 0; i < frames.length; i++) ...[
                if (i > 0) const SizedBox(width: 1),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white10),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Image.memory(
                      frames[i].bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _placeholderStrip() {
    final count = (durationSec / 1.5).ceil().clamp(4, 16);
    return SizedBox(
      width: width,
      height: 28,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 1),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFF334155),
                    const Color(0xFF475569),
                    i / count,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
