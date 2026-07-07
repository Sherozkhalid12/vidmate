import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';

import '../video_engine/video_engine_logger.dart';

/// Safe wrapper for BetterPlayer that checks controller validity before use
/// Prevents "VideoPlayerController was used after being disposed" errors
class SafeBetterPlayerWrapper extends StatefulWidget {
  final BetterPlayerController controller;

  const SafeBetterPlayerWrapper({super.key, required this.controller});

  @override
  State<SafeBetterPlayerWrapper> createState() => _SafeBetterPlayerWrapperState();
}

class _SafeBetterPlayerWrapperState extends State<SafeBetterPlayerWrapper> {
  bool _invalidController = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant SafeBetterPlayerWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _invalidController = false;
      _isDisposed = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Widget _fallback() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: Colors.white.withOpacity(0.5),
          size: 48,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_invalidController || _isDisposed) return _fallback();

    try {
      final vpc = widget.controller.videoPlayerController;
      if (vpc != null && vpc.value.hasError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _invalidController = true);
        });
        return _fallback();
      }
      return BetterPlayer(controller: widget.controller);
    } catch (e) {
      VideoEngineLogger.error('SAFE_PLAYER_BUILD_FAILED: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _invalidController = true);
      });
      return _fallback();
    }
  }
}
