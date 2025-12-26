import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

/// Privacy Policy screen
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Privacy Policy'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: ${DateTime.now().toString().split(' ')[0]}',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                '1. Information We Collect',
                'We collect information you provide directly to us, such as when you create an account, post content, or communicate with us. This includes your name, email address, profile picture, and any content you upload.',
              ),
              _buildSection(
                context,
                '2. How We Use Your Information',
                'We use the information we collect to provide, maintain, and improve our services, process transactions, send you technical notices, and respond to your comments and questions.',
              ),
              _buildSection(
                context,
                '3. Information Sharing',
                'We do not sell, trade, or rent your personal information to third parties. We may share your information only in specific circumstances, such as with your consent or to comply with legal obligations.',
              ),
              _buildSection(
                context,
                '4. Data Security',
                'We implement appropriate security measures to protect your personal information. However, no method of transmission over the internet is 100% secure.',
              ),
              _buildSection(
                context,
                '5. Your Rights',
                'You have the right to access, update, or delete your personal information at any time through your account settings. You can also request a copy of your data.',
              ),
              _buildSection(
                context,
                '6. Cookies and Tracking',
                'We use cookies and similar tracking technologies to track activity on our service and hold certain information. You can instruct your browser to refuse all cookies.',
              ),
              _buildSection(
                context,
                '7. Children\'s Privacy',
                'Our service is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.',
              ),
              _buildSection(
                context,
                '8. Changes to This Policy',
                'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPurple,
                  foregroundColor: context.textPrimary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text('I Understand'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

