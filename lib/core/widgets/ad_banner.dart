import 'package:flutter/material.dart';
import '../theme/theme_extensions.dart';
import '../utils/theme_helper.dart';

/// Ad banner widget for Magnite/SpotX integration
class AdBanner extends StatelessWidget {
  final String? placementId;
  final double? height;
  final String adType; // 'banner', 'video', 'interstitial'

  const AdBanner({
    super.key,
    this.placementId,
    this.height = 50,
    this.adType = 'banner',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: height,
      decoration: BoxDecoration(
        color: ThemeHelper.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Ad content placeholder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.ads_click,
                  color: ThemeHelper.getAccentColor(context),
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ad',
                  style: TextStyle(
                    color: ThemeHelper.getTextMuted(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Ad label
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ThemeHelper.getAccentColor(context).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'AD',
                style: TextStyle(
                  color: ThemeHelper.getAccentColor(context),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

