import 'package:flutter/material.dart';
import 'music_screen.dart';

/// Music Page - wrapper for MusicScreen
class MusicPage extends StatelessWidget {
  final double bottomPadding;

  const MusicPage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: const MusicScreen(),
    );
  }
}
