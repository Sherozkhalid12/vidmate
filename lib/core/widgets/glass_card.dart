import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable glassmorphism card widget
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
    final defaultBgColor = isDark 
        ? AppColors.glassSurface 
        : AppColors.lightSurface;
    final defaultBorderColor = isDark 
        ? AppColors.glassBorder 
        : AppColors.lightGlassBorder;
    
    final card = Container(
      width: width,
      height: height,
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBgColor,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? defaultBorderColor,
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          splashColor: AppColors.neonPurple.withOpacity(0.2),
          highlightColor: AppColors.neonPurple.withOpacity(0.1),
          child: card,
        ),
      );
    }

    return card;
  }
}

