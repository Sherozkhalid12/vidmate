import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

/// Privacy & Security settings screen
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _privateAccount = false;
  bool _showActivityStatus = true;
  bool _allowComments = true;
  bool _allowLikes = true;
  bool _allowShares = true;
  bool _allowStoryReplies = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Privacy & Security'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
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
                    value: _privateAccount,
                    onChanged: (value) {
                      setState(() {
                        _privateAccount = value;
                      });
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSwitchTile(
                    icon: Icons.visibility,
                    title: 'Show Activity Status',
                    subtitle: 'Show when you were last active',
                    value: _showActivityStatus,
                    onChanged: (value) {
                      setState(() {
                        _showActivityStatus = value;
                      });
                    },
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
                    value: _allowComments,
                    onChanged: (value) {
                      setState(() {
                        _allowComments = value;
                      });
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSwitchTile(
                    icon: Icons.favorite,
                    title: 'Allow Likes',
                    value: _allowLikes,
                    onChanged: (value) {
                      setState(() {
                        _allowLikes = value;
                      });
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSwitchTile(
                    icon: Icons.share,
                    title: 'Allow Shares',
                    value: _allowShares,
                    onChanged: (value) {
                      setState(() {
                        _allowShares = value;
                      });
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSwitchTile(
                    icon: Icons.reply,
                    title: 'Allow Story Replies',
                    value: _allowStoryReplies,
                    onChanged: (value) {
                      setState(() {
                        _allowStoryReplies = value;
                      });
                    },
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
                      backgroundColor: AppColors.cyanGlow,
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
                  Divider(color: context.borderColor),
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
                          backgroundColor: AppColors.cyanGlow,
                        ),
                      );
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSettingTile(
                    icon: Icons.download,
                    title: 'Download Your Data',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Data download requested'),
                          backgroundColor: AppColors.cyanGlow,
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: context.textSecondary,
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
            color: context.textSecondary,
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
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textMuted,
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
              color: context.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null)
              Icon(
                Icons.chevron_right,
                color: context.textMuted,
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
          style: TextStyle(color: context.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordController,
                obscureText: true,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: context.textSecondary),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: context.textSecondary),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(color: context.textSecondary),
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
                  content: Text('Password changed successfully'),
                  backgroundColor: AppColors.cyanGlow,
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

