import 'dart:io';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_button.dart';

/// Video upload screen (Long video, Reel, Post)
class VideoUploadScreen extends StatefulWidget {
  final String type; // 'long', 'reel', 'post'

  const VideoUploadScreen({
    super.key,
    required this.type,
  });

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  File? _videoFile;
  File? _thumbnailFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isCompressing = false;
  bool _copyrightCheckPassed = false;
  bool _isCheckingCopyright = false;
  String? _copyrightError;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
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
                leading: Icon(
                  Icons.video_library,
                  color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(
                  Icons.videocam,
                  color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                ),
                title: Text(
                  'Record Video',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final pickedFile = await _picker.pickVideo(
        source: source,
        maxDuration: widget.type == 'reel' 
            ? const Duration(seconds: 60)
            : const Duration(minutes: 10),
      );

      if (pickedFile != null) {
        setState(() {
          _videoFile = File(pickedFile.path);
          _copyrightCheckPassed = false;
        });
        await _generateThumbnail();
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
            backgroundColor: ThemeHelper.getAccentColor(context).withOpacity(0.9), // Theme-aware accent color
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

  Future<void> _generateThumbnail() async {
    if (_videoFile == null) return;

    try {
      final thumbnail = await VideoCompress.getFileThumbnail(
        _videoFile!.path,
        quality: 80,
        position: 0,
      );
      setState(() {
        _thumbnailFile = thumbnail;
      });
    } catch (e) {
      // Thumbnail generation failed, continue without it
    }
  }

  Future<void> _checkCopyright() async {
    if (_videoFile == null) return;

    setState(() {
      _isCheckingCopyright = true;
      _copyrightError = null;
    });

    // Simulate copyright check (frontend only - no backend)
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _copyrightCheckPassed = true; // Mock: always passes
      _copyrightError = null;
      _isCheckingCopyright = false;
    });
  }

  Future<void> _compressVideo() async {
    if (_videoFile == null) return;

    setState(() {
      _isCompressing = true;
    });

    try {
      final compressed = await VideoCompress.compressVideo(
        _videoFile!.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (compressed != null && compressed.path != null) {
        setState(() {
          _videoFile = File(compressed.path!);
          _isCompressing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isCompressing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compression failed: $e'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) return;
    if (!_copyrightCheckPassed && widget.type != 'post') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please check copyright before uploading'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Compress video first
      await _compressVideo();

      // Simulate upload progress (frontend only - no backend)
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() {
          _uploadProgress = i / 100;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: $e',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: ThemeHelper.getAccentColor(context).withOpacity(0.9), // Theme-aware accent color
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Upload ${widget.type.toUpperCase()}'),
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
            // Video preview/selector
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  if (_videoFile == null)
                    GestureDetector(
                      onTap: _pickVideo,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.borderColor,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library,
                              size: 64,
                              color: context.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap to select video',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _thumbnailFile ?? _videoFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.videocam,
                                    color: context.textPrimary,
                                    size: 64,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _pickVideo,
                              icon: Icon(Icons.edit),
                              label: Text('Change Video'),
                            ),
                            if (widget.type != 'post') ...[
                              const SizedBox(width: 16),
                              GlassButton(
                                text: _isCheckingCopyright
                                    ? 'Checking...'
                                    : _copyrightCheckPassed
                                        ? 'Copyright OK'
                                        : 'Check Copyright',
                                backgroundColor: _copyrightCheckPassed
                                    ? ThemeHelper.getAccentColor(context).withOpacity(0.2) // Theme-aware accent with opacity
                                    : null,
                                onPressed: _checkCopyright,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_copyrightError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _copyrightError!,
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Caption
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _captionController,
                maxLines: 4,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  hintStyle: TextStyle(color: context.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Upload progress
            if (_isUploading || _isCompressing)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: context.surfaceColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ThemeHelper.getAccentColor(context), // Theme-aware accent color
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCompressing
                        ? 'Compressing video...'
                        : 'Uploading video...',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            // Upload button
            GlassButton(
              text: _isUploading ? 'Uploading...' : 'Upload Video',
              onPressed: _videoFile != null && !_isUploading
                  ? _uploadVideo
                  : null,
              isLoading: _isUploading,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

