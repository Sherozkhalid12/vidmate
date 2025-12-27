import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/theme_helper.dart';

/// Glassmorphism button with glow effect
class GlassButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.padding,
    this.isLoading = false,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.onPressed != null && !widget.isLoading) {
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              padding: widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                // Use theme-aware button color instead of purple gradient
                gradient: widget.backgroundColor == null
                    ? LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.onPressed != null && !widget.isLoading
                    ? [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.textColor ?? ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                    )
                  else if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: widget.textColor ?? Theme.of(context).colorScheme.onPrimary, // Theme-aware icon color
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.textColor ?? Theme.of(context).colorScheme.onPrimary, // Theme-aware text color
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


