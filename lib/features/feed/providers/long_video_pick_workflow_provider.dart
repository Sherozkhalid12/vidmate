import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../services/posts/long_video_service.dart';

class LongVideoPickWorkflowState {
  final File? rawVideoFile;
  final File? posterFile;
  final File? previewClipFile;
  final VideoPlayerController? previewController;
  final bool isProcessingPick;
  final bool isUploading;
  final double uploadProgress;
  final bool isPreviewReady;
  final bool isTranscodingPreview;
  final CreateLongVideoResult? uploadResult;
  final String? internalErrorLog;
  final int? trimStartMs;
  final int? trimEndMs;

  const LongVideoPickWorkflowState({
    this.rawVideoFile,
    this.posterFile,
    this.previewClipFile,
    this.previewController,
    this.isProcessingPick = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.isPreviewReady = false,
    this.isTranscodingPreview = false,
    this.uploadResult,
    this.internalErrorLog,
    this.trimStartMs,
    this.trimEndMs,
  });

  LongVideoPickWorkflowState copyWith({
    File? rawVideoFile,
    File? posterFile,
    File? previewClipFile,
    VideoPlayerController? previewController,
    bool? isProcessingPick,
    bool? isUploading,
    double? uploadProgress,
    bool? isPreviewReady,
    bool? isTranscodingPreview,
    CreateLongVideoResult? uploadResult,
    String? internalErrorLog,
    int? trimStartMs,
    int? trimEndMs,
    bool clearPoster = false,
    bool clearPreviewClip = false,
    bool clearPreviewController = false,
    bool clearUploadResult = false,
    bool clearError = false,
  }) {
    return LongVideoPickWorkflowState(
      rawVideoFile: rawVideoFile ?? this.rawVideoFile,
      posterFile: clearPoster ? null : (posterFile ?? this.posterFile),
      previewClipFile: clearPreviewClip ? null : (previewClipFile ?? this.previewClipFile),
      previewController: clearPreviewController ? null : (previewController ?? this.previewController),
      isProcessingPick: isProcessingPick ?? this.isProcessingPick,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isPreviewReady: isPreviewReady ?? this.isPreviewReady,
      isTranscodingPreview: isTranscodingPreview ?? this.isTranscodingPreview,
      uploadResult: clearUploadResult ? null : (uploadResult ?? this.uploadResult),
      internalErrorLog: clearError ? null : (internalErrorLog ?? this.internalErrorLog),
      trimStartMs: trimStartMs ?? this.trimStartMs,
      trimEndMs: trimEndMs ?? this.trimEndMs,
    );
  }
}

final longVideoPickWorkflowProvider = StateNotifierProvider.autoDispose<
    LongVideoPickWorkflowNotifier, LongVideoPickWorkflowState>(
  (ref) => LongVideoPickWorkflowNotifier(),
);

class LongVideoPickWorkflowNotifier extends StateNotifier<LongVideoPickWorkflowState> {
  LongVideoPickWorkflowNotifier() : super(const LongVideoPickWorkflowState());
  final LongVideoService _service = LongVideoService();
  Future<CreateLongVideoResult>? _inFlightUpload;
  final List<File> _tempFiles = <File>[];

  Future<void> pickAndStart({
    required File rawFile,
  }) async {
    await _clearPreviewArtifacts();
    state = state.copyWith(
      rawVideoFile: rawFile,
      isProcessingPick: true,
      isUploading: false,
      isTranscodingPreview: true,
      uploadProgress: 0,
      isPreviewReady: false,
      clearUploadResult: true,
      clearError: true,
      clearPoster: true,
      clearPreviewClip: true,
      clearPreviewController: true,
    );

    final thumbnailFuture = _extractPoster(rawFile);
    final previewFuture = _transcodeAndInitPreview(rawFile);

    unawaited(Future.wait<void>([
      thumbnailFuture,
      previewFuture,
    ]).whenComplete(() {
      state = state.copyWith(isProcessingPick: false);
    }));
  }

  Future<void> setTrimRangeMs({int? startMs, int? endMs}) async {
    state = state.copyWith(trimStartMs: startMs, trimEndMs: endMs);
  }

  Future<CreateLongVideoResult> ensureUploadedOrUploadNow({
    required String? caption,
    required File? coverPhoto,
    int preferredMaxHeightPixels = 1080,
  }) async {
    if (_inFlightUpload != null) {
      return _inFlightUpload!;
    }
    final raw = state.rawVideoFile;
    if (raw == null) return CreateLongVideoResult.failure('Video is required');
    return _startRawUpload(
      rawVideoFile: raw,
      caption: caption,
      coverPhoto: coverPhoto,
      preferredMaxHeightPixels: preferredMaxHeightPixels,
    );
  }

