import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
// audioplayers: Run `flutter pub get` to install. Restore import for real audio playback.
import '../../core/utils/create_content_visibility.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/posts_provider_riverpod.dart';
import 'select_music_screen.dart';

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
class CreateContentScreen extends ConsumerStatefulWidget {
  final Widget? bottomNavigationBar;
  final ContentType initialType;
  /// When creating a reel, optional pre-selected audio from "Use this audio" flow
  final String? selectedAudioId;
  final String? selectedAudioName;

  const CreateContentScreen({
    super.key,
    this.bottomNavigationBar,
    this.initialType = ContentType.post,
    this.selectedAudioId,
    this.selectedAudioName,
  });

  @override
  ConsumerState<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends ConsumerState<CreateContentScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  final PageController _carouselController = PageController();

  ContentType _selectedType = ContentType.post;
  
  // Post: multiple images + optional single video
  List<File> _postImages = [];
  File? _postVideo;
  Duration? _postVideoDuration;
  VideoPlayerController? _postVideoController;
  
  // Story: multiple media items (images + videos)
  List<MediaItem> _storyMedia = [];
  
  // Reel & Long Video: single video
  File? _videoFile;
  Duration? _videoDuration;
  VideoPlayerController? _videoController;

  bool _isUploading = false;
  int _currentCarouselIndex = 0;
  /// Pre-selected audio when opening from "Use this audio" (reel only)
  String? _selectedAudioId;
  String? _selectedAudioName;
  /// Audio URL for playback (from Select Music; fallback for "Use this audio")
  String? _selectedAudioUrl;
  /// Play/pause state for audio chip - never auto-play when screen is shown
  bool _isAudioPlaying = false;
  /// Selected location, tagged users, feeling (shown on screen when set)
  String? _selectedLocation;
  final List<String> _taggedUsers = [];
  String? _selectedFeeling;

  @override
  void initState() {
    super.initState();
    createContentVisibleNotifier.value = true; // Pause Reels/background media
    _selectedType = widget.initialType;
    _selectedAudioId = widget.selectedAudioId;
    _selectedAudioName = widget.selectedAudioName;
    _selectedAudioUrl = null;
    // Do not auto-play audio or video in this screen
  }

  @override
  void dispose() {
    createContentVisibleNotifier.value = false;
    _captionController.dispose();
    _carouselController.dispose();
    _postVideoController?.dispose();
    _videoController?.dispose();
    _stopAndDisposeAudio();
    super.dispose();
  }

  void _stopAndDisposeAudio() {
    _isAudioPlaying = false;
  }

  /// Dispose video when switching content type; dispose audio when navigating to select music
  void _disposeMediaForTabChange() {
    _postVideoController?.dispose();
    _postVideoController = null;
    _postVideo = null;
    _postVideoDuration = null;
    _videoController?.dispose();
    _videoController = null;
    _videoFile = null;
    _videoDuration = null;
    _stopAndDisposeAudio();
  }

  void _disposeAudioState() {
    if (mounted) {
      setState(() => _isAudioPlaying = false);
    } else {
      _isAudioPlaying = false;
    }
  }

  /// Get URL for playback (from Select Music or demo for "Use this audio")
  String? get _playbackUrl {
    if (_selectedAudioUrl != null && _selectedAudioUrl!.isNotEmpty) return _selectedAudioUrl;
    if (_selectedAudioId != null && MockDataService.getMockMusic().isNotEmpty) {
      return MockDataService.getMockMusic().first.audioUrl;
    }
    return null;
  }

