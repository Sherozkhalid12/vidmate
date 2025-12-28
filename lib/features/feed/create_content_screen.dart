import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/mock_data_service.dart';

/// Content type enum for different creation modes
enum ContentType {
  post,      // Multiple photos only (carousel, 1-10 images)
  story,     // Multiple photos/videos (1-10 items)
  reel,      // Single short video (15-180 sec)
  longVideo, // Single longer video (30+ sec, 1-60 min)
}

/// Media item model for Story (supports both images and videos)
class MediaItem {
  final File file;
  final bool isVideo;
  final Duration? videoDuration;

  MediaItem({
    required this.file,
    required this.isVideo,
    this.videoDuration,
  });
}

/// Multi-type content creation screen supporting Post, Story, Reel, and Long Video
class CreateContentScreen extends StatefulWidget {
  final Widget? bottomNavigationBar;
  final ContentType initialType;

  const CreateContentScreen({
    super.key,
    this.bottomNavigationBar,
    this.initialType = ContentType.post,
  });

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  final PageController _carouselController = PageController();

  ContentType _selectedType = ContentType.post;
  
  // Post: multiple images
  List<File> _postImages = [];
  
  // Story: multiple media items (images + videos)
  List<MediaItem> _storyMedia = [];
  
  // Reel & Long Video: single video
  File? _videoFile;
  Duration? _videoDuration;
  VideoPlayerController? _videoController;

  bool _isUploading = false;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _carouselController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEDIA PICKING METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Show source selection dialog (Gallery/Camera)
  Future<ImageSource?> _showSourceDialog() async {
    return await showModalBottomSheet<ImageSource>(
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
  }

  /// Pick multiple images for Post (1-10 max)
  Future<void> _pickPostImages() async {
    try {
      final source = await _showSourceDialog();
      if (source == null) return;

      List<XFile> pickedFiles = [];

      if (source == ImageSource.gallery) {
        // Multi-select from gallery
        pickedFiles = await _picker.pickMultiImage();
      } else {
        // Camera: pick single image (can add more later)
        final pickedFile = await _picker.pickImage(source: source);
        if (pickedFile != null) {
          pickedFiles = [pickedFile];
        }
      }

      if (pickedFiles.isNotEmpty) {
        final newImages = pickedFiles.map((file) => File(file.path)).toList();
        final totalCount = _postImages.length + newImages.length;
        
        if (totalCount > 10) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Maximum 10 images allowed. You can add ${10 - _postImages.length} more.',
                  style: TextStyle(color: context.textPrimary),
                ),
                backgroundColor: context.surfaceColor,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          // Add only up to the limit
          final remaining = 10 - _postImages.length;
          if (remaining > 0) {
            setState(() {
              _postImages.addAll(newImages.take(remaining));
            });
          }
        } else {
          setState(() {
            _postImages.addAll(newImages);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking images: ${e.toString()}');
      }
    }
  }

  /// Pick multiple media items for Story (images + videos, 1-10 max)
  Future<void> _pickStoryMedia() async {
    try {
      // Show media type selection
      final String? mediaType = await showModalBottomSheet<String>(
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
                leading: Icon(Icons.image, color: context.buttonColor),
                title: Text(
                  'Add Photos',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: context.buttonColor),
                title: Text(
                  'Add Videos',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, 'video'),
              ),
            ],
          ),
        ),
      );

      if (mediaType == null) return;

      final source = await _showSourceDialog();
      if (source == null) return;

