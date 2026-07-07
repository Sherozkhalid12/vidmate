import 'package:flutter/material.dart';

import '../media/chat_media_image.dart';
import '../media/chat_media_models.dart';

/// Premium collage for one or many chat media items.
///
/// Distinct from a basic grid: it uses an asymmetric "feature + stack" layout
/// for 3 items, a balanced 2x2 for 4, and a "+N" frosted overlay for 5+, with
/// hairline gaps and soft rounded corners. Each cell is tappable and Hero-tagged
/// so it can fly into the full-screen viewer.
class ChatMediaCollage extends StatelessWidget {
  final List<ChatMediaItem> items;
  final double maxWidth;
  final void Function(int index) onTapIndex;

  const ChatMediaCollage({
    super.key,
    required this.items,
    required this.maxWidth,
    required this.onTapIndex,
  });

  static const double _gap = 2.5;
  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: _layout(),
      ),
    );
  }

  Widget _layout() {
    final count = items.length;
    if (count == 1) {
      return _cell(0, aspectChild: true);
    }
    if (count == 2) {
      return SizedBox(
        height: maxWidth * 0.6,
        child: Row(
          children: [
            Expanded(child: _cell(0)),
            const SizedBox(width: _gap),
            Expanded(child: _cell(1)),
          ],
        ),
      );
    }
    if (count == 3) {
      return SizedBox(
        height: maxWidth * 0.7,
        child: Row(
          children: [
            Expanded(flex: 3, child: _cell(0)),
            const SizedBox(width: _gap),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(child: _cell(1)),
                  const SizedBox(height: _gap),
                  Expanded(child: _cell(2)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // 4+
    return SizedBox(
      height: maxWidth,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _cell(0)),
                const SizedBox(width: _gap),
                Expanded(child: _cell(1)),
              ],
            ),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _cell(2)),
                const SizedBox(width: _gap),
                Expanded(child: _cell(3, overflow: count > 4 ? count - 4 : 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int index, {bool aspectChild = false, int overflow = 0}) {
    final item = items[index];
    final image = ChatMediaImage(
      url: item.url,
      fit: BoxFit.cover,
      targetWidth: maxWidth,
    );

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        Hero(tag: item.heroTag, child: image),
        if (item.isVideo) _PlayBadge(compact: !aspectChild),
        if (overflow > 0)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.45),
            child: Center(
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: () => onTapIndex(index),
      // A single item drives its own height via aspect ratio; multi-cell
      // layouts are sized by their parent Row/Column and expand to fill.
      child: aspectChild ? AspectRatio(aspectRatio: 4 / 5, child: stack) : stack,
    );
  }
}

class _PlayBadge extends StatelessWidget {
  final bool compact;
  const _PlayBadge({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 52.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: compact ? 22 : 30,
        ),
      ),
    );
  }
}
