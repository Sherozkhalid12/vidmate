import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';

/// Language selection screen
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'English';

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
    {'code': 'fr', 'name': 'French', 'native': 'Français'},
    {'code': 'de', 'name': 'German', 'native': 'Deutsch'},
    {'code': 'it', 'name': 'Italian', 'native': 'Italiano'},
    {'code': 'pt', 'name': 'Portuguese', 'native': 'Português'},
    {'code': 'ru', 'name': 'Russian', 'native': 'Русский'},
    {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
    {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
    {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
  ];

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
                'Language',
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
              child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final language = _languages[index];
          final isSelected = _selectedLanguage == language['name'];

          return GlassCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected
                    ? ThemeHelper.getAccentColor(context)
                    : ThemeHelper.getTextMuted(context),
              ),
              title: Text(
                language['name']!,
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                language['native']!,
                style: TextStyle(
                  color: ThemeHelper.getTextSecondary(context),
                  fontSize: 12,
                ),
              ),
              onTap: () {
                setState(() {
                  _selectedLanguage = language['name']!;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Language changed to ${language['name']}',
                      style: TextStyle(color: ThemeHelper.getOnAccentColor(context)),
                    ),
                    backgroundColor: ThemeHelper.getAccentColor(context),
                  ),
                );
              },
            ),
          );
        },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


