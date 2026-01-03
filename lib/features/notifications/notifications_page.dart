import 'package:flutter/material.dart';
import 'notifications_screen.dart';

/// Notifications Page - wrapper for NotificationsScreen
class NotificationsPage extends StatelessWidget {
  final double bottomPadding;

  const NotificationsPage({super.key, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: const NotificationsScreen(),
    );
  }
}







