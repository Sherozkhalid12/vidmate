import 'package:flutter/material.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/theme_provider_riverpod.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import '../profile/edit/edit_profile_screen.dart';
import '../../core/services/mock_data_service.dart';
import 'privacy_security_screen.dart';
import 'language_screen.dart';
import 'help_center_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import '../analytics/analytics_screen.dart';
import '../copyright/copyright_screen.dart';
import '../auth/login_screen.dart';

/// Settings screen with grouped sections
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoPlayEnabled = true;
  bool _downloadEnabled = false;

  @override
  Widget build(BuildContext context) {
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
                'Settings',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(
                color: ThemeHelper.getTextPrimary(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
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
                  Divider(color: ThemeHelper.getBorderColor(context)),
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
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  _buildSettingTile(
                    icon: Icons.language,
                    title: 'Language',
                    trailing: Text(
                      'English',
                      style: TextStyle(
                        color: ThemeHelper.getTextSecondary(context),
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
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  // Dark mode toggle using Riverpod for super fast updates
                  Builder(
                    builder: (context) {
                      final isDarkMode = ref.watch(isDarkModeProvider);
                      final themeNotifier = ref.read(themeProvider.notifier);
                      return _buildSwitchTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark Mode',
                        value: isDarkMode,
                        onChanged: (value) {
                          themeNotifier.toggleTheme(); // Super fast async toggle
                        },
                      );
                    },
                  ),
                  Divider(color: ThemeHelper.getBorderColor(context)),
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
                  Divider(color: ThemeHelper.getBorderColor(context)),
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
                  Divider(color: ThemeHelper.getBorderColor(context)),
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
                  Divider(color: ThemeHelper.getBorderColor(context)),
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    trailing: Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: ThemeHelper.getTextSecondary(context),
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: ThemeHelper.getSecondaryBackgroundColor(context),
                          title: Text(
                            'About',
                            style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                          ),
                          content: Text(
                            'SocialVideo v1.0.0\n\nA next-generation social video platform combining the best of Instagram, YouTube, and Messenger.',
                            style: TextStyle(color: ThemeHelper.getTextSecondary(context)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'OK',
                                style: TextStyle(
                                  color: ThemeHelper.getAccentColor(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Divider(color: ThemeHelper.getBorderColor(context)),
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
                  Divider(color: ThemeHelper.getBorderColor(context)),
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
              backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.1),
              child: _buildSettingTile(
                icon: Icons.logout,
                title: 'Log Out',
                titleColor: Theme.of(context).colorScheme.error,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: ThemeHelper.getSecondaryBackgroundColor(context),
                      title: Text(
                        'Log Out',
                        style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
                      ),
                      content: Text(
                        'Are you sure you want to log out?',
                        style: TextStyle(color: ThemeHelper.getTextSecondary(context)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref.read(authProvider.notifier).logout();
                            ref.invalidate(postsProvider);
                            ref.invalidate(userPostsProvider);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Logged out successfully',
                                  style: TextStyle(
                                    color: ThemeHelper.getOnAccentColor(context),
                                  ),
                                ),
                                backgroundColor: ThemeHelper.getAccentColor(context),
                              ),
                            );
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          child: Text(
                            'Log Out',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
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
            )
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
              color: titleColor ?? ThemeHelper.getTextSecondary(context),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor ?? ThemeHelper.getTextPrimary(context),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: ThemeHelper.getAccentColor(context),
          ),
        ],
      ),
    );
  }
}

