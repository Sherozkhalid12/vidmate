import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';

/// Simple center-crop flow for post images.
/// Ensures all images match the aspect ratio best suited for the post card.
class PostCropScreen extends StatefulWidget {
  final List<File> images;

  const PostCropScreen({
    super.key,
    required this.images,
  });

  @override
  State<PostCropScreen> createState() => _PostCropScreenState();
}

class _PostCropScreenState extends State<PostCropScreen> {
  int _currentIndex = 0;
  bool _isSaving = false;

  Future<void> _applyAndReturn() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    final List<File> result = [];
    try {
      final dir = await getTemporaryDirectory();
      const targetAspect = 4 / 5; // Portrait, tuned for post card widget

      for (int i = 0; i < widget.images.length; i++) {
        final file = widget.images[i];
        try {
          final bytes = await file.readAsBytes();
          final decoded = img.decodeImage(bytes);
          if (decoded == null) {
            result.add(file);
            continue;
          }
          final cropped = _centerCropToAspect(decoded, targetAspect);
          final jpg = img.encodeJpg(cropped, quality: 95);
          final out = File(
            '${dir.path}/post_crop_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          );
          await out.writeAsBytes(jpg);
          result.add(out);
        } catch (_) {
          result.add(file);
        }
      }
    } finally {
      if (!mounted) return;
      Navigator.pop(context, result);
    }
  }

  img.Image _centerCropToAspect(img.Image source, double targetAspect) {
    final w = source.width;
    final h = source.height;
    final currentAspect = w / h;

    int cropW = w;
    int cropH = h;

    if (currentAspect > targetAspect) {
      // Too wide – trim width
      cropW = (h * targetAspect).round();
    } else {
      // Too tall – trim height
      cropH = (w / targetAspect).round();
    }

    final left = ((w - cropW) / 2).round();
    final top = ((h - cropH) / 2).round();

    return img.copyCrop(
      source,
      x: left,
      y: top,
      width: cropW,
      height: cropH,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    final current = widget.images[_currentIndex];

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
                        AspectRatio(
                          aspectRatio: 4 / 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              current,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (total > 1)
                          _buildSlider(total),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _applyAndReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeHelper.getAccentColor(context),
                    foregroundColor: ThemeHelper.getOnAccentColor(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ThemeHelper.getOnAccentColor(context),
                          ),
                        )
                      : const Text(
                          'Apply crop',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
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
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        'Crop post',
        style: TextStyle(
          color: context.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: Text(
              '${_currentIndex + 1}/${widget.images.length}',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Images',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: total,
            itemBuilder: (context, index) {
              final file = widget.images[index];
              final isSelected = index == _currentIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                child: Container(
                  width: 72,
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
                    child: Image.file(
                      file,
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
}

