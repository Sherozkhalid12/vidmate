import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/content_preview_draft.dart';
import '../../features/feed/create_content_screen.dart';
import '../../features/feed/providers/long_video_pick_workflow_provider.dart';
import '../../features/long_videos/providers/long_videos_provider.dart';
import '../../services/posts/reels_service.dart';
import '../../services/posts/stories_service.dart';
import 'posts_provider_riverpod.dart';
import 'auth_provider_riverpod.dart';
import 'reels_provider_riverpod.dart';
import 'stories_provider_riverpod.dart';

enum ContentPublishPhase { idle, publishing, success, failed }

class ContentPublishState {
  final ContentPreviewDraft? draft;
  final ContentPublishPhase phase;
  final String? errorMessage;
  final String? successMessage;

  const ContentPublishState({
    this.draft,
    this.phase = ContentPublishPhase.idle,
    this.errorMessage,
    this.successMessage,
  });

  bool get isPublishing => phase == ContentPublishPhase.publishing;

  ContentPublishState copyWith({
    ContentPreviewDraft? draft,
    ContentPublishPhase? phase,
    String? errorMessage,
    String? successMessage,
    bool clearDraft = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ContentPublishState(
      draft: clearDraft ? null : (draft ?? this.draft),
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ContentPublishNotifier extends StateNotifier<ContentPublishState> {
  ContentPublishNotifier(this._ref) : super(const ContentPublishState());

  final Ref _ref;

  void setDraft(ContentPreviewDraft draft) {
    state = state.copyWith(
      draft: draft,
      phase: ContentPublishPhase.idle,
      clearError: true,
      clearSuccess: true,
    );
  }

  void clearDraft() {
    state = state.copyWith(clearDraft: true, phase: ContentPublishPhase.idle);
  }

  void acknowledgeOutcome() {
    state = state.copyWith(
      phase: ContentPublishPhase.idle,
      clearError: true,
      clearSuccess: true,
    );
  }

  /// Starts upload in the background (call then pop preview immediately).
  Future<void> startPublish() async {
    final draft = state.draft;
    if (draft == null || state.isPublishing) return;

    state = state.copyWith(
      phase: ContentPublishPhase.publishing,
      clearError: true,
      clearSuccess: true,
    );

    final caption = draft.displayCaption.trim().isEmpty
        ? null
        : draft.displayCaption.trim();
    final locations =
        draft.location != null && draft.location!.trim().isNotEmpty
            ? [draft.location!.trim()]
            : <String>[];
    final taggedUsers = List<String>.from(draft.taggedUsers);
    final feelings =
        draft.feeling != null && draft.feeling!.trim().isNotEmpty
            ? [draft.feeling!.trim()]
            : <String>[];

    try {
      switch (draft.type) {
        case ContentType.post:
          await _publishPost(draft, caption, locations, taggedUsers, feelings);
          break;
        case ContentType.story:
          await _publishStory(draft, caption, locations, taggedUsers, feelings);
          break;
        case ContentType.reel:
          await _publishReel(draft, caption, locations, taggedUsers, feelings);
          break;
        case ContentType.longVideo:
          await _publishLongVideo(draft, caption);
          break;
        case ContentType.live:
          state = state.copyWith(
            phase: ContentPublishPhase.failed,
            errorMessage: 'Live cannot be published from preview.',
          );
          return;
      }
    } catch (e, st) {
      debugPrint('[ContentPublish] unexpected: $e\n$st');
      state = state.copyWith(
        phase: ContentPublishPhase.failed,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _publishPost(
    ContentPreviewDraft draft,
    String? caption,
    List<String> locations,
    List<String> taggedUsers,
    List<String> feelings,
  ) async {
    final isImagePost =
        draft.postImages.isNotEmpty && draft.postVideo == null;

    final success = await _ref.read(createPostProvider.notifier).createPost(
          images: draft.postImages,
          video: draft.postVideo,
          thumbnailFile: draft.postVideoCover,
          caption: caption,
          locations: locations,
          taggedUsers: taggedUsers,
          feelings: feelings,
          musicUrl: isImagePost &&
                  draft.includePostMusic &&
                  draft.musicPreviewUrl != null &&
                  draft.musicPreviewUrl!.trim().isNotEmpty
              ? draft.musicPreviewUrl!.trim()
              : null,
          musicName: isImagePost ? draft.musicName?.trim() : null,
          musicTitle: isImagePost ? draft.musicTitle?.trim() : null,
        );

    if (!success) {
      final err =
          _ref.read(createPostProvider).error ?? 'Failed to create post';
      state = state.copyWith(phase: ContentPublishPhase.failed, errorMessage: err);
      return;
    }

    _ref.read(createPostProvider.notifier).clearError();
    state = state.copyWith(
      phase: ContentPublishPhase.success,
      successMessage: 'Post shared successfully!',
    );
  }

  Future<void> _publishStory(
    ContentPreviewDraft draft,
    String? caption,
    List<String> locations,
    List<String> taggedUsers,
    List<String> feelings,
  ) async {
    final storyFiles = draft.storyMedia.map((m) => m.file).toList();
    final music = draft.includeStoryMusic &&
            draft.musicId != null &&
            draft.musicId!.trim().isNotEmpty
        ? draft.musicId!.trim()
        : null;

    final result = await StoriesService().createStory(CreateStoryParams(
      storyFiles: storyFiles,
      caption: caption,
      locations: locations,
      taggedUsers: taggedUsers,
      feelings: feelings,
      music: music,
    ));

    if (!result.success) {
      state = state.copyWith(
        phase: ContentPublishPhase.failed,
        errorMessage: result.errorMessage ?? 'Failed to share story',
      );
      return;
    }

    final author = _ref.read(currentUserProvider);
    if (author != null && result.data != null) {
      _ref.read(storiesProvider.notifier).insertCreatedStory(
            apiStory: result.data!,
            author: author,
            localFiles: storyFiles,
            localThumbnailFiles:
                draft.storyMedia.map((m) => m.thumbnailFile).toList(),
          );
    }
    unawaited(_ref.read(storiesProvider.notifier).refresh());
    state = state.copyWith(
      phase: ContentPublishPhase.success,
      successMessage: 'Added to your story!',
    );
  }

  Future<void> _publishReel(
    ContentPreviewDraft draft,
    String? caption,
    List<String> locations,
    List<String> taggedUsers,
    List<String> feelings,
  ) async {
    if (draft.reelVideo == null) {
      state = state.copyWith(
        phase: ContentPublishPhase.failed,
        errorMessage: 'Please select a video for your reel.',
      );
      return;
    }

    final hasMusic = draft.hasLibraryMusic;
    final result = await ReelsService().createReel(CreateReelParams(
      video: draft.reelVideo,
      thumbnailFile: draft.reelCover,
      caption: caption,
      locations: locations,
      taggedUsers: taggedUsers,
      feelings: feelings,
      music: draft.musicPreviewUrl?.trim().isNotEmpty == true
          ? draft.musicPreviewUrl
          : draft.musicId,
      musicName: draft.musicName,
      musicTitle: draft.musicName,
      musicArtist: draft.musicTitle,
      isOriginalSound: hasMusic ? false : draft.isOriginalSound,
      musicSource: hasMusic ? (draft.musicSource ?? 'library') : null,
      soundtrackDurationMs: draft.reelDuration != null
          ? draft.reelDuration!.inMilliseconds
          : null,
    ));

    if (!result.success) {
      state = state.copyWith(
        phase: ContentPublishPhase.failed,
        errorMessage: result.errorMessage ?? 'Failed to share reel',
      );
      return;
    }

    await _ref.read(reelsProvider.notifier).refresh();
    state = state.copyWith(
      phase: ContentPublishPhase.success,
      successMessage: 'Reel shared successfully!',
    );
  }

  Future<void> _publishLongVideo(
    ContentPreviewDraft draft,
    String? caption,
  ) async {
    final lvState = _ref.read(longVideoPickWorkflowProvider);
    final file = lvState.rawVideoFile ?? draft.longVideoFile;
    if (file == null) {
      state = state.copyWith(
        phase: ContentPublishPhase.failed,
        errorMessage: 'Please select a video.',
      );
      return;
    }

    const maxH = 1080;
    final result = await _ref
        .read(longVideoPickWorkflowProvider.notifier)
        .ensureUploadedOrUploadNow(
          caption: caption,
          coverPhoto: draft.longVideoCover,
          preferredMaxHeightPixels: maxH,
        );

    if (!result.success) {
      state = state.copyWith(
        phase: ContentPublishPhase.failed,
        errorMessage: result.errorMessage ?? 'Failed to post video',
      );
      return;
    }

    await _ref.read(longVideosProvider.notifier).loadVideos(refresh: true);
    state = state.copyWith(
      phase: ContentPublishPhase.success,
      successMessage: 'Video posted successfully!',
    );
  }
}

final contentPublishProvider =
    StateNotifierProvider<ContentPublishNotifier, ContentPublishState>((ref) {
  return ContentPublishNotifier(ref);
});

/// Whether create screen should show a global upload progress bar.
final contentPublishUploadingProvider = Provider<bool>((ref) {
  final publish = ref.watch(contentPublishProvider);
  final postCreating = ref.watch(createPostProvider).isCreating;
  final lvUploading = ref.watch(longVideoPickWorkflowProvider).isUploading;
  return publish.isPublishing || postCreating || lvUploading;
});
