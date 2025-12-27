import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

/// Terms of Service screen
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Terms of Service'),
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
                'Terms of Service',
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
                '1. Acceptance of Terms',
                'By accessing and using SocialVideo, you accept and agree to be bound by the terms and provision of this agreement.',
              ),
              _buildSection(
                context,
                '2. User Accounts',
                'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.',
              ),
              _buildSection(
                context,
                '3. User Content',
                'You retain all rights to any content you submit, post or display on or through SocialVideo. By submitting content, you grant us a worldwide, non-exclusive, royalty-free license to use, reproduce, and distribute your content.',
              ),
              _buildSection(
                context,
                '4. Prohibited Content',
                'You agree not to post content that is illegal, harmful, threatening, abusive, or violates any third-party rights. We reserve the right to remove any content that violates these terms.',
              ),
              _buildSection(
                context,
                '5. Intellectual Property',
                'All content on SocialVideo, including but not limited to text, graphics, logos, and software, is the property of SocialVideo or its content suppliers and is protected by copyright laws.',
              ),
              _buildSection(
                context,
                '6. Privacy',
                'Your use of SocialVideo is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices.',
              ),
              _buildSection(
                context,
                '7. Termination',
                'We may terminate or suspend your account and access to the service immediately, without prior notice, for any reason, including breach of these Terms of Service.',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                  foregroundColor: context.textPrimary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text('I Agree'),
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

