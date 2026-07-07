import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/audio/music_preview_player.dart';
import '../../core/utils/create_content_visibility.dart';
import '../../core/utils/video_frame_extractor.dart';
import '../../core/utils/video_upload_transcode.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/natural_aspect_image.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/content_publish_provider_riverpod.dart';
import '../../core/models/user_model.dart';
import 'content_preview_draft.dart';
import 'content_preview_screen.dart';
import 'providers/long_video_pick_workflow_provider.dart';
import 'select_music_screen.dart';
// LiveStreamScreen is kept for legacy/demo; livestream now uses Agora + backend token.
import 'live_agora_screen.dart';
import 'post_crop_screen.dart';
import 'post_edit_screen.dart';
import 'reel_edit_screen.dart';
import 'reel_edit_feature/reel_edit_export_result.dart';
import 'choose_cover_photo_screen.dart';
import '../../core/providers/livestream_controller_riverpod.dart';

/// Content type enum for different creation modes
enum ContentType {
  post,      // Multiple photos only (carousel, 1-10 images)
  story,     // Multiple photos/videos (1-10 items)
  reel,      // Single short video (15-180 sec)
  longVideo, // Long-form video (no client-side duration cap)
  live,      // Live stream (camera preview + Start Live)
}

/// Media item model for Story (supports both images and videos)
class MediaItem {
  final File file;
  final bool isVideo;
  final Duration? videoDuration;
  final File? thumbnailFile;