  /// Play/pause audio. Pause icon stops playback; no auto-play when screen is shown.
  /// Note: Real audio requires `audioplayers`. Run `flutter pub get` and restore
  /// the AudioPlayer implementation for actual playback.
  Future<void> _toggleAudioPlayPause() async {
    if (_playbackUrl == null) return;
    if (_isAudioPlaying) {
      if (mounted) {
        setState(() => _isAudioPlaying = false);
      } else {
        _isAudioPlaying = false;
      }
      return;
    }
    if (mounted) {
      setState(() => _isAudioPlaying = true);
    } else {
      _isAudioPlaying = true;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEDIA PICKING METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Show source selection dialog (Gallery/Camera) - floating, opacity 1
  Future<ImageSource?> _showSourceDialog() async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
                  title: Text(
                    'Choose from Gallery',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
                  title: Text(
                    'Take Photo/Video',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pick video for Post (max 1)
  Future<void> _pickPostVideo() async {
    try {
      if (_postVideo != null) {
        _showErrorSnackBar('Post can only have one video. Remove the existing video first.');
        return;
      }
      final source = await _showSourceDialog();
      if (source == null) return;

      final pickedFile = await _picker.pickVideo(source: source);
      if (pickedFile != null) {
        final videoFile = File(pickedFile.path);
        final duration = await _getVideoDuration(videoFile);

        _postVideoController?.dispose();
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();
        controller.pause();

        setState(() {
          _postVideo = videoFile;
          _postVideoDuration = duration;
          _postVideoController = controller;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking video: ${e.toString()}');
      }
    }
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
      // Show media type selection - floating, pure white
      final String? mediaType = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.image, color: Theme.of(context).colorScheme.primary),
                    title: Text(
                      'Add Photos',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    onTap: () => Navigator.pop(context, 'image'),
                  ),
                  ListTile(
                    leading: Icon(Icons.videocam, color: Theme.of(context).colorScheme.primary),
                    title: Text(
                      'Add Videos',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    onTap: () => Navigator.pop(context, 'video'),
                  ),
                ],
              ),
            ),
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

        // Create new controller for preview - never auto-play
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();
        controller.pause(); // Explicit: do not play in create content screen

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
        if (_postImages.isEmpty && _postVideo == null && _captionController.text.trim().isEmpty) {
          _showErrorSnackBar('Please add at least one image, a video, or a caption.');
          return false;
        }
        if (_postImages.isEmpty && _postVideo == null) {
          _showErrorSnackBar('Post requires at least one image or a video.');
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

  /// Publish content. Post tab uses real API; others simulated for now.
  Future<void> _publishContent() async {
    if (!_validateContent()) return;

    if (_selectedType == ContentType.post) {
      final notifier = ref.read(createPostProvider.notifier);
      final success = await notifier.createPost(
        images: _postImages,
        video: _postVideo,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        locations: _selectedLocation != null ? [_selectedLocation!] : [],
        taggedUsers: _taggedUsers.isEmpty ? [] : List.from(_taggedUsers),
        feelings: _selectedFeeling != null ? [_selectedFeeling!] : [],
      );
      if (!mounted) return;
      ref.read(createPostProvider.notifier).clearError();
      if (success) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Post shared successfully!',
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
          _resetForm();
        }
      } else {
        final error =
            ref.read(createPostProvider).error ?? 'Failed to create post';
        _showErrorSnackBar(error);
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    // Simulate upload for Story / Reel / Long Video
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

      _resetForm();
    }
  }

  /// Reset form to initial state
  void _resetForm() {
    _captionController.clear();
    setState(() {
      _postImages.clear();
      _postVideo = null;
      _postVideoDuration = null;
      _storyMedia.clear();
      _videoFile = null;
      _videoDuration = null;
      _currentCarouselIndex = 0;
      _selectedLocation = null;
      _taggedUsers.clear();
      _selectedFeeling = null;
      _isAudioPlaying = false;
    });
    _postVideoController?.dispose();
    _postVideoController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  /// Show action bottom sheet (Location, Tag People, Feeling) - floating, opacity 1, search for Location/Tag, emoji grid for Feeling
  void _showActionBottomSheet(IconData icon, String label) {
    if (label == 'Location') {
      _showLocationBottomSheet();
    } else if (label == 'Tag People') {
      _showTagPeopleBottomSheet();
    } else if (label == 'Feeling') {
      _showFeelingBottomSheet();
    }
  }

  static const List<String> _locationOptions = [
    'New York', 'Los Angeles', 'London', 'Tokyo', 'Paris', 'Sydney', 'Berlin', 'Mumbai', 'Dubai', 'Singapore',
  ];
  static const List<String> _tagOptions = [
    '@techcreator', '@designer_life', '@traveler', '@fitness_guru', '@music_producer', '@foodie', '@artist',
  ];
  static const List<String> _feelingEmojis = [
    '😊', '😂', '❤️', '😍', '🔥', '👍', '😢', '😡', '🤔', '😴',
    '🎉', '🙏', '💪', '✨', '🌟', '💯', '😎', '🥳', '😌', '🤗',
  ];

  void _showLocationBottomSheet() {
    final searchController = TextEditingController();
    String query = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = query.isEmpty
              ? _locationOptions
              : _locationOptions.where((l) => l.toLowerCase().contains(query.toLowerCase())).toList();
          void updateQuery(String v) {
            query = v;
            setModalState(() {});
          }
          return Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text('Add Location', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      onChanged: updateQuery,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search location...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 22),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final loc = filtered[i];
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(loc, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => _selectedLocation = loc);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      searchController.dispose();
    });
  }

  void _showTagPeopleBottomSheet() {
    final searchController = TextEditingController();
    String query = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void updateQuery(String v) {
            query = v;
            setModalState(() {});
          }
          final filtered = query.isEmpty
              ? _tagOptions
              : _tagOptions.where((u) => u.toLowerCase().contains(query.toLowerCase())).toList();
          return Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text('Tag People', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      onChanged: updateQuery,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 22),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final user = filtered[i];
                        final alreadyTagged = _taggedUsers.contains(user);
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(user, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                          trailing: alreadyTagged ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                          onTap: () {
                            setState(() {
                              if (alreadyTagged) {
                                _taggedUsers.remove(user);
                              } else {
                                _taggedUsers.add(user);
                              }
                            });
                            setModalState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      searchController.dispose();
    });
  }

  void _showFeelingBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text('How are you feeling?', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: _feelingEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = _feelingEmojis[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _selectedFeeling = emoji);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
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

  /// Selected location, tagged people, feeling tiles shown on create content screen
  Widget _buildSelectedTiles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_selectedLocation != null)
            _buildChip(
              icon: Icons.location_on,
              label: _selectedLocation!,
              onRemove: () => setState(() => _selectedLocation = null),
            ),
          ..._taggedUsers.map((u) => _buildChip(
            icon: Icons.person,
            label: u,
            onRemove: () => setState(() => _taggedUsers.remove(u)),
          )),
          if (_selectedFeeling != null)
            _buildChip(
              icon: Icons.mood,
              label: _selectedFeeling!,
              onRemove: () => setState(() => _selectedFeeling = null),
            ),
        ],
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label, required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ThemeHelper.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ThemeHelper.getAccentColor(context)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: ThemeHelper.getTextPrimary(context), fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 18, color: ThemeHelper.getTextMuted(context)),
          ),
        ],
      ),
    );
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
    final createPostState = ref.watch(createPostProvider);
    final isPostUploading = _selectedType == ContentType.post && createPostState.isCreating;
    final isUploading = isPostUploading || _isUploading;
    final screenHeight = MediaQuery.of(context).size.height;
    final minMediaHeight = screenHeight * 0.45;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildAppBar(isUploading)),
              SliverToBoxAdapter(child: _buildTypeSelector()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildAuthorInfo()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: minMediaHeight,
                  child: _buildMediaSection(minMediaHeight),
                ),
              ),
              if (_selectedType == ContentType.reel && _selectedAudioName != null) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildSelectedAudioChip()),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
              if (_selectedType == ContentType.reel) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildAddMusicButton()),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildCaptionField()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildActionButtons()),
              if (_selectedLocation != null || _taggedUsers.isNotEmpty || _selectedFeeling != null) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: _buildSelectedTiles()),
              ],
              if (isUploading) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    backgroundColor: context.surfaceColor,
                    valueColor: AlwaysStoppedAnimation<Color>(context.buttonColor),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  /// Build AppBar with dynamic title and action button
  PreferredSizeWidget _buildAppBar(bool isUploading) {
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
          onPressed: isUploading ? null : _publishContent,
          child: Text(
            actionText,
            style: TextStyle(
              color: isUploading
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
            // Clear media when switching types; dispose video/audio correctly
            if (type != ContentType.post) {
              _postImages.clear();
              _postVideoController?.dispose();
              _postVideoController = null;
              _postVideo = null;
              _postVideoDuration = null;
            }
            if (type != ContentType.story) _storyMedia.clear();
            if (type != ContentType.reel && type != ContentType.longVideo) {
              _disposeMediaForTabChange();
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }

  /// Build media section (type-specific)
  Widget _buildMediaSection([double? minHeight]) {
    final h = minHeight ?? 360;
    switch (_selectedType) {
      case ContentType.post:
        return _buildPostMediaSection(fillHeight: h);
      case ContentType.story:
        return _buildStoryMediaSection(fillHeight: h);
      case ContentType.reel:
      case ContentType.longVideo:
        return _buildVideoMediaSection(fillHeight: h);
    }
  }

  /// Build Post media section (multiple images + optional video with carousel)
  Widget _buildPostMediaSection({double? fillHeight}) {
    final h = fillHeight ?? 400;
    final hasMedia = _postImages.isNotEmpty || _postVideo != null;
    
    if (!hasMedia) {
      return Container(
        height: h,
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
                'Add Photos (1-10) or Video (1)',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickPostImages,
                    icon: Icon(Icons.image, color: context.buttonTextColor),
                    label: Text(
                      'Images',
                      style: TextStyle(color: context.buttonTextColor),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.buttonColor,
                      foregroundColor: context.buttonTextColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _pickPostVideo,
                    icon: Icon(Icons.videocam, color: context.buttonTextColor),
                    label: Text(
                      'Video',
                      style: TextStyle(color: context.buttonTextColor),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.buttonColor,
                      foregroundColor: context.buttonTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final totalItems = _postImages.length + (_postVideo != null ? 1 : 0);
    return Container(
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Carousel preview
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _carouselController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentCarouselIndex = index;
                    });
                  },
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    final isVideo = _postVideo != null && index == _postImages.length;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: isVideo
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  _postVideoController != null &&
                                          _postVideoController!.value.isInitialized
                                      ? AspectRatio(
                                          aspectRatio: _postVideoController!.value.aspectRatio,
                                          child: VideoPlayer(_postVideoController!),
                                        )
                                      : Container(
                                          color: Colors.black,
                                          child: Center(
                                            child: Icon(
                                              Icons.play_circle_filled,
                                              size: 64,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                        ),
                                  if (_postVideoDuration != null)
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
                                          _formatDuration(_postVideoDuration!),
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Image.file(
                                _postImages[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                      ),
                    );
                  },
                ),
                if (totalItems > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        totalItems,
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
              ],
            ),
          ),
          // Buttons below preview (column)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                if (_postImages.length < 10)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pickPostImages,
                      icon: Icon(Icons.add, color: context.buttonTextColor, size: 20),
                      label: Text(
                        'Add Images (${_postImages.length}/10)',
                        style: TextStyle(color: context.buttonTextColor, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.buttonColor,
                        foregroundColor: context.buttonTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_postVideo == null && _postImages.length < 10) const SizedBox(height: 8),
                if (_postVideo == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pickPostVideo,
                      icon: Icon(Icons.videocam, color: context.buttonTextColor, size: 20),
                      label: Text(
                        'Add Video',
                        style: TextStyle(color: context.buttonTextColor, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.buttonColor,
                        foregroundColor: context.buttonTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_postImages.isNotEmpty || _postVideo != null) const SizedBox(height: 8),
                if (_postImages.isNotEmpty || _postVideo != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final isVideo = _postVideo != null && _currentCarouselIndex == _postImages.length;
                        setState(() {
                          if (isVideo) {
                            _postVideoController?.dispose();
                            _postVideoController = null;
                            _postVideo = null;
                            _postVideoDuration = null;
                          } else {
                            _postImages.removeAt(_currentCarouselIndex);
                          }
                          if (_currentCarouselIndex >= totalItems - 1) {
                            _currentCarouselIndex = (totalItems - 2).clamp(0, double.infinity).toInt();
                          }
                          if (_postImages.isEmpty && _postVideo == null) {
                            _currentCarouselIndex = 0;
                          }
                        });
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        color: ThemeHelper.getTextPrimary(context),
                        size: 20,
                      ),
                      label: Text(
                        'Remove',
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: ThemeHelper.getBorderColor(context)),
                        backgroundColor: ThemeHelper.getSurfaceColor(context),
                        foregroundColor: ThemeHelper.getTextPrimary(context),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
  Widget _buildStoryMediaSection({double? fillHeight}) {
    final h = fillHeight ?? 300;
    if (_storyMedia.isEmpty) {
      return Container(
        height: h,
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
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid preview
          Expanded(
            child: GridView.builder(
              shrinkWrap: false,
              physics: const ClampingScrollPhysics(),
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
                          color: ThemeHelper.getSurfaceColor(context).withOpacity(0.95),
                          border: Border.all(
                            color: ThemeHelper.getBorderColor(context),
                            width: 1,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: ThemeHelper.getTextPrimary(context),
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
          ),
          // Buttons below grid (column)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                if (_storyMedia.length < 10)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pickStoryMedia,
                      icon: Icon(Icons.add, color: context.buttonTextColor, size: 20),
                      label: Text(
                        'Add More (${_storyMedia.length}/10)',
                        style: TextStyle(color: context.buttonTextColor, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.buttonColor,
                        foregroundColor: context.buttonTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_storyMedia.isNotEmpty) const SizedBox(height: 8),
                if (_storyMedia.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_storyMedia.isNotEmpty) {
                            _storyMedia.removeLast();
                          }
                        });
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        color: ThemeHelper.getTextPrimary(context),
                        size: 20,
                      ),
                      label: Text(
                        'Remove last',
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: ThemeHelper.getBorderColor(context)),
                        backgroundColor: ThemeHelper.getSurfaceColor(context),
                        foregroundColor: ThemeHelper.getTextPrimary(context),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build video media section (single video preview)
  Widget _buildVideoMediaSection({double? fillHeight}) {
    final h = fillHeight ?? 400;
    if (_videoFile == null) {
      return Container(
        height: h,
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
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pickVideo,
                    icon: Icon(Icons.video_library, color: context.buttonTextColor, size: 20),
                    label: Text(
                      'Change Video',
                      style: TextStyle(color: context.buttonTextColor, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.buttonColor,
                      foregroundColor: context.buttonTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _videoFile = null;
                        _videoDuration = null;
                      });
                      _videoController?.dispose();
                      _videoController = null;
                    },
                    icon: Icon(
                      Icons.delete_outline,
                      color: ThemeHelper.getTextPrimary(context),
                      size: 20,
                    ),
                    label: Text(
                      'Remove',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: ThemeHelper.getBorderColor(context)),
                      backgroundColor: ThemeHelper.getSurfaceColor(context),
                      foregroundColor: ThemeHelper.getTextPrimary(context),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build Add Music button for reel
  Widget _buildAddMusicButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          _disposeAudioState();
          final selected = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (context) => const SelectMusicScreen(),
            ),
          );
          if (selected != null && mounted) {
            setState(() {
              _selectedAudioId = selected['id'] as String?;
              _selectedAudioName = selected['name'] as String?;
              _selectedAudioUrl = selected['audioUrl'] as String?;
              _isAudioPlaying = false;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: context.buttonColor,
                size: 26,
              ),
              const SizedBox(width: 14),
              Text(
                _selectedAudioName != null ? 'Change Music' : 'Add Music',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: context.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build chip showing selected audio with play/pause - no auto-play when screen is shown
  Widget _buildSelectedAudioChip() {
    if (_selectedAudioName == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeHelper.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ThemeHelper.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.music_note_rounded,
              color: ThemeHelper.getAccentColor(context),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Using audio',
                    style: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedAudioName!,
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _toggleAudioPlayPause(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeHelper.getAccentColor(context).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isAudioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: ThemeHelper.getAccentColor(context),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
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
      onTap: () => _showActionBottomSheet(icon, label),
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
