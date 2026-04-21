import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';
import 'create_content_screen.dart';
import 'select_music_screen.dart';

/// Story edit experience for adding text overlays and music
/// to both photos and videos before publishing.
class StoryEditScreen extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final String? initialAudioId;
  final String? initialAudioName;
  final String? initialAudioUrl;

  const StoryEditScreen({
    super.key,
    required this.mediaItems,
    this.initialAudioId,
    this.initialAudioName,
    this.initialAudioUrl,
  });

  @override
  State<StoryEditScreen> createState() => _StoryEditScreenState();
}

class _StoryEditScreenState extends State<StoryEditScreen> {
  int _currentIndex = 0;
  late List<List<String>> _textsPerItem;

  String? _audioId;
  String? _audioName;
  String? _audioUrl;
  String? _musicName;
  String? _musicTitle;

  @override
  void initState() {
    super.initState();
    _textsPerItem = List<List<String>>.generate(
      widget.mediaItems.length,
      (_) => <String>[],
    );
    _audioId = widget.initialAudioId;
    _audioName = widget.initialAudioName;
    _audioUrl = widget.initialAudioUrl;
  }

  void _finish() {
    Navigator.pop<Map<String, dynamic>>(context, {
      'audioId': _audioId,
      'audioName': _audioName,
      'audioUrl': _audioUrl,
      'musicName': _musicName,
      'musicTitle': _musicTitle,
      // Text overlays are visual only in this version
    });
  }

  Future<void> _addTextOverlay() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(
            'Add text',
            style: TextStyle(color: context.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Say something...',
              hintStyle: TextStyle(color: context.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(
                'Add',
                style: TextStyle(color: ThemeHelper.getAccentColor(context)),
              ),
            ),
          ],
        );
      },
    );
    if (text == null || text.isEmpty) return;
    setState(() {
      _textsPerItem[_currentIndex].add(text);
    });
  }

  Future<void> _selectMusic() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectMusicScreen(),
      ),
    );
    if (selected == null) return;
    final preview =
        (selected['previewUrl'] ?? selected['audioUrl'])?.toString().trim() ?? '';
    final mn = selected['musicName']?.toString().trim() ?? '';
    final mt = selected['musicTitle']?.toString().trim() ?? '';
    setState(() {
      _audioId = selected['id']?.toString();
      _audioUrl = preview.isEmpty ? null : preview;
      _musicName = mn.isEmpty ? null : mn;
      _musicTitle = mt.isEmpty ? null : mt;
      if (mn.isNotEmpty && mt.isNotEmpty) {
        _audioName = '$mn · $mt';
      } else {
        _audioName = selected['name']?.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.mediaItems[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: GlassCard(
                    borderRadius: BorderRadius.circular(24),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (item.isVideo)
                                  Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        size: 72,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  )
                                else
                                  Image.file(
                                    item.file,
                                    fit: BoxFit.cover,
                                  ),
                                ..._textsPerItem[_currentIndex].map(
                                  (t) => Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        t,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMediaSlider(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close, color: context.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Edit story',
        style: TextStyle(
          color: context.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _finish,
          child: Text(
            'Done',
            style: TextStyle(
              color: ThemeHelper.getAccentColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Story ${_currentIndex + 1} of ${widget.mediaItems.length}',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_textsPerItem[_currentIndex].isNotEmpty)
              Text(
                '${_textsPerItem[_currentIndex].length} text',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.mediaItems.length,
            itemBuilder: (context, index) {
              final m = widget.mediaItems[index];
              final isSelected = index == _currentIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? ThemeHelper.getAccentColor(context)
                          : ThemeHelper.getBorderColor(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: m.isVideo
                        ? Container(
                            color: Colors.black,
                            child: Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 28,
                                color: context.textPrimary,
                              ),
                            ),
                          )
                        : Image.file(
                            m.file,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addTextOverlay,
                  icon: Icon(
                    Icons.text_fields_outlined,
                    color: context.textPrimary,
                  ),
                  label: Text(
                    'Add text',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectMusic,
                  icon: Icon(
                    Icons.music_note_outlined,
                    color: ThemeHelper.getOnAccentColor(context),
                  ),
                  label: Text(
                    _audioName == null ? 'Add music' : 'Change music',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ThemeHelper.getOnAccentColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeHelper.getAccentColor(context),
                    foregroundColor: ThemeHelper.getOnAccentColor(context),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_audioName != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _audioName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

