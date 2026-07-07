import 'dart:math' as math;

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

import 'safe_better_player.dart';

/// Letterboxed reel player for the home-feed tile (9:16 frame, black bars).
class HomeFeedReelPlayerCover extends StatefulWidget {
  const HomeFeedReelPlayerCover({super.key, required this.controller});

  final BetterPlayerController controller;

  @override
  State<HomeFeedReelPlayerCover> createState() =>
      _HomeFeedReelPlayerCoverState();
}

class _HomeFeedReelPlayerCoverState extends State<HomeFeedReelPlayerCover> {
  Size? _videoSize;
  dynamic _listenedVpc;

  @override
  void initState() {
    super.initState();
    _attachListeners();
  }

  @override
  void didUpdateWidget(covariant HomeFeedReelPlayerCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachListeners(oldWidget.controller);
      _videoSize = null;
      _attachListeners();
    }
  }

  void _attachListeners() {
    widget.controller.addEventsListener(_onControllerEvent);
    final vpc = widget.controller.videoPlayerController;
    if (vpc != null) {
      _listenedVpc = vpc;
      vpc.addListener(_onVideoValueChanged);
      _checkAndStoreSize(vpc.value.size);
    }
  }

  void _detachListeners(BetterPlayerController controller) {
    try {
      (_listenedVpc as dynamic)?.removeListener(_onVideoValueChanged);
    } catch (_) {}
    _listenedVpc = null;
    try {
      controller.removeEventsListener(_onControllerEvent);
    } catch (_) {}
  }

  void _onControllerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType != BetterPlayerEventType.initialized) {
      return;
    }
    final vpc = widget.controller.videoPlayerController;
    if (vpc != null && !identical(_listenedVpc, vpc)) {
      try {
        _listenedVpc?.removeListener(_onVideoValueChanged);
      } catch (_) {}
      _listenedVpc = vpc;
      vpc.addListener(_onVideoValueChanged);
    }
    _checkAndStoreSize(vpc?.value.size);
  }

  void _onVideoValueChanged() {
    final vpc = _listenedVpc;
    if (vpc == null) return;
    _checkAndStoreSize(vpc.value.size);
  }

  void _checkAndStoreSize(Size? size) {
    if (size == null || size.width <= 0 || size.height <= 0) return;
    if (_videoSize == size) return;
    if (!mounted) return;
    try {
      widget.controller.setOverriddenAspectRatio(size.width / size.height);
      widget.controller.setOverriddenFit(BoxFit.contain);
    } catch (_) {}
    setState(() {
      _videoSize = size;
    });
  }

  @override
  void dispose() {
    _detachListeners(widget.controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = SafeBetterPlayerWrapper(
      key: ObjectKey(widget.controller),
      controller: widget.controller,
    );

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameW = constraints.maxWidth;
          final frameH = constraints.maxHeight;
          final size = _videoSize;
          if (size == null) {
            return SizedBox.expand(child: player);
          }
          final scale = math.min(frameW / size.width, frameH / size.height);
          return ClipRect(
            child: SizedBox(
              width: frameW,
              height: frameH,
              child: Center(
                child: SizedBox(
                  width: size.width * scale,
                  height: size.height * scale,
                  child: player,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
