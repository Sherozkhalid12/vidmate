import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

/// Help Center screen
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final List<Map<String, dynamic>> _helpCategories = [
    {
      'title': 'Getting Started',
      'icon': Icons.play_circle_outline,
      'items': [
        'How to create an account',
        'How to upload your first post',
        'How to follow other users',
        'Understanding the feed',
      ],
    },
    {
      'title': 'Account & Profile',
      'icon': Icons.person_outline,
      'items': [
        'Edit your profile',
        'Change your password',
        'Privacy settings',
        'Delete your account',
      ],
    },
    {
      'title': 'Posts & Stories',
      'icon': Icons.photo_library_outlined,
      'items': [
        'How to create a post',
        'How to upload a story',
        'Edit or delete posts',
        'Story privacy settings',
      ],
    },
    {
      'title': 'Videos & Reels',
      'icon': Icons.video_library_outlined,
      'items': [
        'Upload long videos',
        'Create reels',
        'Video quality settings',
        'Video compression',
      ],
    },
    {
      'title': 'Messaging',
      'icon': Icons.chat_bubble_outline,
      'items': [
        'Send messages',
        'Share media in chat',
        'Block users',
        'Report messages',
      ],
    },
    {
      'title': 'Safety & Privacy',
      'icon': Icons.security,
      'items': [
        'Report content',
        'Block users',
        'Privacy controls',
        'Data security',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Help Center'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Search help articles'),
                  backgroundColor: AppColors.cyanGlow,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Support
            GlassCard(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 48,
                    color: AppColors.neonPurple,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Need More Help?',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contact our support team',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening support chat...'),
                          backgroundColor: AppColors.cyanGlow,
                        ),
                      );
                    },
                    icon: Icon(Icons.chat),
                    label: Text('Contact Support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonPurple,
                      foregroundColor: context.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Help Categories
            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._helpCategories.map((category) {
              return _buildHelpCategory(category);
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCategory(Map<String, dynamic> category) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: ExpansionTile(
        leading: Icon(
          category['icon'] as IconData,
          color: AppColors.neonPurple,
        ),
        title: Text(
          category['title'] as String,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: (category['items'] as List<String>).map((item) {
          return ListTile(
            leading: Icon(
              Icons.help_outline,
              color: context.textMuted,
              size: 20,
            ),
            title: Text(
              item,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 14,
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening: $item'),
                  backgroundColor: AppColors.cyanGlow,
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}


