import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_button.dart';

/// Copyright management screen (frontend mock)
class CopyrightScreen extends StatefulWidget {
  const CopyrightScreen({super.key});

  @override
  State<CopyrightScreen> createState() => _CopyrightScreenState();
}

class _CopyrightScreenState extends State<CopyrightScreen> {
  final List<Map<String, dynamic>> _copyrightClaims = [
    {
      'id': '1',
      'contentType': 'Video',
      'contentTitle': 'My Amazing Video',
      'claimType': 'Audio Match',
      'matchConfidence': 85,
      'status': 'Pending',
      'date': DateTime.now().subtract(const Duration(days: 2)),
    },
    {
      'id': '2',
      'contentType': 'Video',
      'contentTitle': 'Travel Vlog',
      'claimType': 'Video Match',
      'matchConfidence': 92,
      'status': 'Resolved',
      'date': DateTime.now().subtract(const Duration(days: 5)),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Copyright Management'),
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
            // Info Card
            GlassCard(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Icon(
                    Icons.copyright,
                    size: 48,
                    color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Copyright Protection',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All uploaded content is automatically checked for copyright violations. You can review and dispute claims here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Check New Content
            GlassButton(
              text: 'Check Content for Copyright',
              icon: Icons.search,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Select content to check for copyright'),
                    backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                  ),
                );
              },
              width: double.infinity,
            ),
            const SizedBox(height: 24),
            // Claims List
            Text(
              'Copyright Claims',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_copyrightClaims.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(40),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Copyright Claims',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All your content is original',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._copyrightClaims.map((claim) => _buildClaimCard(claim)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final status = claim['status'] as String;
    final isPending = status == 'Pending';
    final confidence = claim['matchConfidence'] as int;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPending ? Icons.warning : Icons.check_circle,
                color: isPending ? AppColors.warning : ThemeHelper.getAccentColor(context), // Theme-aware accent color
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim['contentTitle'] as String,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      claim['contentType'] as String,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPending
                      ? AppColors.warning.withOpacity(0.2)
                      : ThemeHelper.getAccentColor(context).withOpacity(0.2), // Theme-aware accent with opacity
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isPending ? AppColors.warning : ThemeHelper.getAccentColor(context), // Theme-aware accent color
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildClaimInfo('Type', claim['claimType'] as String),
              ),
              Expanded(
                child: _buildClaimInfo('Confidence', '$confidence%'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Dispute submitted'),
                          backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                        ),
                      );
                    },
                    child: Text('Dispute'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        claim['status'] = 'Resolved';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                    ),
                    child: Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildClaimInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


