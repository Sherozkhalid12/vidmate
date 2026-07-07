import 'package:flutter/material.dart';
import 'notifications_screen.dart';

/// Notifications tab — embeds [NotificationsScreen] in the bottom nav.
class NotificationsPage extends StatelessWidget {
  final double bottomPadding;

  const NotificationsPage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 0),
        child: const NotificationsScreen(),
      ),
    );
  }
}
