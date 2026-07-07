import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/theme_helper.dart';

/// Fixed 9:16 phone frame; inner media uses [BoxFit.contain] like the story viewer.
class StoryPhonePreviewFrame extends StatelessWidget {
  final File? imageFile;
  final Widget? innerChild;
  final double maxWidth;
  final double maxHeight;
  final double borderRadius;
  final List<Widget> overlays;

  const StoryPhonePreviewFrame({
    super.key,
    this.imageFile,
    this.innerChild,
    this.maxWidth = 220,
    this.maxHeight = 360,
    this.borderRadius = 18,
    this.overlays = const [],
  }) : assert(
          imageFile != null || innerChild != null,
          'Provide imageFile or innerChild',
        );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(borderRadius + 2),
              border: Border.all(
                color: ThemeHelper.getBorderColor(context),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  if (imageFile != null)
                    Center(
                      child: Image.file(
                        imageFile!,
                        fit: BoxFit.contain,
                      ),
                    )
                  else if (innerChild != null)
                    Center(child: innerChild),
                  ...overlays,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// In viewer / tray: show local file instantly when CDN URL is not ready yet.
class StoryMediaImage extends StatelessWidget {
  final String imageUrl;
  final String? localFilePath;
  final BoxFit fit;
  final VoidCallback? onDisplayed;
  final Widget? placeholder;

  const StoryMediaImage({
    super.key,
    required this.imageUrl,
    this.localFilePath,
    this.fit = BoxFit.contain,
    this.onDisplayed,
    this.placeholder,
  });

  void _notifyDisplayedOnce(VoidCallback? cb, _DisplayedOnce token) {
    if (cb == null || token.called) return;
    token.called = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => cb());
  }

  @override
  Widget build(BuildContext context) {
    final token = _DisplayedOnce();
    final ph = placeholder ?? const ColoredBox(color: Colors.black);

    if (localFilePath != null && localFilePath!.isNotEmpty) {
      final file = File(localFilePath!);
      return Image.file(
        file,
        fit: fit,
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded || frame != null) {
            _notifyDisplayedOnce(onDisplayed, token);
          }
          return frame == null ? ph : child;
        },
        errorBuilder: (_, __, ___) => ph,
      );
    }

    if (imageUrl.isEmpty) return ph;

    return Image.network(
      imageUrl,
      fit: fit,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded || frame != null) {
          _notifyDisplayedOnce(onDisplayed, token);
        }
        return frame == null ? ph : child;
      },
      errorBuilder: (_, __, ___) => ph,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : ph,
    );
  }
}

class _DisplayedOnce {
  bool called = false;
}
