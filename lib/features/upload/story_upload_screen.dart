import 'dart:io';
import '../../core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_button.dart';

/// Story upload screen
class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  final _picker = ImagePicker();
  
  File? _mediaFile;
  bool _isVideo = false;
  bool _isPrivate = false;
  bool _isUploading = false;

  Future<void> _pickMedia(bool isVideo) async {
    try {
      // Show source selection dialog
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: context.secondaryBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.neonPurple),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.neonPurple),
                title: Text(
                  'Take Photo/Video',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick media from selected source
      final pickedFile = isVideo
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _mediaFile = File(pickedFile.path);
          _isVideo = isVideo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: AppColors.softBlue.withOpacity(0.9),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'OK',
              textColor: context.textPrimary,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _uploadStory() async {
    if (_mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a photo or video',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: AppColors.softBlue.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    // Simulate upload
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Story uploaded successfully!'),
          backgroundColor: AppColors.cyanGlow,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Upload Story'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media selector
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  if (_mediaFile == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMediaOption(
                          icon: Icons.image,
                          label: 'Photo',
                          onTap: () => _pickMedia(false),
                        ),
                        _buildMediaOption(
                          icon: Icons.videocam,
                          label: 'Video',
                          onTap: () => _pickMedia(true),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Container(
                          height: 400,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _isVideo
                                ? Center(
                                    child: Icon(
                                      Icons.play_circle_filled,
                                      size: 64,
                                      color: context.textPrimary,
                                    ),
                                  )
                                : Image.file(
                                    _mediaFile!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _pickMedia(_isVideo),
                          icon: Icon(Icons.edit),
                          label: Text('Change Media'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Privacy toggle
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Private Story',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  Switch(
                    value: _isPrivate,
                    onChanged: (value) {
                      setState(() {
                        _isPrivate = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Upload button
            GlassButton(
              text: _isUploading ? 'Uploading...' : 'Upload Story',
              onPressed: _mediaFile != null && !_isUploading
                  ? _uploadStory
                  : null,
              isLoading: _isUploading,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.neonPurple),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

