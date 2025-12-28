import 'package:flutter/material.dart';
import 'reels_screen.dart';

/// Reels Page - wrapper for ReelsScreen
class ReelsPage extends StatelessWidget {
  final double bottomPadding;

  const ReelsPage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: const ReelsScreen(),
    );
  }
}

