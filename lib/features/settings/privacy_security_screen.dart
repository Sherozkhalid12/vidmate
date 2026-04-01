import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/user_preferences_provider_riverpod.dart';

/// Privacy & Security settings screen
class PrivacySecurityScreen extends ConsumerStatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  ConsumerState<PrivacySecurityScreen> createState() =>
      _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends ConsumerState<PrivacySecurityScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userPreferencesProvider.notifier).loadFromStorage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(userPreferencesProvider).preferences;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: Column(
          children: [
            AppBar(
              title: Text(
                'Privacy & Security',
                style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Privacy
            _buildSectionTitle('Account Privacy'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.lock,
                    title: 'Private Account',
                    subtitle: 'Only approved followers can see your posts',
                    value: preferences.privateAccount,
                    onChanged: (value) => ref
                        .read(userPreferencesProvider.notifier)
                        .updatePreference(
                          update: (current) =>
                              current.copyWith(privateAccount: value),
                        ),
                  ),
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  _buildSwitchTile(
                    icon: Icons.visibility,
                    title: 'Show Activity Status',
                    subtitle: 'Show when you were last active',
                    value: preferences.showActivityStatus,
                    onChanged: (value) => ref
                        .read(userPreferencesProvider.notifier)
                        .updatePreference(
                          update: (current) =>
                              current.copyWith(showActivityStatus: value),
                        ),
                  ),
                ],
              ),
            ),
            // Content Privacy
            _buildSectionTitle('Content Privacy'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.comment,
                    title: 'Allow Comments',
                    subtitle: 'Control who can comment on your posts',
                    value: preferences.allowComments,
                    onChanged: (value) => ref
                        .read(userPreferencesProvider.notifier)
                        .updatePreference(
                          update: (current) =>
                              current.copyWith(allowComments: value),
                        ),
                  ),
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  _buildSwitchTile(
                    icon: Icons.favorite,
                    title: 'Allow Likes',
                    value: preferences.allowLikes,
                    onChanged: (value) => ref
                        .read(userPreferencesProvider.notifier)
                        .updatePreference(
                          update: (current) => current.copyWith(allowLikes: value),
                        ),
                  ),
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  _buildSwitchTile(
                    icon: Icons.share,
                    title: 'Allow Shares',
                    value: preferences.allowShares,
                    onChanged: (value) => ref
                        .read(userPreferencesProvider.notifier)
                        .updatePreference(
                          update: (current) =>
                              current.copyWith(allowShares: value),
                        ),
                  ),
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  _buildSwitchTile(
                    icon: Icons.reply,
                    title: 'Allow Story Replies',
                    value: preferences.allowStoryReplies,
                    onChanged: (value) => ref
                        .read(userPreferencesProvider.notifier)
                        .updatePreference(
                          update: (current) =>
                              current.copyWith(allowStoryReplies: value),
                        ),
                  ),
                ],
              ),
            ),
            // Blocked Users
            _buildSectionTitle('Blocked Users'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: _buildSettingTile(
                icon: Icons.block,
                title: 'Blocked Accounts',
                trailing: Text(
                  '0',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Blocked users list'),
                      backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                    ),
                  );
                },
              ),
            ),
            // Data & Security
            _buildSectionTitle('Data & Security'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.lock_reset,
                    title: 'Change Password',
                    onTap: () {
                      _showChangePasswordDialog();
                    },
                  ),
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  _buildSettingTile(
                    icon: Icons.security,
                    title: 'Two-Factor Authentication',
                    trailing: Text(
                      'Off',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Two-factor authentication setup'),
                          backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                        ),
                      );
                    },
                  ),
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  _buildSettingTile(
                    icon: Icons.download,
                    title: 'Download Your Data',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Data download requested',
                    style: TextStyle(color: ThemeHelper.getOnAccentColor(context)),
                  ),
                  backgroundColor: ThemeHelper.getAccentColor(context),
                ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: ThemeHelper.getTextSecondary(context),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: ThemeHelper.getTextSecondary(context),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: ThemeHelper.getTextSecondary(context),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null)
              Icon(
                Icons.chevron_right,
                color: ThemeHelper.getTextMuted(context),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        title: Text(
          'Change Password',
          style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordController,
                obscureText: true,
                style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: ThemeHelper.getTextSecondary(context)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: ThemeHelper.getTextSecondary(context)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(color: ThemeHelper.getTextSecondary(context)),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Password changed successfully',
                    style: TextStyle(color: ThemeHelper.getOnAccentColor(context)),
                  ),
                  backgroundColor: ThemeHelper.getAccentColor(context),
                ),
              );
            },
            child: Text('Change'),
          ),
        ],
      ),
    );
  }
}

