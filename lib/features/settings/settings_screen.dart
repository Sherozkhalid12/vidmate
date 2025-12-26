import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/theme_provider.dart';
import '../profile/edit/edit_profile_screen.dart';
import '../../core/services/mock_data_service.dart';
import 'privacy_security_screen.dart';
import 'language_screen.dart';
import 'help_center_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import '../analytics/analytics_screen.dart';
import '../copyright/copyright_screen.dart';

/// Settings screen with grouped sections
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoPlayEnabled = true;
  bool _downloadEnabled = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark 
        ? context.backgroundColor 
        : AppColors.lightBackground;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account section
            _buildSectionTitle('Account'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            user: MockDataService.mockUsers[0],
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSettingTile(
                    icon: Icons.lock_outline,
                    title: 'Privacy & Security',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacySecurityScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSettingTile(
                    icon: Icons.language,
                    title: 'Language',
                    trailing: Text(
                      'English',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LanguageScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Preferences section
            _buildSectionTitle('Preferences'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                  Divider(color: context.borderColor),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return _buildSwitchTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark Mode',
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme(); // This is now async and saves to SharedPreferences
                        },
                      );
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSwitchTile(
                    icon: Icons.play_circle_outline,
                    title: 'Auto-play Videos',
                    value: _autoPlayEnabled,
                    onChanged: (value) {
                      setState(() {
                        _autoPlayEnabled = value;
                      });
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSwitchTile(
                    icon: Icons.download_outlined,
                    title: 'Download Over Wi-Fi Only',
                    value: _downloadEnabled,
                    onChanged: (value) {
                      setState(() {
                        _downloadEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Content Management
            _buildSectionTitle('Content Management'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.analytics_outlined,
                    title: 'Analytics',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSettingTile(
                    icon: Icons.copyright,
                    title: 'Copyright Management',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CopyrightScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Support section
            _buildSectionTitle('Support'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpCenterScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    trailing: Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: context.secondaryBackgroundColor,
                          title: Text(
                            'About',
                            style: TextStyle(color: context.textPrimary),
                          ),
                          content: Text(
                            'SocialVideo v1.0.0\n\nA next-generation social video platform combining the best of Instagram, YouTube, and Messenger.',
                            style: TextStyle(color: context.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSettingTile(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.borderColor),
                  _buildSettingTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Logout button
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              backgroundColor: AppColors.warning.withOpacity(0.1),
              child: _buildSettingTile(
                icon: Icons.logout,
                title: 'Log Out',
                titleColor: AppColors.warning,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: context.secondaryBackgroundColor,
                      title: Text(
                        'Log Out',
                        style: TextStyle(color: context.textPrimary),
                      ),
                      content: Text(
                        'Are you sure you want to log out?',
                        style: TextStyle(color: context.textSecondary),
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
                                content: Text('Logged out successfully'),
                                backgroundColor: AppColors.cyanGlow,
                              ),
                            );
                            // Navigate to login screen
                          },
                          child: Text(
                            'Log Out',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  );
                },
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

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? titleColor,
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
              color: titleColor ?? context.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor ?? context.textPrimary,
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

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
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
            child: Text(
              title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
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
}

