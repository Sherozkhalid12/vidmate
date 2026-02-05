import 'package:flutter/material.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/services/mock_data_service.dart';

/// Bottom sheet to pick audio for reel creation.
/// Returns {audioId, audioName} when user selects an audio.
Future<Map<String, String>?> showAudioPickerBottomSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: ThemeHelper.getSurfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Add Music',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: ThemeHelper.getBorderColor(context).withOpacity(0.5),
            ),
            // Audio list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: MockDataService.getMockReelSounds().length,
                itemBuilder: (context, index) {
                  final sound = MockDataService.getMockReelSounds()[index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ThemeHelper.getAccentColor(context).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: ThemeHelper.getAccentColor(context),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      sound['name'] ?? '',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Use this audio',
                      style: TextStyle(
                        color: ThemeHelper.getTextMuted(context),
                        fontSize: 13,
                      ),
                    ),
                    trailing: Icon(
                      Icons.play_circle_outline,
                      color: ThemeHelper.getAccentColor(context),
                    ),
                    onTap: () => Navigator.pop(context, sound),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
