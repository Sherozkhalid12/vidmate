import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/theme_helper.dart';

/// Reusable glassmorphism card widget with blur effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? blurRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.blurRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use original dark mode transparency (glassSurface = 8% white) for dark mode
    // Keep beautiful light mode transparency (lightGlassSurfaceMedium = 85% white) for light mode
    final defaultBgColor = backgroundColor ?? (isDark 
        ? AppColors.glassSurface  // Original dark mode: 8% white (more transparent)
        : AppColors.lightGlassSurfaceMedium); // Light mode: 85% white (beautiful)
    final blur = blurRadius ?? AppColors.blurMedium;
    final buttonColor = Theme.of(context).colorScheme.primary; // Theme-aware button color
    
    final card = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          margin: margin ?? EdgeInsets.zero,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: defaultBgColor,
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            // No border in both modes
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? AppColors.glassShadow 
                    : AppColors.lightGlassShadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          splashColor: buttonColor.withOpacity(0.1),
          highlightColor: buttonColor.withOpacity(0.05),
          child: card,
        ),
      );
    }

    return card;
  }
}

