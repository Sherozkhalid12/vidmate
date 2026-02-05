import 'package:flutter/material.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  @override
  Widget build(BuildContext context) {
    final recentChats = MockDataService.mockUsers.take(8).toList();
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: ThemeHelper.getBackgroundColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ThemeHelper.getBorderColor(context),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Share',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Recent chats section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Recent',
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
                      itemCount: recentChats.length,
                      itemBuilder: (context, index) {
                        final user = recentChats[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 28,
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
                              Icons.send,
                              color: ThemeHelper.getAccentColor(context),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Shared with ${user.username}'),
                                  backgroundColor: ThemeHelper.getAccentColor(context),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Share options
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: ThemeHelper.getBorderColor(context),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  _buildShareOption(
                    context,
                    icon: Icons.link,
                    label: 'Copy Link',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Link copied to clipboard!',
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                            ),
                          ),
                          backgroundColor: ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildShareOption(
                    context,
                    icon: Icons.more_horiz,
                    label: 'More Options',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('More sharing options'),
                          backgroundColor: ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          color: ThemeHelper.getSurfaceColor(context).withOpacity(0.5),
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
