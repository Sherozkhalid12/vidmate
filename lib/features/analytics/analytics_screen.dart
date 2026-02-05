import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

/// Analytics screen (frontend mock)
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'Last 7 Days';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Analytics'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
              const PopupMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
              const PopupMenuItem(value: 'Last 90 Days', child: Text('Last 90 Days')),
              const PopupMenuItem(value: 'All Time', child: Text('All Time')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _selectedPeriod,
                style: TextStyle(color: context.textPrimary),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Stats
            _buildSectionTitle('Overview'),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Daily Active Users',
                    '12.5K',
                    Icons.people,
                    ThemeHelper.getAccentColor(context), // Theme-aware accent color
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Views',
                    '1.2M',
                    Icons.visibility,
                    ThemeHelper.getAccentColor(context), // Theme-aware accent color
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Watch Time',
                    '45.2K hrs',
                    Icons.play_circle,
                    ThemeHelper.getAccentColor(context), // Theme-aware accent color
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Retention',
                    '68%',
                    Icons.trending_up,
                    AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Video Analytics
            _buildSectionTitle('Video Performance'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildAnalyticsRow('Total Videos', '1,234'),
                  Divider(color: context.borderColor),
                  _buildAnalyticsRow('Total Views', '1,234,567'),
                  Divider(color: context.borderColor),
                  _buildAnalyticsRow('Average Watch Time', '3m 24s'),
                  Divider(color: context.borderColor),
                  _buildAnalyticsRow('Engagement Rate', '12.5%'),
                ],
              ),
            ),
            // User Analytics
            _buildSectionTitle('User Analytics'),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  _buildAnalyticsRow('New Users', '456'),
                  Divider(color: context.borderColor),
                  _buildAnalyticsRow('Active Users', '12,500'),
                  Divider(color: context.borderColor),
                  _buildAnalyticsRow('Retention Rate', '68%'),
                  Divider(color: context.borderColor),
                  _buildAnalyticsRow('Avg Session Duration', '18m 32s'),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


