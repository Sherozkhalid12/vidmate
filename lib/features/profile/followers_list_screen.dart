import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/follow_provider_riverpod.dart';
import 'profile_screen.dart';

/// Followers/Following list screen. Uses API data when viewing current user's list.
class FollowersListScreen extends ConsumerWidget {
  final String userId;
  final bool isFollowers; // true for followers, false for following

  const FollowersListScreen({
    super.key,
    required this.userId,
    this.isFollowers = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followState = ref.watch(followProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isCurrentUser = currentUserId != null && currentUserId == userId;
    final users = isCurrentUser
        ? (isFollowers ? followState.followersList : followState.followingList)
        : <UserModel>[];

    final isLoading = isCurrentUser && (isFollowers ? followState.isLoadingFollowers : followState.isLoadingFollowing);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(isFollowers ? 'Followers' : 'Following'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading && users.isEmpty
          ? Center(child: CircularProgressIndicator(color: ThemeHelper.getAccentColor(context)))
          : AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildUserCard(context, ref, users[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _buildUserCard(BuildContext context, WidgetRef ref, UserModel user) {
    final isFollowing = ref.watch(followProvider).followingIds.contains(user.id) || user.isFollowing;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final showFollowButton = currentUserId != null && currentUserId != user.id;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(user: user),
          ),
        );
      },
      child: Row(
        children: [
          Stack(
            children: [
              ClipOval(
                child: Image.network(
                  user.avatarUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      color: context.surfaceColor,
                      child: Icon(
                        Icons.person,
                        color: context.textSecondary,
                        size: 30,
                      ),
                    );
                  },
                ),
              ),
              if (user.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.backgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 14,
                  ),
                ),
                if (user.bio != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.bio!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showFollowButton)
            !isFollowing
                ? GestureDetector(
                    onTap: () => ref.read(followProvider.notifier).follow(user.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: ThemeHelper.getAccentGradient(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Follow',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => ref.read(followProvider.notifier).unfollow(user.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Text(
                        'Following',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}