  MediaItem({
    required this.file,
    required this.isVideo,
    this.videoDuration,
    this.thumbnailFile,
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
    this.initialType = ContentType.reel,
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

  ContentType _selectedType = ContentType.reel;
  
  // Post: multiple images + optional single video
  List<File> _postImages = [];
  File? _postVideo;
  Duration? _postVideoDuration;
  VideoPlayerController? _postVideoController;
  
  // Story: multiple media items (images + videos)
  List<MediaItem> _storyMedia = [];
  int _currentStoryPreviewIndex = 0;
  
  // Reel & Long Video: single video
  File? _videoFile;
  Duration? _videoDuration;
  VideoPlayerController? _videoController;
  File? _coverPhoto;

  /// True while video is being prepared (duration + controller init) after pick
  bool _isLoadingVideo = false;
  int _currentCarouselIndex = 0;
  /// Pre-selected audio when opening from "Use this audio" (reel only)
  String? _selectedAudioId;
  String? _selectedAudioName;
  /// Audio URL for playback (from Select Music; fallback for "Use this audio")
  String? _selectedAudioUrl;
  /// Song title from picker (attribution + API-adjacent state).
  String? _selectedMusicName;
  /// Artist from picker (paired with [_selectedMusicName] for attribution).
  String? _selectedMusicTitle;
  /// Play/pause state for audio chip - never auto-play when screen is shown
  bool _isAudioPlaying = false;
  late final MusicPreviewPlayer _audioPreview;
  /// Selected location, tagged users, feeling (shown on screen when set)
  String? _selectedLocation;
  final List<String> _taggedUsers = [];
  String? _selectedFeeling;

  /// Long video: fixed preferred encode height for create API (`maxResolution`).
  static const int _kLongVideoPreferredMaxHeightPixels = 1080;

  /// Live tab: camera for preview (disposed when switching tab or going full screen)
  CameraController? _liveCameraController;
  bool _liveCameraReady = false;
  String? _liveCameraError;

  @override
  void initState() {
    super.initState();
    // Defer: setting the notifier synchronously notifies ReelsScreen, which calls
    // setState — that must not run during this widget's first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        createContentVisibleNotifier.value = true; // Pause Reels/background media
      }
    });
    _selectedType = widget.initialType;
    _selectedAudioId = widget.selectedAudioId;
    _selectedAudioName = widget.selectedAudioName;
    _selectedAudioUrl = null;
    _audioPreview = MusicPreviewPlayer(
      onIsPlayingChanged: (playing) {
        if (!mounted) return;
        setState(() => _isAudioPlaying = playing);
      },
    );
    // Do not auto-play audio or video in this screen
  }

  @override
  void dispose() {
    createContentVisibleNotifier.value = false;
    unawaited(ref.read(longVideoPickWorkflowProvider.notifier).clear());
    _captionController.dispose();
    _carouselController.dispose();
    _postVideoController?.dispose();
    _videoController?.dispose();
    _disposeLiveCamera();
    _isAudioPlaying = false;
    unawaited(_audioPreview.dispose());
    super.dispose();
  }

  Future<void> _initLiveCamera() async {
    if (_liveCameraController != null) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() {
          _liveCameraError = 'No camera found';
        });
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _liveCameraController = controller;
          _liveCameraReady = true;
          _liveCameraError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _liveCameraError = e.toString();
        _liveCameraReady = false;
      });
    }
  }

  void _disposeLiveCamera() {
    _liveCameraController?.dispose();
    _liveCameraController = null;
    _liveCameraReady = false;
    _liveCameraError = null;
  }

  void _stopAndDisposeAudio() {
    _isAudioPlaying = false;
    unawaited(_audioPreview.stop());
  }

  /// Dispose video when switching content type; dispose audio when navigating to select music
  void _disposeMediaForTabChange() {
    unawaited(ref.read(longVideoPickWorkflowProvider.notifier).clear());
    _postVideoController?.dispose();
    _postVideoController = null;
    _postVideo = null;
    _postVideoDuration = null;
    _videoController?.dispose();
    _videoController = null;
    _videoFile = null;
    _videoDuration = null;
    _coverPhoto = null;
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
    return null;
  }

  /// Play/pause selected music preview (Deezer etc.), capped at 30s.
  Future<void> _toggleAudioPlayPause() async {
    final url = _playbackUrl;
    if (url == null || url.isEmpty) return;
    await _audioPreview.toggle(url);
    if (!mounted) return;
    setState(() => _isAudioPlaying = _audioPreview.isPlaying);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEDIA PICKING METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Show source selection dialog (Gallery/Camera) - floating, theme-aware
  Future<ImageSource?> _showSourceDialog() async {
    final bgColor = ThemeHelper.getBackgroundColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final borderColor = ThemeHelper.getBorderColor(context);
    final accentColor = ThemeHelper.getAccentColor(context);
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: ThemeHelper.getTextPrimary(context).withOpacity(0.15),
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
                  leading: Icon(Icons.photo_library, color: accentColor),
                  title: Text(
                    'Choose from Gallery',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: accentColor),
                  title: Text(
                    'Take Photo/Video',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
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
        final original = File(pickedFile.path);
        final opened = await _openPickedVideoForPreview(
          original,
          maxVideoHeight: 1920,
        );
        final duration = opened.duration;

        _postVideoController?.dispose();
        final controller = opened.controller;
        controller.pause();

        setState(() {
          _postVideo = opened.videoFile;
          _postVideoDuration = duration;
          _postVideoController = controller;
          _selectedAudioId = null;
          _selectedAudioName = null;
          _selectedAudioUrl = null;
          _selectedMusicName = null;
          _selectedMusicTitle = null;
          _isAudioPlaying = false;
        });
        unawaited(_audioPreview.stop());
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

        List<File> toAdd;

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
          final remaining = 10 - _postImages.length;
          toAdd = remaining > 0 ? newImages.take(remaining).toList() : <File>[];
        } else {
          toAdd = newImages;
        }

        if (toAdd.isNotEmpty) {
          setState(() {
            _postImages.addAll(toAdd);
          });

          final cropped = await Navigator.push<List<File>>(
            context,
            MaterialPageRoute(
              builder: (context) => PostCropScreen(
                images: List<File>.from(_postImages),
              ),
            ),
          );
          if (cropped != null && mounted) {
            setState(() {
              _postImages = cropped;
            });
          }
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
      // Show media type selection - floating, theme-aware
      final bgColor = ThemeHelper.getBackgroundColor(context);
      final textPrimary = ThemeHelper.getTextPrimary(context);
      final borderColor = ThemeHelper.getBorderColor(context);
      final accentColor = ThemeHelper.getAccentColor(context);
      final String? mediaType = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: ThemeHelper.getTextPrimary(context).withOpacity(0.15),
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
                    leading: Icon(Icons.image, color: accentColor),
                    title: Text(
                      'Add Photos',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
                    ),
                    onTap: () => Navigator.pop(context, 'image'),
                  ),
                  ListTile(
                    leading: Icon(Icons.videocam, color: accentColor),
                    title: Text(
                      'Add Videos',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
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
          final original = File(pickedFile.path);
          final videoFile = await _resolvePlayableVideo(
            original,
            maxVideoHeight: 1920,
          );
          final duration = await _getVideoDuration(videoFile);
          final thumbnail = await _generateStoryVideoThumbnail(videoFile);

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
              thumbnailFile: thumbnail,
            ));
            _selectedAudioId = null;
            _selectedAudioName = null;
            _selectedAudioUrl = null;
            _selectedMusicName = null;
            _selectedMusicTitle = null;
            _isAudioPlaying = false;
          });
          unawaited(_audioPreview.stop());
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking media: ${e.toString()}');
      }
    }
  }

  Future<void> _pushReelEditForStorySegment(int index) async {
    if (index < 0 || index >= _storyMedia.length) return;
    final item = _storyMedia[index];
    final exported = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelEditScreen(
          mediaFile: item.file,
          isImageMode: !item.isVideo,
        ),
      ),
    );
    final File? exportedFile = exported is ReelEditExportResult
        ? exported.video
        : exported is File
            ? exported
            : null;
    if (exportedFile != null && mounted) {
      File? thumb = item.thumbnailFile;
      if (item.isVideo) {
        thumb = await _generateStoryVideoThumbnail(exportedFile);
      }
      setState(() {
        _storyMedia[index] = MediaItem(
          file: exportedFile,
          isVideo: item.isVideo,
          videoDuration: item.videoDuration,
          thumbnailFile: thumb,
        );
      });
    }
  }

  Future<void> _openStoryMediaEditor() async {
    if (_storyMedia.isEmpty) return;
    if (_storyMedia.length == 1) {
      await _pushReelEditForStorySegment(0);
      return;
    }
    final idx = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Edit which clip?',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...List.generate(_storyMedia.length, (i) {
                final item = _storyMedia[i];
                return ListTile(
                  leading: Icon(
                    item.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                    color: ThemeHelper.getAccentColor(context),
                  ),
                  title: Text(
                    'Segment ${i + 1} · ${item.isVideo ? 'Video' : 'Photo'}',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, i),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (idx != null && mounted) {
      await _pushReelEditForStorySegment(idx);
    }
  }

  bool get _postShowsMusicTile => _postVideo == null;

  bool get _storyShowsMusicTile =>
      _storyMedia.length == 1 && !_storyMedia.first.isVideo;

  bool get _hasMusicPreview =>
      _selectedAudioUrl != null && _selectedAudioUrl!.trim().isNotEmpty;

  void _applyMusicPickerResult(Map<String, dynamic> selected) {
    final preview =
        (selected['previewUrl'] ?? selected['audioUrl'])?.toString().trim() ?? '';
    final mn = selected['musicName']?.toString().trim() ?? '';
    final mt = selected['musicTitle']?.toString().trim() ?? '';
    setState(() {
      _selectedAudioId = selected['id']?.toString();
      _selectedAudioUrl = preview.isEmpty ? null : preview;
      _selectedMusicName = mn.isEmpty ? null : mn;
      _selectedMusicTitle = mt.isEmpty ? null : mt;
      if (mn.isNotEmpty && mt.isNotEmpty) {
        _selectedAudioName = '$mn · $mt';
      } else {
        _selectedAudioName = selected['name']?.toString();
      }
      _isAudioPlaying = false;
    });
  }

  void _clearMusicSelection() {
    if (!mounted) return;
    setState(() {
      _selectedAudioId = null;
      _selectedAudioName = null;
      _selectedAudioUrl = null;
      _selectedMusicName = null;
      _selectedMusicTitle = null;
      _isAudioPlaying = false;
    });
    unawaited(_audioPreview.stop());
  }

  Future<void> _pickStoryMusic() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectMusicScreen(),
      ),
    );
    if (selected != null && mounted) {
      _applyMusicPickerResult(selected);
    }
  }

  Future<void> _pickPostMusic() => _pickStoryMusic();

  /// Pick single video for Reel or Long Video
  Future<void> _pickVideo() async {
    try {
      final source = await _showSourceDialog();
      if (source == null) return;

      final pickedFile = await _picker.pickVideo(source: source);
      if (pickedFile != null) {
        if (_selectedType == ContentType.longVideo) {
          final workflow = ref.read(longVideoPickWorkflowProvider.notifier);
          await workflow.pickAndStart(
            rawFile: File(pickedFile.path),
          );
          return;
        }
        if (mounted) setState(() => _isLoadingVideo = true);

        final original = File(pickedFile.path);
        final maxH = _selectedType == ContentType.longVideo
            ? _kLongVideoPreferredMaxHeightPixels
            : 1920;
        final opened = await _openPickedVideoForPreview(original, maxVideoHeight: maxH);
        final videoFile = opened.videoFile;
        final duration = opened.duration;

        if (!mounted) return;

        if (_selectedType == ContentType.reel) {
          if (duration.inSeconds < 5) {
            opened.controller.dispose();
            setState(() => _isLoadingVideo = false);
            _showErrorSnackBar('Reel must be at least 5 seconds long.');
            return;
          }
          if (duration.inSeconds > 180) {
            opened.controller.dispose();
            setState(() => _isLoadingVideo = false);
            _showErrorSnackBar('Reel must be 180 seconds (3 minutes) or less.');
            return;
          }
        }

        _videoController?.dispose();

        final controller = opened.controller;
        controller.pause();

        if (mounted) {
          setState(() {
            _videoFile = videoFile;
            _videoDuration = duration;
            _videoController = controller;
            _isLoadingVideo = false;
          });
        }
      }
    } catch (e, st) {
      debugPrint(
        '[CreateContent] Error picking video (type=$_selectedType): $e',
      );
      debugPrint('$st');
      if (mounted) {
        setState(() => _isLoadingVideo = false);
        _showErrorSnackBar('Error picking video: ${e.toString()}');
      }
    }
  }

  void _showVideoConvertingSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Converting video for playback and upload…',
          style: TextStyle(
            color: ThemeHelper.getTextPrimary(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: ThemeHelper.getSurfaceColor(context),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<File> _preparePickedVideoFile(
    File original, {
    required int maxVideoHeight,
  }) async {
    final codec = await VideoUploadTranscode.probeVideoCodecName(original);
    if (VideoUploadTranscode.shouldSoftwareTranscode(codec)) {
      _showVideoConvertingSnackBar();
      return VideoUploadTranscode.transcodeToH264AacMp4(
        input: original,
        maxVideoHeight: maxVideoHeight,
      );
    }
    return original;
  }

  /// Ensures the file can be decoded; transcodes from [original] if needed.
  Future<File> _resolvePlayableVideo(
    File original, {
    required int maxVideoHeight,
  }) async {
    File work = await _preparePickedVideoFile(
      original,
      maxVideoHeight: maxVideoHeight,
    );
    if (work.path != original.path) {
      return work;
    }
    try {
      final probe = VideoPlayerController.file(work);
      await probe.initialize();
      await probe.dispose();
      return work;
    } catch (e) {
      debugPrint('[CreateContent] Decoder probe failed, transcoding: $e');
      _showVideoConvertingSnackBar();
      work = await VideoUploadTranscode.transcodeToH264AacMp4(
        input: original,
        maxVideoHeight: maxVideoHeight,
      );
      final probe2 = VideoPlayerController.file(work);
      await probe2.initialize();
      await probe2.dispose();
      return work;
    }
  }

  Future<
      ({
        VideoPlayerController controller,
        File videoFile,
        Duration duration,
      })> _openPickedVideoForPreview(
    File original, {
    required int maxVideoHeight,
  }) async {
    final file = await _resolvePlayableVideo(
      original,
      maxVideoHeight: maxVideoHeight,
    );
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    controller.pause();
    var duration = controller.value.duration;
    if (duration <= Duration.zero) {
      duration = await _getVideoDuration(file);
    }
    return (controller: controller, videoFile: file, duration: duration);
  }

  /// Get video duration from file
  Future<Duration> _getVideoDuration(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      if (duration > Duration.zero) return duration;
    } catch (e) {
      debugPrint('[CreateContent] VideoPlayer duration failed, using ffprobe: $e');
    }
    final ms = await VideoFrameExtractor.getDurationMs(videoFile);
    if (ms > 0) return Duration(milliseconds: ms);
    return Duration.zero;
  }

  /// JPEG frame for story tray preview when the segment is a video.
  Future<File?> _generateStoryVideoThumbnail(File videoFile) async {
    try {
      final durationMs = await VideoFrameExtractor.getDurationMs(videoFile);
      final positionMs = durationMs > 500 ? 500 : 0;
      return await VideoFrameExtractor.extractJpegFrame(
        videoFile: videoFile,
        positionMs: positionMs,
        maxWidth: 720,
      );
    } catch (e) {
      debugPrint('[CreateContent] Story thumbnail failed: $e');
      return null;
    }
  }

  void _applyEditorSoundtrack(ReelSoundtrackInfo? soundtrack) {
    if (soundtrack == null || !soundtrack.hasLibraryMusic) return;
    final title = soundtrack.title?.trim() ?? '';
    final artist = soundtrack.artist?.trim() ?? '';
    setState(() {
      _selectedAudioId = soundtrack.trackId;
      _selectedAudioUrl = soundtrack.musicUrl;
      _selectedMusicName = title.isEmpty ? null : title;
      _selectedMusicTitle = artist.isEmpty ? null : artist;
      if (title.isNotEmpty && artist.isNotEmpty) {
        _selectedAudioName = '$title · $artist';
      } else if (title.isNotEmpty) {
        _selectedAudioName = title;
      } else if (artist.isNotEmpty) {
        _selectedAudioName = artist;
      }
      _isAudioPlaying = false;
    });
  }

  bool get _hasReelLibraryMusic =>
      _hasMusicPreview ||
      (_selectedMusicName != null && _selectedMusicName!.trim().isNotEmpty) ||
      (_selectedAudioId != null && _selectedAudioId!.trim().isNotEmpty);

  Future<void> _handleReelEditResult(dynamic result) async {
    if (result == null || !mounted) return;
    if (result is ReelEditExportResult) {
      _applyEditorSoundtrack(result.soundtrack);
      if (_selectedType == ContentType.reel) {
        await _replaceReelVideoWithExported(result.video);
      } else {
        await _replaceLongVideoWithExported(result.video);
      }
      return;
    }
    if (result is File) {
      if (_selectedType == ContentType.reel) {
        await _replaceReelVideoWithExported(result);
      } else {
        await _replaceLongVideoWithExported(result);
      }
    }
  }

  /// Replaces the current reel video with the exported file from ReelEditScreen.
  /// Keeps caption, music, etc.; only the video file is replaced so Share posts the edited reel.
  Future<void> _replaceReelVideoWithExported(File exportedFile) async {
    if (_selectedType != ContentType.reel) return;
    setState(() => _isLoadingVideo = true);
    _videoController?.dispose();
    _videoController = null;
    try {
      final opened = await _openPickedVideoForPreview(
        exportedFile,
        maxVideoHeight: 1920,
      );
      final duration = opened.duration;
      if (!mounted) return;
      if (duration.inSeconds < 5) {
        opened.controller.dispose();
        setState(() => _isLoadingVideo = false);
        _showErrorSnackBar('Exported reel must be at least 5 seconds long.');
        return;
      }
      if (duration.inSeconds > 180) {
        opened.controller.dispose();
        setState(() => _isLoadingVideo = false);
        _showErrorSnackBar('Exported reel must be 180 seconds or less.');
        return;
      }
      opened.controller.pause();
      if (mounted) {
        setState(() {
          _videoFile = opened.videoFile;
          _videoDuration = duration;
          _videoController = opened.controller;
          _isLoadingVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingVideo = false);
        _showErrorSnackBar('Error loading exported video: ${e.toString()}');
      }
    }
  }

  /// Replaces the current long video with the exported file from ReelEditScreen.
  /// Keeps caption, etc.; only the video file is replaced so Share posts the edited video.
  Future<void> _replaceLongVideoWithExported(File exportedFile) async {
    if (_selectedType != ContentType.longVideo) return;
    setState(() => _isLoadingVideo = true);
    _videoController?.dispose();
    _videoController = null;
    try {
      final opened = await _openPickedVideoForPreview(
        exportedFile,
        maxVideoHeight: _kLongVideoPreferredMaxHeightPixels,
      );
      final duration = opened.duration;
      if (!mounted) return;
      opened.controller.pause();
      if (mounted) {
        setState(() {
          _videoFile = opened.videoFile;
          _videoDuration = duration;
          _videoController = opened.controller;
          _isLoadingVideo = false;
        });
      }
    } catch (e, st) {
      debugPrint('[CreateContent] Error loading long video export: $e');
      debugPrint('$st');
      if (mounted) {
        setState(() => _isLoadingVideo = false);
        _showErrorSnackBar('Error loading exported video: ${e.toString()}');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDATION & PUBLISHING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validate content before publishing
  bool _validateContent() {
    final rawCaption = _captionController.text.trim();
    switch (_selectedType) {
      case ContentType.post:
        if (_postImages.isEmpty && _postVideo == null) {
          _showErrorSnackBar('Post requires at least one image or a video.');
          return false;
        }
        if (rawCaption.isEmpty) {
          _showErrorSnackBar('Caption is required for posts.');
          return false;
        }
        break;
      case ContentType.story:
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
        if (_coverPhoto == null) {
          _showErrorSnackBar('Please choose a cover photo for your reel.');
          return false;
        }
        if (rawCaption.isEmpty) {
          _showErrorSnackBar('Caption is required for reels.');
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
        final lvState = ref.read(longVideoPickWorkflowProvider);
        final hasLongVideo = _videoFile != null || lvState.rawVideoFile != null;
        if (!hasLongVideo) {
          _showErrorSnackBar('Please select a video.');
          return false;
        }
        if (rawCaption.isEmpty) {
          _showErrorSnackBar('Caption is required for long videos.');
          return false;
        }
        break;
      case ContentType.live:
        // Live creation moved to a dedicated screen.
        return false;
    }
    return true;
  }

  void _openPublishPreview() {
    if (!_validateContent()) return;
    if (ref.read(contentPublishUploadingProvider)) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showErrorSnackBar('Please sign in to continue.');
      return;
    }

    ref.read(contentPublishProvider.notifier).setDraft(_buildPreviewDraft(user));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContentPreviewScreen()),
    );
  }

  ContentPreviewDraft _buildPreviewDraft(UserModel user) {
    final lv = ref.read(longVideoPickWorkflowProvider);
    return ContentPreviewDraft(
      type: _selectedType,
      author: user,
      displayCaption: _buildUnifiedCaption() ?? '',
      location: _selectedLocation,
      taggedUsers: List<String>.from(_taggedUsers),
      feeling: _selectedFeeling,
      postImages: List<File>.from(_postImages),
      postVideo: _postVideo,
      postVideoCover: _coverPhoto,
      storyMedia: List<MediaItem>.from(_storyMedia),
      reelVideo: _videoFile,
      reelCover: _coverPhoto,
      reelDuration: _videoDuration,
      longVideoFile: lv.rawVideoFile ?? _videoFile,
      longVideoCover: lv.posterFile ?? _coverPhoto,
      musicId: _selectedAudioId,
      musicName: _selectedMusicName ?? _selectedAudioName,
      musicTitle: _selectedMusicTitle,
      musicPreviewUrl: _selectedAudioUrl,
      includePostMusic: _postShowsMusicTile && _hasMusicPreview,
      includeStoryMusic: _storyShowsMusicTile && _selectedAudioId != null,
      isOriginalSound:
          _selectedType == ContentType.reel && !_hasReelLibraryMusic,
      musicSource: _hasReelLibraryMusic ? 'library' : null,
    );
  }

  void _onPublishOutcome(ContentPublishState next) {
    if (!mounted) return;
    if (next.phase == ContentPublishPhase.failed &&
        next.errorMessage != null &&
        next.errorMessage!.isNotEmpty) {
      _showErrorSnackBar(next.errorMessage!);
      ref.read(contentPublishProvider.notifier).acknowledgeOutcome();
    } else if (next.phase == ContentPublishPhase.success) {
      final message = next.successMessage ?? 'Shared successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
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
      _resetForm();
      ref.read(contentPublishProvider.notifier).clearDraft();
      ref.read(contentPublishProvider.notifier).acknowledgeOutcome();
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    }
  }

  String? _buildUnifiedCaption() {
    final rawCaption = _captionController.text.trim();
    final feeling = _selectedFeeling?.trim() ?? '';
    if (rawCaption.isEmpty && feeling.isEmpty) return null;
    if (feeling.isEmpty) return rawCaption;
    if (rawCaption.isEmpty) return feeling;
    return '$feeling $rawCaption';
  }

  /// Reset form to initial state. Clears all media and reel/long-video state so the same content is not posted again.
  void _resetForm() {
    unawaited(ref.read(longVideoPickWorkflowProvider.notifier).clear());
    _captionController.clear();
    _videoFile = null;
    _videoDuration = null;
    _coverPhoto = null;
    _selectedAudioId = null;
    _selectedAudioName = null;
    _selectedAudioUrl = null;
    _selectedMusicName = null;
    _selectedMusicTitle = null;
    _postVideoController?.dispose();
    _postVideoController = null;
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _postImages.clear();
      _postVideo = null;
      _postVideoDuration = null;
      _storyMedia.clear();
      _isLoadingVideo = false;
      _currentCarouselIndex = 0;
      _selectedLocation = null;
      _taggedUsers.clear();
      _selectedFeeling = null;
      _isAudioPlaying = false;
    });
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
          final bgColor = ThemeHelper.getBackgroundColor(context);
          final textPrimary = ThemeHelper.getTextPrimary(context);
          final textSecondary = ThemeHelper.getTextSecondary(context);
          final surfaceColor = ThemeHelper.getSurfaceColor(context);
          final borderColor = ThemeHelper.getBorderColor(context);
          return Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getTextPrimary(context).withOpacity(0.15),
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
                      color: textSecondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text('Add Location', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      onChanged: updateQuery,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search location...',
                        hintStyle: TextStyle(color: textSecondary),
                        prefixIcon: Icon(Icons.search, color: ThemeHelper.getAccentColor(context), size: 22),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
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
                              color: ThemeHelper.getAccentColor(context).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.location_on, color: ThemeHelper.getAccentColor(context)),
                          ),
                          title: Text(loc, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _selectedLocation = loc);
                            });
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
          final bgColor = ThemeHelper.getBackgroundColor(context);
          final textPrimary = ThemeHelper.getTextPrimary(context);
          final textSecondary = ThemeHelper.getTextSecondary(context);
          final surfaceColor = ThemeHelper.getSurfaceColor(context);
          final borderColor = ThemeHelper.getBorderColor(context);
          final accentColor = ThemeHelper.getAccentColor(context);
          return Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getTextPrimary(context).withOpacity(0.15),
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
                      color: textSecondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text('Tag People', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      onChanged: updateQuery,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        hintStyle: TextStyle(color: textSecondary),
                        prefixIcon: Icon(Icons.search, color: accentColor, size: 22),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
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
                              color: accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.person, color: accentColor),
                          ),
                          title: Text(user, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
                          trailing: alreadyTagged ? Icon(Icons.check_circle, color: accentColor) : null,
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            if (alreadyTagged) {
                              _taggedUsers.remove(user);
                            } else {
                              _taggedUsers.add(user);
                            }
                            setModalState(() {});
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() {});
                            });
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
    final bgColor = ThemeHelper.getBackgroundColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final surfaceColor = ThemeHelper.getSurfaceColor(context);
    final borderColor = ThemeHelper.getBorderColor(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: textPrimary.withOpacity(0.15),
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
                  color: ThemeHelper.getTextSecondary(context).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text('How are you feeling?', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
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
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.pop(context);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selectedFeeling = emoji);
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
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
            color: ThemeHelper.getOnAccentColor(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: ThemeHelper.getAccentColor(context),
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
    ref.listen<ContentPublishState>(contentPublishProvider, (prev, next) {
      if (prev?.phase == next.phase) return;
      _onPublishOutcome(next);
    });

    final longVideoWorkflow = ref.watch(longVideoPickWorkflowProvider);
    final isUploading = ref.watch(contentPublishUploadingProvider);
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
              if (isUploading) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    value: (_selectedType == ContentType.longVideo &&
                            longVideoWorkflow.isUploading)
                        ? longVideoWorkflow.uploadProgress.clamp(0.0, 1.0)
                        : null,
                    backgroundColor: context.surfaceColor,
                    valueColor: AlwaysStoppedAnimation<Color>(context.buttonColor),
                  ),
                ),
              ],
              SliverToBoxAdapter(child: _buildTypeSelector()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildAuthorInfo()),
              SliverToBoxAdapter(
                child: _buildMediaSection(minMediaHeight),
              ),
              if (_selectedAudioName != null &&
                  ((_selectedType == ContentType.reel) ||
                      (_selectedType == ContentType.post && _postShowsMusicTile) ||
                      (_selectedType == ContentType.story && _storyShowsMusicTile))) ...[
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
              if (_selectedLocation != null ||
                  _taggedUsers.isNotEmpty ||
                  _selectedFeeling != null) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: _buildSelectedTiles()),
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
    const title = 'Create Content';
    String actionText;
    
    switch (_selectedType) {
      case ContentType.post:
        actionText = 'Share';
        break;
      case ContentType.story:
        actionText = 'Your Story';
        break;
      case ContentType.reel:
        actionText = 'Share Reel';
        break;
      case ContentType.longVideo:
        actionText = 'Post';
        break;
      case ContentType.live:
        actionText = '';
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
        if (actionText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: isUploading
                ? Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ThemeHelper.getAccentColor(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sharing...',
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : TextButton(
                    onPressed: _openPublishPreview,
                    child: Text(
                      actionText,
                      style: TextStyle(
                        color: context.buttonColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }

  /// Build type selector (segmented control) – equal-width tabs
  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Expanded(
              child: _buildTypeChip(
                ContentType.story,
                'Story',
                Icons.auto_stories_outlined,
              ),
            ),
            Expanded(
              child: _buildTypeChip(
                ContentType.reel,
                'Reel',
                Icons.video_library_outlined,
              ),
            ),
            Expanded(
              child: _buildTypeChip(
                ContentType.longVideo,
                'Video',
                Icons.movie_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual type chip – theme-aware, optional icon and live accent
  Widget _buildTypeChip(ContentType type, String label, IconData icon, {bool isLive = false}) {
    final isSelected = _selectedType == type;
    final accentColor = isLive && isSelected
        ? Colors.red
        : ThemeHelper.getAccentColor(context);
    final bgColor = isSelected
        ? (isLive ? Colors.red.withOpacity(0.2) : accentColor.withOpacity(0.2))
        : Colors.transparent;
    final textColor = isSelected ? (isLive ? Colors.red : accentColor) : context.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
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
            _disposeLiveCamera();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: isSelected && isLive
                ? Border.all(color: Colors.red.withOpacity(0.6), width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
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
      case ContentType.live:
        return _buildPostMediaSection(fillHeight: h);
    }
  }

  /// Build Live tab: camera preview + Start Live button – modern, theme-aware
  Widget _buildLiveMediaSection({double? fillHeight}) {
    final h = fillHeight ?? 360;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Go Live header chip
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ThemeHelper.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ThemeHelper.getAccentColor(context),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getAccentColor(context).withOpacity(0.6),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Go Live',
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Camera preview card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ThemeHelper.getBorderColor(context),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_liveCameraError != null)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off_rounded,
                              size: 56,
                              color: context.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _liveCameraError!,
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (!_liveCameraReady || _liveCameraController == null)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                color: context.buttonColor,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Opening camera...',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _liveCameraController!.value.previewSize?.height ?? 1,
                          height: _liveCameraController!.value.previewSize?.width ?? 1,
                          child: CameraPreview(_liveCameraController!),
                        ),
                      ),
                    // Gradient overlay above button
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ),
                    // Start Live button
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              _disposeLiveCamera();
                              if (!mounted) return;

                              // Start livestream on backend first (fetches Agora token).
                              final uid = ref.read(currentUserProvider)?.id ?? '';
                              final channelName =
                                  'stream_${uid.isNotEmpty ? uid : "guest"}_${DateTime.now().millisecondsSinceEpoch}';
                              final ok = await ref
                                  .read(livestreamControllerProvider.notifier)
                                  .startHost(channelName: channelName);
                              if (!mounted) return;
                              if (!ok) {
                                final err = ref.read(livestreamControllerProvider).errorMessage ??
                                    'Failed to start livestream';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(err),
                                    backgroundColor:
                                        ThemeHelper.getAccentColor(context),
                                  ),
                                );
                                if (mounted) _initLiveCamera();
                                return;
                              }

                              await Navigator.of(context).push(
                                PageRouteBuilder(
                                  opaque: true,
                                  barrierColor: Colors.black,
                                  pageBuilder: (_, __, ___) =>
                                      const LiveAgoraScreen(),
                                  transitionsBuilder: (_, a, __, c) {
                                    return FadeTransition(
                                      opacity: a,
                                      child: ScaleTransition(
                                        scale: Tween<double>(begin: 0.95, end: 1).animate(
                                          CurvedAnimation(
                                            parent: a,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                        child: c,
                                      ),
                                    );
                                  },
                                  transitionDuration: const Duration(milliseconds: 300),
                                ),
                              );
                              if (mounted) _initLiveCamera();
                            },
                            borderRadius: BorderRadius.circular(32),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: context.buttonColor,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.buttonColor.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.live_tv_rounded,
                                    color: context.buttonTextColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Start Live',
                                    style: TextStyle(
                                      color: context.buttonTextColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Post media section (multiple images + optional video with carousel)
  Widget _buildPostMediaSection({double? fillHeight}) {
    final h = fillHeight ?? 400;
    final previewWidth = MediaQuery.of(context).size.width - 32;
    final previewHeight = previewWidth * (5 / 4);
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Carousel preview (same square ratio as feed post card)
          SizedBox(
            height: previewHeight,
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
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    _postImages[index],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Material(
                                      color: Colors.black.withOpacity(0.55),
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () {
                                          final removeIndex = index;
                                          setState(() {
                                            _postImages.removeAt(removeIndex);
                                            if (_postImages.isEmpty && _postVideo == null) {
                                              _currentCarouselIndex = 0;
                                              return;
                                            }
                                            final maxIndex =
                                                _postImages.length + (_postVideo != null ? 1 : 0) - 1;
                                            if (_currentCarouselIndex > maxIndex) {
                                              _currentCarouselIndex = maxIndex;
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: ThemeHelper.getOnAccentColor(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (totalItems > 1) ...[
            const SizedBox(height: 10),
            Row(
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
          ],
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
                if (_postVideo != null) const SizedBox(height: 8),
                if (_postVideo != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final file = _postVideo;
                        if (file == null) return;
                        await showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: ThemeHelper.getSurfaceColor(context),
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) {
                            return Container(
                              color: ThemeHelper.getSurfaceColor(ctx),
                              child: SafeArea(
                                top: false,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                    Container(
                                      width: 44,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: ThemeHelper.getTextMuted(ctx)
                                            .withAlpha(60),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      leading: Icon(Icons.photo_library_outlined,
                                          color:
                                              ThemeHelper.getAccentColor(ctx)),
                                      title: Text(
                                        'Choose from gallery',
                                        style: TextStyle(
                                          color:
                                              ThemeHelper.getTextPrimary(ctx),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final picker = ImagePicker();
                                        final img = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 90,
                                        );
                                        if (img != null && mounted) {
                                          setState(() =>
                                              _coverPhoto = File(img.path));
                                        }
                                      },
                                    ),
                                    ListTile(
                                      leading: Icon(Icons.video_library_outlined,
                                          color:
                                              ThemeHelper.getAccentColor(ctx)),
                                      title: Text(
                                        'Choose from video',
                                        style: TextStyle(
                                          color:
                                              ThemeHelper.getTextPrimary(ctx),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final selected =
                                            await Navigator.push<File>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ChooseCoverPhotoScreen(
                                                    videoFile: file),
                                          ),
                                        );
                                        if (selected != null && mounted) {
                                          setState(() => _coverPhoto = selected);
                                        }
                                      },
                                    ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      icon: Icon(
                        Icons.photo_outlined,
                        color: ThemeHelper.getTextPrimary(context),
                        size: 20,
                      ),
                      label: Text(
                        _coverPhoto != null
                            ? 'Cover photo selected'
                            : 'Choose cover photo',
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: ThemeHelper.getBorderColor(context)),
                        backgroundColor: ThemeHelper.getSurfaceColor(context),
                        foregroundColor: ThemeHelper.getTextPrimary(context),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_postShowsMusicTile) const SizedBox(height: 8),
                if (_postShowsMusicTile)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickPostMusic,
                      icon: Icon(
                        Icons.library_music_outlined,
                        color: ThemeHelper.getTextPrimary(context),
                        size: 20,
                      ),
                      label: Text(
                        _hasMusicPreview ? 'Change music' : 'Add music',
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
                if (_postImages.isNotEmpty) const SizedBox(height: 8),
                if (_postImages.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostEditScreen(
                              images: List<File>.from(_postImages),
                              initialAudioId: _selectedAudioId,
                              initialAudioName: _selectedAudioName,
                              initialAudioUrl: _selectedAudioUrl,
                              initialMusicName: _selectedMusicName,
                              initialMusicTitle: _selectedMusicTitle,
                            ),
                          ),
                        );
                        if (result != null && mounted) {
                          setState(() {
                            _selectedAudioId = result['audioId'] as String?;
                            _selectedAudioName = result['audioName'] as String?;
                            _selectedAudioUrl = result['audioUrl'] as String?;
                            _selectedMusicName = result['musicName'] as String?;
                            _selectedMusicTitle = result['musicTitle'] as String?;
                          });
                        }
                      },
                      icon: Icon(
                        Icons.edit_outlined,
                        color: ThemeHelper.getTextPrimary(context),
                        size: 20,
                      ),
                      label: Text(
                        'Edit post (text & music)',
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

    final previewIndex = _currentStoryPreviewIndex.clamp(0, (_storyMedia.length - 1).clamp(0, double.infinity).toInt());
    final previewItem = _storyMedia[previewIndex];

    return Container(
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: previewItem.isVideo
                  ? StoryPhonePreviewFrame(
                      maxWidth: 220,
                      maxHeight: h * 0.85,
                      innerChild: Icon(
                        Icons.play_circle_filled,
                        size: 44,
                        color: context.textPrimary,
                      ),
                    )
                  : StoryPhonePreviewFrame(
                      imageFile: previewItem.file,
                      maxWidth: 220,
                      maxHeight: h * 0.85,
                      overlays: [
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Story preview',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (_storyMedia.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _storyMedia.length,
                itemBuilder: (context, index) {
                  final item = _storyMedia[index];
                  final selected = index == previewIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _currentStoryPreviewIndex = index),
                    child: Container(
                      width: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? ThemeHelper.getAccentColor(context)
                              : ThemeHelper.getBorderColor(context),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.isVideo
                            ? Container(
                                color: Colors.black,
                                child: Icon(Icons.play_arrow_rounded, color: context.textPrimary, size: 18),
                              )
                            : Image.file(item.file, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
                if (_storyMedia.isNotEmpty) const SizedBox(height: 8),
                if (_storyMedia.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openStoryMediaEditor,
                      icon: Icon(
                        Icons.tune_rounded,
                        color: ThemeHelper.getTextPrimary(context),
                        size: 20,
                      ),
                      label: Text(
                        'Edit media',
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
                if (_storyShowsMusicTile) const SizedBox(height: 8),
                if (_storyShowsMusicTile)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickStoryMusic,
                      icon: Icon(
                        Icons.library_music_outlined,
                        color: ThemeHelper.getTextPrimary(context),
                        size: 20,
                      ),
                      label: Text(
                        _hasMusicPreview ? 'Change music' : 'Add music',
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
    final longVideoWorkflow = ref.watch(longVideoPickWorkflowProvider);
    final effectiveVideoFile = _selectedType == ContentType.longVideo
        ? (longVideoWorkflow.rawVideoFile ?? _videoFile)
        : _videoFile;
    final effectiveVideoController = _selectedType == ContentType.longVideo
        ? (longVideoWorkflow.previewController ?? _videoController)
        : _videoController;

    if (effectiveVideoFile == null) {
      final longVideoSelecting =
          _selectedType == ContentType.longVideo &&
              (longVideoWorkflow.isProcessingPick ||
                  longVideoWorkflow.isTranscodingPreview);
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
            children: longVideoSelecting
                ? [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: ThemeHelper.getAccentColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Converting video…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This can take a minute for long clips.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ]
                : [
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

    final showVideoLoader = _selectedType == ContentType.longVideo
        ? (longVideoWorkflow.isTranscodingPreview ||
            (effectiveVideoController == null ||
                !effectiveVideoController.value.isInitialized))
        : (_isLoadingVideo ||
            (effectiveVideoController == null ||
                !effectiveVideoController.value.isInitialized));

    return Container(
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _selectedType == ContentType.longVideo ? double.infinity : 220,
                    ),
                    child: AspectRatio(
                      aspectRatio: _selectedType == ContentType.reel
                          ? 9 / 16
                          : (_selectedType == ContentType.longVideo ? 16 / 9 : 4 / 5),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.black,
                          border: Border.all(
                            color: ThemeHelper.getBorderColor(context),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: effectiveVideoController != null &&
                                  effectiveVideoController.value.isInitialized
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: effectiveVideoController.value.size.width,
                                    height: effectiveVideoController.value.size.height,
                                    child: VideoPlayer(effectiveVideoController),
                                  ),
                                )
                              : (_selectedType == ContentType.longVideo &&
                                      longVideoWorkflow.posterFile != null)
                                  ? Image.file(
                                      longVideoWorkflow.posterFile!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
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
                    ),
                  ),
                ),
                if (showVideoLoader)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black54,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: ThemeHelper.getAccentColor(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading video...',
                              style: TextStyle(
                                color: ThemeHelper.getTextPrimary(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                        _coverPhoto = null;
                      });
                      _videoController?.dispose();
                      _videoController = null;
                      unawaited(ref.read(longVideoPickWorkflowProvider.notifier).clear());
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final longVideoWorkflow =
                          ref.read(longVideoPickWorkflowProvider);
                      final file = _selectedType == ContentType.longVideo
                          ? (longVideoWorkflow.rawVideoFile ?? _videoFile)
                          : _videoFile;
                      if (file == null) return;
                      await showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: ThemeHelper.getSurfaceColor(context),
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (ctx) {
                          return Container(
                            color: ThemeHelper.getSurfaceColor(ctx),
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Container(
                                    width: 44,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: ThemeHelper.getTextMuted(ctx)
                                          .withAlpha(60),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ListTile(
                                    leading: Icon(Icons.photo_library_outlined,
                                        color: ThemeHelper.getAccentColor(ctx)),
                                    title: Text(
                                      'Choose from gallery',
                                      style: TextStyle(
                                        color: ThemeHelper.getTextPrimary(ctx),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      final picker = ImagePicker();
                                      final img = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 90,
                                      );
                                      if (img != null && mounted) {
                                        setState(() =>
                                            _coverPhoto = File(img.path));
                                      }
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.video_library_outlined,
                                        color: ThemeHelper.getAccentColor(ctx)),
                                    title: Text(
                                      'Choose from video',
                                      style: TextStyle(
                                        color: ThemeHelper.getTextPrimary(ctx),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      final selected =
                                          await Navigator.push<File>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ChooseCoverPhotoScreen(
                                                  videoFile: file),
                                        ),
                                      );
                                      if (selected != null && mounted) {
                                        setState(() => _coverPhoto = selected);
                                      }
                                    },
                                  ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: Icon(
                      Icons.photo_outlined,
                      color: ThemeHelper.getTextPrimary(context),
                      size: 20,
                    ),
                    label: Text(
                      _coverPhoto != null
                          ? 'Cover photo selected'
                          : 'Choose cover photo',
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
                if (_selectedType == ContentType.reel ||
                    _selectedType == ContentType.longVideo)
                  const SizedBox(height: 8),
                if (_selectedType == ContentType.reel ||
                    _selectedType == ContentType.longVideo)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final longVideoWorkflow =
                            ref.read(longVideoPickWorkflowProvider);
                        final file = _selectedType == ContentType.longVideo
                            ? (longVideoWorkflow.rawVideoFile ?? _videoFile)
                            : _videoFile;
                        if (file == null) return;
                        final exported = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReelEditScreen(mediaFile: file),
                          ),
                        );
                        await _handleReelEditResult(exported);
                      },
                      icon: Icon(
                        Icons.edit_outlined,
                        color: ThemeHelper.getTextPrimary(context),
                        size: 20,
                      ),
                      label: Text(
                        _selectedType == ContentType.reel ? 'Edit reel' : 'Edit video',
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
            _applyMusicPickerResult(selected);
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
                ((_selectedAudioName != null &&
                            _selectedAudioName!.trim().isNotEmpty) ||
                        _hasMusicPreview)
                    ? 'Change Music'
                    : 'Add Music',
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
    final hasLine = (_selectedMusicName != null &&
            _selectedMusicName!.trim().isNotEmpty &&
            _selectedMusicTitle != null &&
            _selectedMusicTitle!.trim().isNotEmpty) ||
        (_selectedAudioName != null && _selectedAudioName!.trim().isNotEmpty);
    if (!hasLine) return const SizedBox.shrink();
    final displayLine = (_selectedMusicName != null &&
            _selectedMusicName!.trim().isNotEmpty &&
            _selectedMusicTitle != null &&
            _selectedMusicTitle!.trim().isNotEmpty)
        ? '${_selectedMusicName!.trim()} · ${_selectedMusicTitle!.trim()}'
        : _selectedAudioName!.trim();
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
                    displayLine,
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
