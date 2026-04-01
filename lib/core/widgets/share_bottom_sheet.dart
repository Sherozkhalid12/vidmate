import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/utils/theme_helper.dart';
import '../../core/utils/share_link_helper.dart';
import '../../core/providers/follow_provider_riverpod.dart';
import '../../services/posts/posts_service.dart';
import '../../services/chat/chat_service.dart';

/// Share bottom sheet widget (Instagram-style)
class ShareBottomSheet extends StatelessWidget {
  final String? postId;
  final String? videoUrl;
  final String? imageUrl;

  const ShareBottomSheet({
    super.key,
    this.postId,
    this.videoUrl,
    this.imageUrl,
  });

  static Color _alpha(Color c, double opacity) =>
      c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final following = ref.watch(followingListProvider);
        if (following.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => ref.read(followProvider.notifier).ensureFollowListsLoaded(),
          );
        }
        final shareUsers = following.take(8).toList();

        final postId = this.postId;
        final sharedLink = (postId != null && postId.isNotEmpty)
            ? ShareLinkHelper.build(
                contentId: postId,
                thumbnailUrl: imageUrl,
              )
            : null;

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              gradient: ThemeHelper.getBackgroundGradient(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: _alpha(Colors.black, 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _alpha(ThemeHelper.getTextMuted(context), 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Share',
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Text(
                          'Following',
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: shareUsers.length,
                          itemBuilder: (context, index) {
                            final user = shareUsers[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: _alpha(ThemeHelper.getSurfaceColor(context), 0.55),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _alpha(ThemeHelper.getBorderColor(context), 0.7),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                                  backgroundColor: ThemeHelper.getSurfaceColor(context),
                                ),
                                title: Text(
                                  user.username,
                                  style: TextStyle(
                                    color: ThemeHelper.getTextPrimary(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  user.displayName,
                                  style: TextStyle(
                                    color: ThemeHelper.getTextSecondary(context),
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.send_rounded,
                                    color: ThemeHelper.getAccentColor(context),
                                  ),
                                  onPressed: () async {
                                    if (sharedLink == null || postId == null) return;
                                    Navigator.pop(context);

                                    () async {
                                      await PostsService().sharePost(postId);
                                      // Use dedicated chat endpoint so backend includes post data in the message.
                                      await ChatService().sharePost(
                                        postIdOrLink: postId,
                                        receiverId: user.id,
                                      );
                                    }();

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Shared with ${user.username}'),
                                        backgroundColor: ThemeHelper.getAccentColor(context),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getBackgroundColor(context),
                          border: Border(
                            top: BorderSide(
                              color: _alpha(ThemeHelper.getBorderColor(context), 0.5),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: _buildShareOption(
                          context,
                          icon: Icons.link,
                          label: 'Copy Link',
                          onTap: () {
                            if (sharedLink == null) return;
                            Navigator.pop(context);
                            Clipboard.setData(ClipboardData(text: sharedLink));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Link copied!',
                                  style: TextStyle(
                                    color: ThemeHelper.getTextPrimary(context),
                                  ),
                                ),
                                backgroundColor:
                                    _alpha(ThemeHelper.getSurfaceColor(context), 0.95),
                              ),
                            );
                          },
                        ),
                      ),]
                    ),
                  ),
                
              ],
            ),
          
        ));
    }
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _alpha(ThemeHelper.getSurfaceColor(context), 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeHelper.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: ThemeHelper.getAccentColor(context),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: ThemeHelper.getTextMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}