  Future<void> clear() async {
    await _clearPreviewArtifacts();
    state = const LongVideoPickWorkflowState();
  }

  Future<void> _extractPoster(File rawFile) async {
    try {
      final Uint8List? bytes = await VideoThumbnail.thumbnailData(
        video: rawFile.path,
        imageFormat: ImageFormat.JPEG,
        quality: 72,
        maxWidth: 640,
        timeMs: 500,
      );
      if (bytes == null || bytes.isEmpty) return;
      final String outPath = await Isolate.run<String>(() {
        return '${Directory.systemTemp.path}${Platform.pathSeparator}lv_poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
      final file = File(outPath);
      await file.writeAsBytes(bytes, flush: true);
      _tempFiles.add(file);
      state = state.copyWith(posterFile: file);
    } catch (e, st) {
      debugPrint('[LongVideoPickWorkflow] poster error: $e\n$st');
    }
  }

  Future<CreateLongVideoResult> _startRawUpload({
    required File rawVideoFile,
    required String? caption,
    required File? coverPhoto,
    required int preferredMaxHeightPixels,
  }) async {
    if (_inFlightUpload != null) return _inFlightUpload!;
    state = state.copyWith(isUploading: true, uploadProgress: 0);

    final future = _service.createLongVideo(
      CreateLongVideoParams(
        video: rawVideoFile,
        thumbnailFile: coverPhoto,
        caption: caption,
        preferredMaxHeightPixels: preferredMaxHeightPixels,
        trimStartMs: state.trimStartMs,
        trimEndMs: state.trimEndMs,
        // Backend may treat this as a staged upload.
        deferPublish: true,
      ),
      onSendProgress: (sent, total) {
        if (total <= 0) return;
        final progress = (sent / total).clamp(0.0, 1.0);
        state = state.copyWith(uploadProgress: progress);
      },
    );
    _inFlightUpload = future;
    final result = await future;
    _inFlightUpload = null;
    state = state.copyWith(
      uploadResult: result,
      isUploading: false,
      uploadProgress: result.success ? 1.0 : state.uploadProgress,
    );
    if (!result.success) {
      state = state.copyWith(internalErrorLog: result.errorMessage ?? 'Upload failed');
    }
    return result;
  }

  Future<void> _transcodeAndInitPreview(File rawFile) async {
    try {
      final outputPath = await Isolate.run<String>(() {
        return '${Directory.systemTemp.path}${Platform.pathSeparator}lv_preview30_${DateTime.now().millisecondsSinceEpoch}.mp4';
      });
      final args = <String>[
        '-y',
        '-ss',
        '0',
        '-t',
        '30',
        '-i',
        rawFile.path,
        '-vf',
        'scale=-2:360',
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-tune',
        'fastdecode',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '96k',
        '-movflags',
        '+faststart',
        outputPath,
      ];
      final session = await FFmpegKit.executeWithArguments(args);
      final code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code)) {
        final logs = await session.getAllLogsAsString();
        state = state.copyWith(
          isTranscodingPreview: false,
          internalErrorLog: 'Preview transcode failed: $logs',
        );
        return;
      }
      final clipFile = File(outputPath);
      if (!await clipFile.exists()) {
        state = state.copyWith(
          isTranscodingPreview: false,
          internalErrorLog: 'Preview clip not found',
        );
        return;
      }
      _tempFiles.add(clipFile);
      final controller = VideoPlayerController.file(clipFile);
      await controller.initialize();
      await controller.pause();
      state.previewController?.dispose();
      state = state.copyWith(
        previewClipFile: clipFile,
        previewController: controller,
        isTranscodingPreview: false,
        isPreviewReady: true,
      );
    } catch (e, st) {
      state = state.copyWith(
        isTranscodingPreview: false,
        internalErrorLog: 'Preview init failed: $e',
      );
      debugPrint('[LongVideoPickWorkflow] preview error: $e\n$st');
    }
  }

  Future<void> _clearPreviewArtifacts() async {
    try {
      await state.previewController?.dispose();
    } catch (_) {}
    for (final f in _tempFiles) {
      try {
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    _tempFiles.clear();
  }

  @override
  void dispose() {
    unawaited(_clearPreviewArtifacts());
    super.dispose();
  }
}
