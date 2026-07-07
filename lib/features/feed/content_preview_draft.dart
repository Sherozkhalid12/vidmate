import 'dart:io';

import '../../core/models/user_model.dart';
import 'create_content_screen.dart';

/// Snapshot of create-form data for the pre-publish preview screen.
class ContentPreviewDraft {
  final ContentType type;
  final UserModel author;
  final String displayCaption;
  final String? location;
  final List<String> taggedUsers;
  final String? feeling;

  final List<File> postImages;
  final File? postVideo;
  final File? postVideoCover;

  final List<MediaItem> storyMedia;

  final File? reelVideo;
  final File? reelCover;
  final Duration? reelDuration;

  final File? longVideoFile;
  final File? longVideoCover;

  final String? musicId;
  final String? musicName;
  final String? musicTitle;
  final String? musicPreviewUrl;
  final bool includePostMusic;
  final bool includeStoryMusic;
  final bool isOriginalSound;
  final String? musicSource;

  const ContentPreviewDraft({
    required this.type,
    required this.author,
    this.displayCaption = '',
    this.location,
    this.taggedUsers = const [],
    this.feeling,
    this.postImages = const [],
    this.postVideo,
    this.postVideoCover,
    this.storyMedia = const [],
    this.reelVideo,
    this.reelCover,
    this.reelDuration,
    this.longVideoFile,
    this.longVideoCover,
    this.musicId,
    this.musicName,
    this.musicTitle,
    this.musicPreviewUrl,
    this.includePostMusic = false,
    this.includeStoryMusic = false,
    this.isOriginalSound = false,
    this.musicSource,
  });

  String get typeLabel {
    switch (type) {
      case ContentType.post:
        return postVideo != null ? 'Video post' : 'Post';
      case ContentType.story:
        return 'Story';
      case ContentType.reel:
        return 'Reel';
      case ContentType.longVideo:
        return 'Video';
      case ContentType.live:
        return 'Live';
    }
  }

  bool get hasLibraryMusic =>
      (musicPreviewUrl != null && musicPreviewUrl!.trim().isNotEmpty) ||
      (musicName != null && musicName!.trim().isNotEmpty) ||
      (musicId != null && musicId!.trim().isNotEmpty);

  bool get hasMusicLine => hasLibraryMusic;
}
