import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';

/// Safe wrapper for BetterPlayer that checks controller validity before use
/// Prevents "VideoPlayerController was used after being disposed" errors
class SafeBetterPlayerWrapper extends StatefulWidget {
  final BetterPlayerController controller;

  const SafeBetterPlayerWrapper({super.key, required this.controller});

  @override
  State<SafeBetterPlayerWrapper> createState() => _SafeBetterPlayerWrapperState();
}

class _SafeBetterPlayerWrapperState extends State<SafeBetterPlayerWrapper> {
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    // Verify controller is valid before building
    _checkControllerValidity();
  }

  void _checkControllerValidity() {
    try {
      // Try to access controller properties to verify it's not disposed
      final _ = widget.controller.videoPlayerController;
      _isValid = true;
    } catch (e) {
      // Controller is disposed or invalid
      _isValid = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValid) {
      // Return placeholder if controller is invalid
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

    try {
      return BetterPlayer(controller: widget.controller);
    } catch (e) {
      // Controller was disposed during build, show placeholder
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isValid = false;
            });
          }
        });
      }
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
  }
}
