// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// Legacy commented-out inline player (package removed).
//
// import '../../../core/media/app_media_cache.dart';
// import '../../../core/models/post_model.dart';
// import '../../../core/utils/theme_helper.dart';
// import '../../../core/widgets/feed_cached_post_image.dart';
// import '../../../core/widgets/feed_image_precache.dart';
// import '../providers/long_video_widget_provider.dart';
//
// const double _kLongVideoPlayerHeight = 220;
//
// String _formatLongVideoDurationBadge(Duration duration) {
//   String twoDigits(int n) => n.toString().padLeft(2, '0');
//   final hours = duration.inHours;
//   final minutes = duration.inMinutes.remainder(60);
//   final seconds = duration.inSeconds.remainder(60);
//   if (hours > 0) {
//     return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
//   }
//   return '${twoDigits(minutes)}:${twoDigits(seconds)}';
// }
//
// /// Inline long-video surface for the Long Videos tab only.
// ///
// /// Shows the **API thumbnail** until playback; [Video] mounts only while [isPlaying]
// /// so warmed decoders never paint mid-roll frames over the poster.
// class LongVideoFeedPlayer extends ConsumerStatefulWidget {
//   final PostModel video;
//   final Future<void> Function() onOpenEmbedded;
//
//   const LongVideoFeedPlayer({
//     super.key,
//     required this.video,
//     required this.onOpenEmbedded,
//   });
//
//   @override
//   ConsumerState<LongVideoFeedPlayer> createState() =>
//       _LongVideoFeedPlayerState();
// }
//
// class _LongVideoFeedPlayerState extends ConsumerState<LongVideoFeedPlayer> {
//   @override
//   Widget build(BuildContext context) {
//     final videoUrl = widget.video.videoUrl;
//     if (videoUrl == null) {
//       return SizedBox(
//         width: double.infinity,
//         height: _kLongVideoPlayerHeight,
//         child: ColoredBox(
//           color: ThemeHelper.getSurfaceColor(context),
//           child: Icon(
//             Icons.video_library,
//             color: ThemeHelper.getTextSecondary(context),
//             size: 48,
//           ),
//         ),
//       );
//     }
//
//     final key = VideoWidgetKey(widget.video.id, videoUrl);
//     final widgetState = ref.watch(longVideoWidgetProvider(key));
//
//     final isVideoInitialized = widgetState.isInitialized;
//     final isPlaying = widgetState.isPlaying;
//
//     // Backend thumbnail until the user actually plays: mounting [Video] while paused
//     // at a non-zero decode position (warm/resume) leaks frames through opacity 0.
//     // While embedded is open, only the route mounts [Video] for this controller.
//     final inlineVideoHostElsewhere =
//         LongVideoEmbedGuard.blocksDecoderFor(widget.video.id);
//     // Only show the Video surface when playing AND position is confirmed
//     // near zero (for initial play) or any value (for resumed play after
//     // user interaction). This prevents the texture from flashing a mid-roll
//     // frame during the seek-to-zero window.
//     final showVideoSurface = isPlaying &&
//         isVideoInitialized &&
//         widgetState.videoController != null &&
//         !inlineVideoHostElsewhere &&
//         widgetState.phase == LongVideoTilePhase.active;
//
//     final rawThumb = widget.video.effectiveThumbnailUrl ??
//         widget.video.thumbnailUrl ??
//         widget.video.imageUrl ??
//         '';
//     final networkThumb =
//         rawThumb.isNotEmpty && !isProtectedVideoCdnThumbnailUrl(rawThumb)
//             ? rawThumb
//             : '';
//     final dpr = MediaQuery.devicePixelRatioOf(context);
//     final sw = MediaQuery.sizeOf(context).width;
//     final memW = (sw * dpr).round();
//     final memH = (_kLongVideoPlayerHeight * dpr).round();
//
//     return SizedBox(
//       width: double.infinity,
//       height: _kLongVideoPlayerHeight,
//       child: Stack(
//         clipBehavior: Clip.hardEdge,
//         children: [
//           // Black base + cached thumbnail always under the player so detach/handoff
//           // never shows an empty grey frame before the embedded route paints.
//           const ColoredBox(color: Colors.black),
//           if (networkThumb.isNotEmpty)
//             Positioned.fill(
//               child: FeedCachedPostImage(
//                 key: ValueKey<String>(
//                   'lv_thumb_${widget.video.id}_${networkThumb.hashCode}',
//                 ),
//                 imageUrl: networkThumb,
//                 postId: widget.video.id,
//                 blurHash: widget.video.blurHash,
//                 fit: BoxFit.cover,
//                 useShimmerWhileLoading: false,
//                 diskCacheManager: AppMediaCache.longVideoThumbnails,
//                 memCacheWidthOverride: memW,
//                 memCacheHeightOverride: memH,
//               ),
//             ),
//           if (showVideoSurface)
//             Positioned.fill(
//               child: RepaintBoundary(
//                 child: ClipRect(
//                   child: _FadeInInlineVideo(
//                     key: ObjectKey(widgetState.videoController!),
//                     controller: widgetState.videoController!,
//                   ),
//                 ),
//               ),
//             ),
//
//           // Explore/long-videos behavior: tapping the tile opens embedded only.
//           Positioned.fill(
//             child: GestureDetector(
//               behavior: HitTestBehavior.opaque,
//               onTap: widget.onOpenEmbedded,
//             ),
//           ),
//
//           if (widget.video.videoDuration != null)
//             Positioned(
//               bottom: 8,
//               right: 8,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withValues(alpha: 0.8),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Text(
//                   _formatLongVideoDurationBadge(widget.video.videoDuration!),
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// /// Delays showing the [Video] surface until the player has rendered at least
// /// one frame after play/seek. This prevents the Mali GPU texture pipeline
// /// from flashing a stale pre-buffered frame (e.g., 8 seconds into the video)
// /// when the actual playback position is 0:00.
// class _FadeInInlineVideo extends StatefulWidget {
//   const _FadeInInlineVideo({
//     super.key,
//     required this.controller,
//   });
//
//   final VideoController controller;
//
//   @override
//   State<_FadeInInlineVideo> createState() => _FadeInInlineVideoState();
// }
//
// class _FadeInInlineVideoState extends State<_FadeInInlineVideo>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _opacity;
//   bool _firstFrameReady = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _opacity = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 180),
//     );
//     _waitForFirstFrame();
//   }
//
//   void _waitForFirstFrame() {
//     // Wait for the Video widget to actually render a frame.
//     // On Android with software rendering (no HW accel for long videos),
//     // the first frame arrives after the seek completes and the surface
//     // is populated. We use a combination of:
//     // 1. A minimum delay to let the GPU pipeline flush
//     // 2. Checking that the player is actually playing
//     Future.delayed(const Duration(milliseconds: 250), () {
//       if (!mounted) return;
//       setState(() => _firstFrameReady = true);
//       _opacity.forward();
//     });
//   }
//
//   @override
//   void didUpdateWidget(covariant _FadeInInlineVideo oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.controller != widget.controller) {
//       _firstFrameReady = false;
//       _opacity.reset();
//       _waitForFirstFrame();
//     }
//   }
//
//   @override
//   void dispose() {
//     _opacity.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!_firstFrameReady) {
//       // Return an empty box so the Video widget is NOT in the tree yet.
//       // This prevents the texture from being sampled before the first
//       // real frame is rendered.
//       return const SizedBox.shrink();
//     }
//     return FadeTransition(
//       opacity: CurvedAnimation(parent: _opacity, curve: Curves.easeOut),
//       child: Video(
//         controller: widget.controller,
//         fit: BoxFit.cover,
//         controls: NoVideoControls,
//         wakelock: false,
//         pauseUponEnteringBackgroundMode: true,
//       ),
//     );
//   }
// }
