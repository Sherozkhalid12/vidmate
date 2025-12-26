import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../theme/app_colors.dart';

/// Story avatar with animated gradient ring
class StoryAvatar extends StatefulWidget {
  final String imageUrl;
  final String? username;
  final bool isViewed;
  final bool isOwnStory;
  final VoidCallback? onTap;
  final double size;

  const StoryAvatar({
    super.key,
    required this.imageUrl,
    this.username,
    this.isViewed = false,
    this.isOwnStory = false,
    this.onTap,
    this.size = 70,
  });

  @override
  State<StoryAvatar> createState() => _StoryAvatarState();
}

class _StoryAvatarState extends State<StoryAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: widget.onTap,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Container(
                      width: widget.size + 4,
                      height: widget.size + 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.isViewed
                            ? null
                            : LinearGradient(
                                colors: [
                                  AppColors.neonPurple,
                                  AppColors.cyanGlow,
                                  AppColors.softBlue,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                transform: GradientRotation(
                                  _rotationAnimation.value * 2 * 3.14159,
                                ),
                              ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBackground,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            widget.imageUrl,
                            width: widget.size,
                            height: widget.size,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: widget.size,
                                height: widget.size,
                                color: AppColors.glassSurface,
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.textSecondary,
                                  size: widget.size * 0.5,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (widget.username != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: widget.size + 20,
                    child: Text(
                      widget.username!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


