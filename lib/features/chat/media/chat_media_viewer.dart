import 'package:flutter/material.dart';

import 'chat_media_grid_screen.dart';
import 'chat_media_models.dart';
import 'chat_media_preview_screen.dart';

/// Opens the swipeable full-screen viewer (Instagram-style) at [initialIndex].
Future<void> openChatMediaViewer(
  BuildContext context,
  List<ChatMediaItem> items, {
  int initialIndex = 0,
}) {
  if (items.isEmpty) return Future<void>.value();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) =>
          ChatMediaPreviewScreen(items: items, initialIndex: initialIndex),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

/// Opens a grid of all [items] first, then the viewer on tap.
/// Used when a collage is tapped (multiple media in one message run).
Future<void> openChatMediaGrid(
  BuildContext context,
  List<ChatMediaItem> items, {
  String title = 'Media',
}) {
  if (items.isEmpty) return Future<void>.value();
  if (items.length == 1) {
    return openChatMediaViewer(context, items);
  }
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatMediaGridScreen(items: items, title: title),
    ),
  );
}
