import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';

/// Create post screen (photo/video)
class CreatePostScreen extends ConsumerStatefulWidget {
  final Widget? bottomNavigationBar;
  
  const CreatePostScreen({super.key, this.bottomNavigationBar});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  
  File? _mediaFile;
  bool _isVideo = false;

  Future<void> _pickMedia(bool isVideo) async {
    try {
      // Show source selection dialog
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: context.surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: context.buttonColor),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: context.buttonColor),
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
            backgroundColor: context.surfaceColor,
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

  Future<void> _createPost() async {
    if (_mediaFile == null && _captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add media or caption',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: ThemeHelper.getAccentColor(context).withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final notifier = ref.read(createPostProvider.notifier);
    final success = await notifier.createPost(
      images: _isVideo ? [] : (_mediaFile != null ? [_mediaFile!] : []),
      video: _isVideo ? _mediaFile : null,
      caption: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
      locations: [],
      taggedUsers: [],
      feelings: [],
    );

    if (!mounted) return;
    final errorMessage = ref.read(createPostProvider).error;
    ref.read(createPostProvider.notifier).clearError();

    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Post created successfully!',
            style: TextStyle(color: ThemeHelper.getOnAccentColor(context)),
          ),
          backgroundColor: ThemeHelper.getAccentColor(context),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        _captionController.clear();
        setState(() {
          _mediaFile = null;
          _isVideo = false;
        });
      }
    } else {
      final error = errorMessage ?? 'Failed to create post';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: context.surfaceColor,
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

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createPostState = ref.watch(createPostProvider);
    final currentUser = ref.watch(currentUserProvider);
    final displayName = currentUser != null
        ? (currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : (currentUser.username.isNotEmpty
                ? currentUser.username
                : MockDataService.mockUsers[0].displayName))
        : MockDataService.mockUsers[0].displayName;
    final avatarUrl = currentUser != null && currentUser.avatarUrl.isNotEmpty
        ? currentUser.avatarUrl
        : null;
    final isUploading = createPostState.isCreating;
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: widget.bottomNavigationBar,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Create Post',
          style: TextStyle(color: context.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: context.textPrimary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: isUploading ? null : _createPost,
            child: Text(
              'Share',
              style: TextStyle(
                color: isUploading
                    ? context.textMuted
                    : context.buttonColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Author info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipOval(
                    child: avatarUrl == null
                        ? Container(
                            width: 40,
                            height: 40,
                            color: context.surfaceColor,
                            child: Icon(
                              Icons.person,
                              color: context.textSecondary,
                            ),
                          )
                        : Image.network(
                            avatarUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 40,
                                height: 40,
                                color: context.surfaceColor,
                                child: Icon(
                                  Icons.person,
                                  color: context.textSecondary,
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    displayName,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Media preview/selector
            if (_mediaFile == null)
              Container(
                height: 300,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.borderColor,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
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
                ),
              )
            else
              Container(
                height: 400,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black,
                ),
                child: Stack(
                  children: [
                    ClipRRect(
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
                              width: double.infinity,
                            ),
                    ),
                    // Remove button at bottom
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _mediaFile = null;
                            });
                          },
                          icon: Icon(Icons.delete_outline),
                          label: Text('Remove'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.7),
                            foregroundColor: context.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // Caption
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  controller: _captionController,
                  maxLines: 6,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Write a caption...',
                    hintStyle: TextStyle(color: context.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOption(Icons.location_on, 'Location'),
                  _buildOption(Icons.people, 'Tag People'),
                  _buildOption(Icons.mood, 'Feeling'),
                ],
              ),
            ),
            if (isUploading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                backgroundColor: context.surfaceColor,
                valueColor: AlwaysStoppedAnimation<Color>(context.buttonColor),
              ),
            ],
          ],
        ),
      ),
      )
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
          color: context.secondaryBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.buttonColor),
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

  Widget _buildOption(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
