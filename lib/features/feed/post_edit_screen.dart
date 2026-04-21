import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/music_attribution_label.dart';
import 'select_music_screen.dart';

/// Lightweight post edit screen.
/// - Lets user preview each image
/// - Add simple text overlays per image (visual only)
/// - Pick a single music track applied to the whole post
class PostEditScreen extends StatefulWidget {
  final List<File> images;
  final String? initialAudioId;
  final String? initialAudioName;
  final String? initialAudioUrl;
  final String? initialMusicName;
  final String? initialMusicTitle;

  const PostEditScreen({
    super.key,
    required this.images,
    this.initialAudioId,
    this.initialAudioName,
    this.initialAudioUrl,
    this.initialMusicName,
    this.initialMusicTitle,
  });

  @override
  State<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends State<PostEditScreen> {
  int _currentIndex = 0;
  late List<List<String>> _textsPerImage;

  String? _audioId;
  String? _audioName;
  String? _audioUrl;
  String? _musicName;
  String? _musicTitle;

  @override
  void initState() {
    super.initState();
    _textsPerImage = List<List<String>>.generate(
      widget.images.length,
      (_) => <String>[],
    );
    _audioId = widget.initialAudioId;
    _audioName = widget.initialAudioName;
    _audioUrl = widget.initialAudioUrl;
    _musicName = widget.initialMusicName;
    _musicTitle = widget.initialMusicTitle;
  }

  void _finish() {
    Navigator.pop<Map<String, dynamic>>(context, {
      'audioId': _audioId,
      'audioName': _audioName,
      'audioUrl': _audioUrl,
      'musicName': _musicName,
      'musicTitle': _musicTitle,
      // Text overlays are visual-only for now.
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
              hintText: 'Type something...',
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
      _textsPerImage[_currentIndex].add(text);
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
    final preview = (selected['previewUrl'] ?? selected['audioUrl'])?.toString().trim() ?? '';
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
    final currentFile = widget.images[_currentIndex];

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
                                Image.file(
                                  currentFile,
                                  fit: BoxFit.cover,
                                ),
                                // Text overlays for this image
                                ..._textsPerImage[_currentIndex].map(
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
                        _buildImageSlider(),
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
        'Edit post',
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

  Widget _buildImageSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Image ${_currentIndex + 1} of ${widget.images.length}',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_textsPerImage[_currentIndex].isNotEmpty)
              Text(
                '${_textsPerImage[_currentIndex].length} text',
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
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final f = widget.images[index];
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
                    child: Image.file(f, fit: BoxFit.cover),
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
          if (_musicName != null &&
              _musicName!.isNotEmpty &&
              _musicTitle != null &&
              _musicTitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            MusicAttributionLabel(
              musicName: _musicName,
              musicTitle: _musicTitle,
            ),
          ] else if (_audioName != null && _audioName!.isNotEmpty) ...[
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