      if (mediaType == 'image') {
        // Pick multiple images
        List<XFile> pickedFiles = [];

        if (source == ImageSource.gallery) {
          // Multi-select from gallery
          pickedFiles = await _picker.pickMultiImage();
        } else {
          // Camera: pick single image (can add more later)
          final pickedFile = await _picker.pickImage(source: source);
          if (pickedFile != null) {
            pickedFiles = [pickedFile];
          }
        }

        if (pickedFiles.isNotEmpty) {
          final newItems = pickedFiles.map((file) => MediaItem(
            file: File(file.path),
            isVideo: false,
          )).toList();

          final totalCount = _storyMedia.length + newItems.length;
          if (totalCount > 10) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Maximum 10 items allowed. You can add ${10 - _storyMedia.length} more.',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  backgroundColor: context.surfaceColor,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
            final remaining = 10 - _storyMedia.length;
            if (remaining > 0) {
              setState(() {
                _storyMedia.addAll(newItems.take(remaining));
              });
            }
          } else {
            setState(() {
              _storyMedia.addAll(newItems);
            });
          }
        }
      } else {
        // Pick single video (can be called multiple times)
        final pickedFile = await _picker.pickVideo(source: source);
        if (pickedFile != null) {
          final videoFile = File(pickedFile.path);
          final duration = await _getVideoDuration(videoFile);
          
          if (_storyMedia.length >= 10) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Maximum 10 items allowed.',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  backgroundColor: context.surfaceColor,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
            return;
          }

          setState(() {
            _storyMedia.add(MediaItem(
              file: videoFile,
              isVideo: true,
              videoDuration: duration,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking media: ${e.toString()}');
      }
    }
  }

  /// Pick single video for Reel or Long Video
  Future<void> _pickVideo() async {
    try {
      final source = await _showSourceDialog();
      if (source == null) return;

      final pickedFile = await _picker.pickVideo(source: source);
      if (pickedFile != null) {
        final videoFile = File(pickedFile.path);
        final duration = await _getVideoDuration(videoFile);

        // Validate duration based on type
        if (_selectedType == ContentType.reel) {
          if (duration.inSeconds < 5) {
            _showErrorSnackBar('Reel must be at least 5 seconds long.');
            return;
          }
          if (duration.inSeconds > 180) {
            _showErrorSnackBar('Reel must be 180 seconds (3 minutes) or less.');
            return;
          }
        } else if (_selectedType == ContentType.longVideo) {
          if (duration.inSeconds < 30) {
            _showErrorSnackBar('Long video must be at least 30 seconds long.');
            return;
          }
          if (duration.inMinutes > 60) {
            _showErrorSnackBar('Long video must be 60 minutes or less.');
            return;
          }
        }

        // Dispose previous controller
        _videoController?.dispose();

        // Create new controller for preview
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();

        setState(() {
          _videoFile = videoFile;
          _videoDuration = duration;
          _videoController = controller;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking video: ${e.toString()}');
      }
    }
  }

  /// Get video duration from file
  Future<Duration> _getVideoDuration(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      return duration;
    } catch (e) {
      return const Duration(seconds: 0);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDATION & PUBLISHING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validate content before publishing
  bool _validateContent() {
    switch (_selectedType) {
      case ContentType.post:
        if (_postImages.isEmpty && _captionController.text.trim().isEmpty) {
          _showErrorSnackBar('Please add at least one image or a caption.');
          return false;
        }
        if (_postImages.isEmpty) {
          _showErrorSnackBar('Post requires at least one image.');
          return false;
        }
        break;
      case ContentType.story:
        if (_storyMedia.isEmpty && _captionController.text.trim().isEmpty) {
          _showErrorSnackBar('Please add at least one media item or a caption.');
          return false;
        }
        if (_storyMedia.isEmpty) {
          _showErrorSnackBar('Story requires at least one media item.');
          return false;
        }
        break;
      case ContentType.reel:
        if (_videoFile == null) {
          _showErrorSnackBar('Please select a video for your reel.');
          return false;
        }
        if (_videoDuration != null) {
          if (_videoDuration!.inSeconds < 5) {
            _showErrorSnackBar('Reel must be at least 5 seconds long.');
            return false;
          }
          if (_videoDuration!.inSeconds > 180) {
            _showErrorSnackBar('Reel must be 180 seconds (3 minutes) or less.');
            return false;
          }
        }
        break;
      case ContentType.longVideo:
        if (_videoFile == null) {
          _showErrorSnackBar('Please select a video.');
          return false;
        }
        if (_videoDuration != null && _videoDuration!.inSeconds < 30) {
          _showErrorSnackBar('Long video must be at least 30 seconds long.');
          return false;
        }
        break;
    }
    return true;
  }

  /// Publish content (simulated)
  Future<void> _publishContent() async {
    if (!_validateContent()) return;

    setState(() {
      _isUploading = true;
    });

    // Simulate upload
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isUploading = false;
      });

      String successMessage;
      switch (_selectedType) {
        case ContentType.post:
          successMessage = 'Post shared successfully!';
          break;
        case ContentType.story:
          successMessage = 'Added to your story!';
          break;
        case ContentType.reel:
          successMessage = 'Reel shared successfully!';
          break;
        case ContentType.longVideo:
          successMessage = 'Video posted successfully!';
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: context.surfaceColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Reset form
      _resetForm();
    }
  }

  /// Reset form to initial state
  void _resetForm() {
    _captionController.clear();
    setState(() {
      _postImages.clear();
      _storyMedia.clear();
      _videoFile = null;
      _videoDuration = null;
      _currentCarouselIndex = 0;
    });
    _videoController?.dispose();
    _videoController = null;
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
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
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // appBar:
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               _buildAppBar(),
              // Type selector (segmented control)
              _buildTypeSelector(),
              const SizedBox(height: 16),

              // Author info
              _buildAuthorInfo(),

              // Media preview/selector (type-specific)
              _buildMediaSection(),

              const SizedBox(height: 20),

              // Caption
              _buildCaptionField(),

              const SizedBox(height: 20),

              // Action buttons (Location, Tag, Feeling)
              if (_shouldShowActionButtons()) _buildActionButtons(),

              if (_isUploading) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  backgroundColor: context.surfaceColor,
                  valueColor: AlwaysStoppedAnimation<Color>(context.buttonColor),
                ),
              ],

              const SizedBox(height: 40), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  /// Build AppBar with dynamic title and action button
  PreferredSizeWidget _buildAppBar() {
    String title;
    String actionText;
    
    switch (_selectedType) {
      case ContentType.post:
        title = 'Create Post';
        actionText = 'Share';
        break;
      case ContentType.story:
        title = 'Create Story';
        actionText = 'Your Story';
        break;
      case ContentType.reel:
        title = 'Create Reel';
        actionText = 'Share Reel';
        break;
      case ContentType.longVideo:
        title = 'Upload Video';
        actionText = 'Post';
        break;
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
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
          onPressed: _isUploading ? null : _publishContent,
          child: Text(
            actionText,
            style: TextStyle(
              color: _isUploading
                  ? context.textMuted
                  : context.buttonColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Build type selector (segmented control)
  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(4),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            _buildTypeChip(ContentType.post, 'Post'),
            _buildTypeChip(ContentType.story, 'Story'),
            _buildTypeChip(ContentType.reel, 'Reel'),
            _buildTypeChip(ContentType.longVideo, 'Video'),
          ],
        ),
      ),
    );
  }

  /// Build individual type chip
  Widget _buildTypeChip(ContentType type, String label) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            // Clear media when switching types
            if (type != ContentType.post) _postImages.clear();
            if (type != ContentType.story) {
              _storyMedia.clear();
            }
            if (type != ContentType.reel && type != ContentType.longVideo) {
              _videoFile = null;
              _videoDuration = null;
              _videoController?.dispose();
              _videoController = null;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? context.buttonColor.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? context.buttonColor
                  : context.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  /// Build author info header
  Widget _buildAuthorInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ClipOval(
            child: Image.network(
              MockDataService.mockUsers[0].avatarUrl,
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
            MockDataService.mockUsers[0].displayName,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build media section (type-specific)
  Widget _buildMediaSection() {
    switch (_selectedType) {
      case ContentType.post:
        return _buildPostMediaSection();
      case ContentType.story:
        return _buildStoryMediaSection();
      case ContentType.reel:
      case ContentType.longVideo:
        return _buildVideoMediaSection();
    }
  }

  /// Build Post media section (multiple images with carousel)
  Widget _buildPostMediaSection() {
    if (_postImages.isEmpty) {
      return Container(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate,
                size: 64,
                color: context.buttonColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Add Photos (1-10)',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickPostImages,
                icon: Icon(Icons.image, color: context.buttonTextColor),
                label: Text(
                  'Select Images',
                  style: TextStyle(color: context.buttonTextColor),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.buttonColor,
                  foregroundColor: context.buttonTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          // Carousel preview
          PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            itemCount: _postImages.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _postImages[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              );
            },
          ),
          
          // Carousel indicators
          if (_postImages.length > 1)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _postImages.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentCarouselIndex == index
                          ? context.buttonColor
                          : context.buttonColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
          
          // Action buttons
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_postImages.length < 10)
                  ElevatedButton.icon(
                    onPressed: _pickPostImages,
                    icon: Icon(Icons.add, color: context.buttonTextColor),
                    label: Text(
                      'Add More (${_postImages.length}/10)',
                      style: TextStyle(color: context.buttonTextColor),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.buttonColor,
                      foregroundColor: context.buttonTextColor,
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _postImages.removeAt(_currentCarouselIndex);
                      if (_currentCarouselIndex >= _postImages.length) {
                        _currentCarouselIndex = _postImages.length - 1;
                      }
                      if (_postImages.isEmpty) {
                        _currentCarouselIndex = 0;
                      }
                    });
                  },
                  icon: Icon(Icons.delete_outline, color: context.textPrimary),
                  label: Text(
                    'Remove',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.7),
                    foregroundColor: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build Story media section (grid/list preview)
  Widget _buildStoryMediaSection() {
    if (_storyMedia.isEmpty) {
      return Container(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_stories,
                size: 64,
                color: context.buttonColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Add Photos or Videos (1-10)',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickStoryMedia,
                icon: Icon(Icons.add, color: context.buttonTextColor),
                label: Text(
                  'Add Media',
                  style: TextStyle(color: context.buttonTextColor),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.buttonColor,
                  foregroundColor: context.buttonTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid preview
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _storyMedia.length,
            itemBuilder: (context, index) {
              final item = _storyMedia[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.isVideo
                        ? Container(
                            color: Colors.black,
                            child: Center(
                              child: Icon(
                                Icons.play_circle_filled,
                                size: 32,
                                color: context.textPrimary,
                              ),
                            ),
                          )
                        : Image.file(
                            item.file,
                            fit: BoxFit.cover,
                          ),
                  ),
                  // Remove button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _storyMedia.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Video duration badge
                  if (item.isVideo && item.videoDuration != null)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(item.videoDuration!),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          
          // Add more button
          if (_storyMedia.length < 10)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _pickStoryMedia,
                  icon: Icon(Icons.add, color: context.buttonTextColor),
                  label: Text(
                    'Add More (${_storyMedia.length}/10)',
                    style: TextStyle(color: context.buttonTextColor),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.buttonColor,
                    foregroundColor: context.buttonTextColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build video media section (single video preview)
  Widget _buildVideoMediaSection() {
    if (_videoFile == null) {
      return Container(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                size: 64,
                color: context.buttonColor,
              ),
              const SizedBox(height: 16),
              Text(
                _selectedType == ContentType.reel
                    ? 'Add Reel Video (5-180 sec)'
                    : 'Add Video (30+ sec)',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: Icon(Icons.video_library, color: context.buttonTextColor),
                label: Text(
                  'Select Video',
                  style: TextStyle(color: context.buttonTextColor),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.buttonColor,
                  foregroundColor: context.buttonTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _videoController != null &&
                      _videoController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 64,
                        color: context.textPrimary,
                      ),
                    ),
            ),
          ),
          
          // Video duration badge
          if (_videoDuration != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDuration(_videoDuration!),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          
          // Remove button
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _videoFile = null;
                    _videoDuration = null;
                  });
                  _videoController?.dispose();
                  _videoController = null;
                },
                icon: Icon(Icons.delete_outline, color: context.textPrimary),
                label: Text(
                  'Remove',
                  style: TextStyle(color: context.textPrimary),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  foregroundColor: context.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build caption field
  Widget _buildCaptionField() {
    final maxLines = _selectedType == ContentType.story ? 3 : 6;
    final hintText = _selectedType == ContentType.story
        ? 'Add a caption to your story...'
        : _selectedType == ContentType.reel
            ? 'Add a caption...'
            : 'Write a caption...';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        child: TextField(
          controller: _captionController,
          maxLines: maxLines,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: context.textMuted),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  /// Build action buttons (Location, Tag, Feeling)
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.location_on, 'Location'),
          _buildActionButton(Icons.people, 'Tag People'),
          _buildActionButton(Icons.mood, 'Feeling'),
        ],
      ),
    );
  }

  /// Build individual action button
  Widget _buildActionButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        // Handle action button tap
      },
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

  /// Check if action buttons should be shown
  bool _shouldShowActionButtons() {
    return _selectedType == ContentType.post ||
        _selectedType == ContentType.reel ||
        _selectedType == ContentType.longVideo;
  }

  /// Format duration to string (MM:SS or HH:MM:SS)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

