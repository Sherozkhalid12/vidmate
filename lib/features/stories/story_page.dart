import 'package:flutter/material.dart';
import 'stories_viewer_screen.dart';

/// Story Page - wrapper for StoriesViewerScreen
class StoryPage extends StatelessWidget {
  final double bottomPadding;

  const StoryPage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: const StoriesViewerScreen(),
    );
  }
}

