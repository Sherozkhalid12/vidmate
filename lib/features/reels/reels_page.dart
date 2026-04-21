import 'package:flutter/material.dart';
import 'reels_screen.dart';

/// Reels tab with [AutomaticKeepAliveClientMixin] so list state survives tab switches.
class ReelsPage extends StatefulWidget {
  final double bottomPadding;

  const ReelsPage({super.key, required this.bottomPadding});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: ReelsScreen(
        key: const PageStorageKey<String>('reels_tab_scroll'),
        bottomPadding: widget.bottomPadding,
      ),
    );
  }
}
