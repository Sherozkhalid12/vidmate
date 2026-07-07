part of '../reel_edit_screen.dart';

class _ReelEditScreenState extends ConsumerState<ReelEditScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late final AnimationController _toolPanelAnim;

  late final _EditorState _editorState;
  late final _BrushState _brushState;
  late final _LayerState _layerState;
  late final ValueNotifier<bool> _isPlaying;
  late final ValueNotifier<bool> _isInitializing;
  late final ValueNotifier<List<Offset?>> _currentStroke;

  bool _isExporting = false;

  final _overlayKey = GlobalKey();
  final _fullImageExportKey = GlobalKey();
  final _videoContainerKey = GlobalKey();

  /// Pixel dimensions of [mediaFile] when [isImageMode].
  double? _imagePixelW;
  double? _imagePixelH;

  Size _videoDisplaySize = Size.zero;

  @override
  void initState() {
    super.initState();

    _editorState = _EditorState();
    _brushState = _BrushState();
    _layerState = _LayerState();
    _isPlaying = ValueNotifier(false);
    _isInitializing = ValueNotifier(true);
    _currentStroke = ValueNotifier([]);

    _toolPanelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Allow video audio + music preview to play simultaneously on Android/iOS.
    unawaited(ReelAudioSessionService.instance.ensureMixablePlayback());

    // Eager-init audio preview sync while this screen is open.
    ref.read(reelAudioPreviewProvider);

    if (widget.isImageMode) {
      _loadImageForEdit();
    } else {
      _initVideo();
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.pause();
    _videoController?.dispose();
    ref.read(reelAudioTimelineProvider.notifier).setClipDragging(false);
    unawaited(ReelAudioSessionService.instance.restoreDefaultPlayback());
    _toolPanelAnim.dispose();
    _editorState.dispose();
    _brushState.dispose();
    _layerState.dispose();
    _isPlaying.dispose();
    _isInitializing.dispose();
    _currentStroke.dispose();
    super.dispose();
  }

  Future<void> _loadImageForEdit() async {
    try {
      final bytes = await widget.mediaFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _imagePixelW = img.width.toDouble();
        _imagePixelH = img.height.toDouble();
      });
      img.dispose();
      _isInitializing.value = false;
    } catch (e) {
      debugPrint('Story image load error: $e');
      if (mounted) _isInitializing.value = false;
    }
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.file(
        widget.mediaFile,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      controller.setLooping(false);
      controller.addListener(_videoListener);

      if (!mounted) {
        controller.dispose();
        return;
      }

      _videoController = controller;
      _isInitializing.value = false;
      final durationSec = controller.value.duration.inMilliseconds / 1000;
      ref.read(reelAudioTimelineProvider.notifier).setVideoDurationSec(durationSec);
      _syncPlaybackState(controller);
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) _isInitializing.value = false;
    }
  }

  void _videoListener() {
    if (widget.isImageMode) return;
    final controller = _videoController;
    if (controller == null) return;

    _syncPlaybackState(controller);

    if (controller.value.isPlaying) {
      final duration = controller.value.duration;
      final position = controller.value.position;
      final trimEndMs =
      (duration.inMilliseconds * _editorState.trimEnd).round();

      if (position.inMilliseconds >= trimEndMs) {
        controller.pause();
        _isPlaying.value = false;
        final trimStartMs =
        (duration.inMilliseconds * _editorState.trimStart).round();
        controller.seekTo(Duration(milliseconds: trimStartMs));
      }
    }
  }

  void _togglePlay() async {
    if (widget.isImageMode) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    await _DS.hapticLight();

    final shouldPlay = !controller.value.isPlaying;
    if (shouldPlay) {
      final duration = controller.value.duration;
      final position = controller.value.position;
      final trimStartMs =
          (duration.inMilliseconds * _editorState.trimStart).round();
      final trimEndMs =
          (duration.inMilliseconds * _editorState.trimEnd).round();

      if (position.inMilliseconds < trimStartMs ||
          position.inMilliseconds >= trimEndMs) {
        await controller.seekTo(Duration(milliseconds: trimStartMs));
      }
      await controller.play();
    } else {
      await controller.pause();
    }

    _isPlaying.value = controller.value.isPlaying;
    _syncPlaybackState(controller);
    _applyVideoAudioMute();
  }

  void _applyVideoAudioMute() {
    final controller = _videoController;
    if (controller == null) return;
    final muted = ref.read(reelAudioTimelineProvider).videoAudioMuted;
    controller.setVolume(muted ? 0.0 : 1.0);
  }

  void _syncPlaybackState(VideoPlayerController controller) {
    _isPlaying.value = controller.value.isPlaying;
    ref.read(reelEditPlaybackProvider.notifier).sync(
          positionMs: controller.value.position.inMilliseconds,
          durationMs: controller.value.duration.inMilliseconds,
          isPlaying: controller.value.isPlaying,
          trimStart: _editorState.trimStart,
          trimEnd: _editorState.trimEnd,
        );
  }

  void _selectTool(_Tool tool) async {
    await _DS.hapticLight();
    if (widget.isImageMode && tool == _Tool.trim) return;
    if (widget.isImageMode && tool == _Tool.audio) return;

    if (_editorState.activeTool == tool) {
      _editorState.activeTool = _Tool.none;
      _toolPanelAnim.reverse();
    } else {
      _editorState.activeTool = tool;
      _toolPanelAnim.forward(from: 0);
    }
    _layerState.selectedIndex = null;
  }

  void _onPanStart(DragStartDetails details) {
    if (_editorState.activeTool != _Tool.paint) return;
    _layerState.saveHistory();
    _currentStroke.value = [details.localPosition];
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_editorState.activeTool != _Tool.paint) return;
    _currentStroke.value = [..._currentStroke.value, details.localPosition];
  }

  void _onPanEnd(DragEndDetails _) {
    if (_editorState.activeTool != _Tool.paint) return;
    if (_currentStroke.value.isEmpty) return;

    _layerState.addLayer(_DrawLayer(
      position: Offset.zero,
      points: List.from(_currentStroke.value),
      color: _brushState.color,
      strokeWidth: _brushState.size,
      brush: _brushState.type,
    ));
    _currentStroke.value = [];
  }

  void _onCanvasTap(TapDownDetails details) async {
    if (_editorState.activeTool == _Tool.text) {
      await _showTextEditor(position: details.localPosition);
      return;
    }
    if (_editorState.activeTool == _Tool.sticker) {
      await _showStickerPicker(position: details.localPosition);
      return;
    }
    if (_layerState.selectedIndex != null) {
      _layerState.selectedIndex = null;
    }
  }

  Future<void> _showTextEditor({Offset? position, int? editIndex}) async {
    _videoController?.pause();
    _isPlaying.value = false;

    final existing = editIndex != null
        ? _layerState.layers[editIndex] as _TextLayer?
        : null;

    final result = await showGeneralDialog<_TextLayer?>(
      context: context,
      barrierDismissible: false,
      barrierColor: ThemeHelper.getBackgroundColor(context).withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, a1, a2, child) {
        return FadeTransition(
          opacity: a1,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) => _TextEditorDialog(
        existing: existing,
        initialPosition: position ?? const Offset(80, 200),
      ),
    );

    if (result != null) {
      if (editIndex != null) {
        _layerState.updateLayer(editIndex, result);
      } else {
        _layerState.addLayer(result);
      }
    }
  }

  Future<void> _showStickerPicker({required Offset position}) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _ReelEditTheme.of(context).surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const _StickerPickerSheet(),
    );

    if (emoji != null) {
      _layerState.addLayer(_StickerLayer(
        position: position - const Offset(24, 24),
        emoji: emoji,
        size: 48,
      ));
    }
  }

  ColorFilter? _computeColorFilter() {
    final filter = _filters[_editorState.filterIndex];

    final b = _editorState.brightness * 80;
    final c = _editorState.contrast;
    final s = _editorState.saturation;
    final w = _editorState.warmth;

    final hasAdjustments = _editorState.brightness != 0 ||
        _editorState.contrast != 1 ||
        _editorState.saturation != 1 ||
        _editorState.warmth != 0;

    if (filter.matrix == null && !hasAdjustments) return null;

    if (filter.matrix != null) return filter.colorFilter;

    final sr = (1 - s) * 0.2126;
    final sg = (1 - s) * 0.7152;
    final sb = (1 - s) * 0.0722;

    return ColorFilter.matrix([
      c * (sr + s), c * sg, c * sb, 0, b + w * 20,
      c * sr, c * (sg + s), c * sb, 0, b,
      c * sr, c * sg, c * (sb + s), 0, b - w * 20,
      0, 0, 0, 1, 0,
    ]);
  }

  double get _effectiveBlur {
    final filterBlur = _filters[_editorState.filterIndex].blur * 3;
    return _editorState.blur + filterBlur;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIXED EXPORT FUNCTIONALITY - PROPERLY MERGES ALL LAYERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleExport() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    await _DS.hapticMedium();

    // Pause video and clear selection
    _videoController?.pause();
    _isPlaying.value = false;
    _layerState.clearSelection();
    _editorState.activeTool = _Tool.none;

    // Wait for UI to update (removes selection borders)
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final File? result = widget.isImageMode
          ? await _exportImageWithOverlays()
          : await _exportVideoWithOverlays();
      if (mounted && result != null) {
        if (widget.isImageMode) {
          Navigator.pop(context, result);
        } else {
          Navigator.pop(
            context,
            ReelEditExportResult(
              video: result,
              soundtrack: _soundtrackFromTimeline(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: _ReelEditTheme.of(context).accentAlt,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  ReelSoundtrackInfo? _soundtrackFromTimeline() {
    final timeline = ref.read(reelAudioTimelineProvider);
    if (timeline.musicMuted || timeline.clips.isEmpty) return null;

    final clip = timeline.selectedClip ?? timeline.clips.first;
    final url = clip.sourceUrl.trim();
    final title = clip.title.trim();
    final artist = clip.subtitle.trim();
    if (url.isEmpty && title.isEmpty) return null;

    final durationMs = ref.read(reelEditPlaybackProvider).trimmedDurationMs;
    return ReelSoundtrackInfo(
      trackId: clip.trackId,
      musicUrl: url.isEmpty ? null : url,
      title: title.isEmpty ? null : title,
      artist: artist.isEmpty ? null : artist,
      musicSource: 'library',
      durationMs: durationMs > 0 ? durationMs.round() : null,
    );
  }

  Future<File?> _exportImageWithOverlays() async {
    final progressController = StreamController<double>.broadcast();
    final statusController = StreamController<String>.broadcast();

    if (!mounted) return null;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor:
          ThemeHelper.getBackgroundColor(context).withValues(alpha: 0.82),
      builder: (_) => _ExportProgressDialog(
        progressStream: progressController.stream,
        statusStream: statusController.stream,
        isImageExport: true,
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      statusController.add('Preparing…');
      progressController.add(0.06);
      await Future.delayed(const Duration(milliseconds: 120));

      statusController.add('Rendering…');
      progressController.add(0.22);

      final boundary = _fullImageExportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.pop(context);
        return widget.mediaFile;
      }

      await Future.delayed(const Duration(milliseconds: 80));
      final pixelRatio =
          MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
      final uiImage = await boundary.toImage(pixelRatio: pixelRatio);
      progressController.add(0.62);
      statusController.add('Saving…');

      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();

      if (byteData == null) {
        if (mounted) Navigator.pop(context);
        return widget.mediaFile;
      }

      final outPath = '${tempDir.path}/story_edit_$timestamp.png';
      await File(outPath).writeAsBytes(byteData.buffer.asUint8List());

      progressController.add(1.0);
      statusController.add('Done');
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) Navigator.pop(context);

      return File(outPath);
    } catch (e, st) {
      debugPrint('Image export error: $e\n$st');
      if (mounted) Navigator.pop(context);
      rethrow;
    } finally {
      await progressController.close();
      await statusController.close();
    }
  }

  Future<File?> _exportVideoWithOverlays() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return widget.mediaFile;
    }

    // Create stream controllers for progress
    final progressController = StreamController<double>.broadcast();
    final statusController = StreamController<String>.broadcast();

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor:
          ThemeHelper.getBackgroundColor(context).withValues(alpha: 0.82),
      builder: (_) => _ExportProgressDialog(
        progressStream: progressController.stream,
        statusStream: statusController.stream,
        isImageExport: false,
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      statusController.add('Capturing overlay layers...');
      progressController.add(0.05);

      // Step 1: Capture overlay if there are layers
      String? overlayPath;

      // Capture overlay when there are layers (text/stickers/drawings) or an in-progress stroke
      final hasOverlayContent =
          _layerState.hasLayers || _currentStroke.value.isNotEmpty;
      if (hasOverlayContent) {
        // Force a rebuild to ensure layers are rendered without selection
        await Future.delayed(const Duration(milliseconds: 100));

        final overlayData = await _captureOverlayImage();
        if (overlayData != null) {
          overlayPath = '${tempDir.path}/overlay_$timestamp.png';
          final overlayFile = File(overlayPath);
          await overlayFile.writeAsBytes(overlayData);
          debugPrint('✓ Overlay saved: $overlayPath (${overlayData.length} bytes)');
        }
      }

      progressController.add(0.12);
      statusController.add('Preparing audio tracks...');

      // Calculate trim parameters first (needed for audio mix duration).
      final duration = controller.value.duration;
      final totalMs = duration.inMilliseconds;
      final startMs = (totalMs * _editorState.trimStart).round();
      final endMs = (totalMs * _editorState.trimEnd).round();
      final clipDurationMs = endMs - startMs;
      final startTimeSec = startMs / 1000.0;
      final clipDurationSec = clipDurationMs / 1000.0;

      final timelineState = ref.read(reelAudioTimelineProvider);
      final audioClips = timelineState.musicMuted ? <ReelAudioClip>[] : timelineState.clips;
      final resolvedClips = <ReelAudioClip>[];
      final audioPaths = <String>[];
      for (final clip in audioClips) {
        final path = clip.localFilePath ??
            await ReelAudioCacheService.instance.ensureLocalFile(
              url: clip.sourceUrl,
              clipId: clip.id,
            );
        if (path != null && path.isNotEmpty) {
          resolvedClips.add(clip);
          audioPaths.add(path);
        }
      }

      final audioPlan = ReelAudioFfmpegMixer.build(
        clips: resolvedClips,
        localPaths: audioPaths,
        exportDurationSec: clipDurationSec,
        firstAudioInputIndex: overlayPath != null ? 2 : 1,
        includeBaseVideoAudio: !timelineState.videoAudioMuted,
      );

      progressController.add(0.15);
      statusController.add('Processing video...');

      // Get video dimensions
      final videoWidth = controller.value.size.width.toInt();
      final videoHeight = controller.value.size.height.toInt();

      // Step 4: Build output path
      final outputPath = '${tempDir.path}/edited_video_$timestamp.mp4';

      // Step 5: Build FFmpeg arguments (list form for reliable parsing, no shell quoting)
      final ffmpegArgs = _buildFFmpegExportArguments(
        inputPath: widget.mediaFile.path,
        overlayPath: overlayPath,
        outputPath: outputPath,
        startTime: startTimeSec,
        duration: clipDurationSec,
        videoWidth: videoWidth,
        videoHeight: videoHeight,
        audioPlan: audioPlan.hasAudioMix ? audioPlan : null,
      );

      debugPrint('FFmpeg args: ${ffmpegArgs.join(" ")}');

      progressController.add(0.2);
      statusController.add('Encoding video with effects...');

      // Step 6: Setup progress monitoring
      FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0 && clipDurationMs > 0) {
          final progress = 0.2 + (timeMs / clipDurationMs) * 0.7;
          progressController.add(progress.clamp(0.2, 0.9));
        }
      });

      // Step 7: Execute FFmpeg with argument list (avoids quote/parse issues)
      final session = await FFmpegKit.executeWithArguments(ffmpegArgs);
      final returnCode = await session.getReturnCode();

      progressController.add(0.95);
      statusController.add('Finalizing...');

      // Step 8: Check result
      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          debugPrint('✓ Export successful: $outputPath (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

          // Cleanup temp overlay
          if (overlayPath != null) {
            try {
              await File(overlayPath).delete();
            } catch (_) {}
          }

          progressController.add(1.0);
          statusController.add('Complete!');
          await Future.delayed(const Duration(milliseconds: 300));

          // Close dialog
          if (mounted) Navigator.pop(context);

          return outputFile;
        }
      }

      // Log FFmpeg output on failure
      final logs = await session.getAllLogsAsString();
      final failureStack = await session.getFailStackTrace();
      debugPrint('FFmpeg failed!\nLogs: $logs\nStack: $failureStack');

      // Close dialog
      if (mounted) Navigator.pop(context);

      // Return original file as fallback
      return widget.mediaFile;

    } catch (e, stackTrace) {
      debugPrint('Export exception: $e\n$stackTrace');
      if (mounted) Navigator.pop(context);
      rethrow;
    } finally {
      await progressController.close();
      await statusController.close();
    }
  }

  /// Captures the overlay layers as a PNG image with transparency
  Future<Uint8List?> _captureOverlayImage() async {
    try {
      final boundary = _overlayKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('⚠ Overlay boundary is null');
        return null;
      }

      // Wait for any pending paints
      await Future.delayed(const Duration(milliseconds: 50));

      // Capture at device pixel ratio for quality
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('⚠ Failed to convert overlay to bytes');
        return null;
      }

      debugPrint('✓ Overlay captured: ${image.width}x${image.height} @ ${pixelRatio}x');
      return byteData.buffer.asUint8List();

    } catch (e) {
      debugPrint('⚠ Overlay capture error: $e');
      return null;
    }
  }

  /// Builds the FFmpeg arguments for export (list form for executeWithArguments).
  /// Overlay image is read with -loop 1 so it lasts the full video duration.
  List<String> _buildFFmpegExportArguments({
    required String inputPath,
    String? overlayPath,
    required String outputPath,
    required double startTime,
    required double duration,
    required int videoWidth,
    required int videoHeight,
    AudioMixPlan? audioPlan,
  }) {
    // Build video filter chain
    final List<String> videoFilters = [];

    // 1. Color filter from presets
    final filterDef = _filters[_editorState.filterIndex];
    if (filterDef.ffmpegFilter != null && filterDef.ffmpegFilter!.isNotEmpty) {
      videoFilters.add(filterDef.ffmpegFilter!);
    }

    // 2. Manual adjustments (brightness, contrast, saturation)
    if (_editorState.brightness != 0 ||
        _editorState.contrast != 1 ||
        _editorState.saturation != 1) {
      final brightness = (_editorState.brightness * 0.3).toStringAsFixed(3);
      final contrast = _editorState.contrast.toStringAsFixed(3);
      final saturation = _editorState.saturation.toStringAsFixed(3);
      videoFilters.add('eq=brightness=$brightness:contrast=$contrast:saturation=$saturation');
    }

    // 3. Color temperature (warmth)
    if (_editorState.warmth != 0) {
      final w = _editorState.warmth;
      if (w > 0) {
        videoFilters.add(
            'colorbalance=rs=${(w * 0.3).toStringAsFixed(2)}:gs=${(w * 0.1).toStringAsFixed(2)}:bs=${(-w * 0.2).toStringAsFixed(2)}'
        );
      } else {
        videoFilters.add(
            'colorbalance=rs=${(w * 0.2).toStringAsFixed(2)}:gs=${(w * 0.1).toStringAsFixed(2)}:bs=${(-w * 0.3).toStringAsFixed(2)}'
        );
      }
    }

    // 4. Blur
    if (_editorState.blur > 0) {
      final sigma = (_editorState.blur * 2).toStringAsFixed(2);
      videoFilters.add('gblur=sigma=$sigma');
    }

    // 5. Vignette
    if (_editorState.vignette > 0) {
      final angle = (_editorState.vignette * 0.5).toStringAsFixed(2);
      videoFilters.add('vignette=angle=$angle');
    }

    final videoFilterChain = videoFilters.isNotEmpty
        ? videoFilters.join(',')
        : 'null';

    final encodeTail = <String>[
      '-t', duration.toStringAsFixed(3),
      '-c:v', 'libx264',
      '-profile:v', 'baseline',
      '-level', '3.1',
      '-preset', 'fast',
      '-crf', '23',
      '-pix_fmt', 'yuv420p',
      '-vsync', 'cfr',
      '-r', '30',
      '-x264opts', 'keyint=30:min-keyint=30:no-scenecut',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-ac', '2',
      '-ar', '44100',
      '-movflags', '+faststart',
      outputPath,
    ];

    final args = <String>[
      '-y',
      '-ss', startTime.toStringAsFixed(3),
      '-i', inputPath,
    ];

    if (overlayPath != null) {
      args.addAll(['-loop', '1', '-i', overlayPath]);
    }

    if (audioPlan != null) {
      for (final audioInput in audioPlan.extraInputs) {
        args.addAll(['-i', audioInput]);
      }
    }

    if (overlayPath != null) {
      final complexFilter = StringBuffer();
      complexFilter.write('[0:v]setpts=PTS-STARTPTS');
      if (videoFilterChain != 'null') {
        complexFilter.write(',$videoFilterChain');
      }
      complexFilter.write('[base];');
      complexFilter.write('[1:v]scale=$videoWidth:$videoHeight,format=rgba[ovrl];');
      complexFilter.write('[base][ovrl]overlay=0:0:format=auto:shortest=1[v]');
      if (audioPlan?.filterGraph != null) {
        complexFilter.write(';');
        complexFilter.write(audioPlan!.filterGraph);
      }
      args.addAll(['-filter_complex', complexFilter.toString(), '-map', '[v]']);
      if (audioPlan?.outputLabel != null) {
        args.addAll(['-map', audioPlan!.outputLabel!]);
      } else {
        args.addAll(['-map', '0:a?']);
      }
      args.addAll(encodeTail);
      return args;
    }

    if (audioPlan != null && audioPlan.filterGraph != null) {
      final complexFilter = StringBuffer();
      if (videoFilterChain != 'null') {
        complexFilter.write('[0:v]$videoFilterChain[v];');
      } else {
        complexFilter.write('[0:v]copy[v];');
      }
      complexFilter.write(audioPlan.filterGraph);
      args.addAll(['-filter_complex', complexFilter.toString(), '-map', '[v]']);
      if (audioPlan.outputLabel != null) {
        args.addAll(['-map', audioPlan.outputLabel!]);
      }
      args.addAll(encodeTail);
      return args;
    }

    if (videoFilters.isNotEmpty) {
      args.addAll(['-vf', videoFilterChain]);
    }
    args.addAll([
      '-map', '0:v',
      '-map', '0:a?',
      ...encodeTail,
    ]);
    return args;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      reelAudioTimelineProvider.select((s) => s.videoAudioMuted),
      (_, __) => _applyVideoAudioMute(),
    );

    final size = MediaQuery.of(context).size;
    final accent = ThemeHelper.getAccentColor(context);
    final themeData = _ReelEditThemeData(
      bg: ThemeHelper.getBackgroundColor(context),
      surface: ThemeHelper.getSurfaceColor(context),
      surface2: ThemeHelper.getSecondaryBackgroundColor(context),
      border: ThemeHelper.getBorderColor(context),
      accent: accent,
      accentAlt: AppColors.error,
      textPrim: ThemeHelper.getTextPrimary(context),
      textSec: ThemeHelper.getTextSecondary(context),
      textDim: ThemeHelper.getTextMuted(context),
    );

    return _ReelEditTheme(
      data: themeData,
      child: Scaffold(
        backgroundColor: _ReelEditTheme.of(context).bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: ListenableBuilder(
                  listenable: _editorState,
                  builder: (context, _) {
                    return Center(
                      child: _buildVideoViewport(size),
                    );
                  },
                ),
              ),
              _buildToolPanel(),
              _buildTabBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _IconBtn(
            Icons.close,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(widget.isImageMode ? 'EDIT PHOTO' : 'EDITOR',
              style: _DS.heading(context,
                  size: 11, color: _ReelEditTheme.of(context).textSec)),
          const Spacer(),
          ListenableBuilder(
            listenable: _layerState,
            builder: (context, _) {
              if (!_layerState.canUndo) return const SizedBox.shrink();
              return _IconBtn(
                Icons.undo_rounded,
                onTap: _layerState.undo,
                color: _ReelEditTheme.of(context).textSec,
              );
            },
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isExporting ? null : _handleExport,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: _isExporting
                    ? _ReelEditTheme.of(context).surface2
                    : _ReelEditTheme.of(context).accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _isExporting
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _ReelEditTheme.of(context).accent,
                ),
              )
                  : Text(
                'EXPORT',
                style: _DS.label(context,
                    color: ThemeHelper.getOnAccentColor(context),
                    weight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoViewport(Size screenSize) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isInitializing,
      builder: (context, isInitializing, _) {
        if (isInitializing) {
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _ReelEditTheme.of(context).accent),
            ),
          );
        }

        if (widget.isImageMode) {
          final iw = _imagePixelW;
          final ih = _imagePixelH;
          if (iw == null || ih == null || iw <= 0 || ih <= 0) {
            return Center(
              child: Icon(Icons.broken_image_outlined,
                  color: _ReelEditTheme.of(context).textDim, size: 40),
            );
          }
          final imageAspect = iw / ih;
          final selectedRatio =
              _aspectRatios[_editorState.aspectRatioIndex].ratio;
          final displayAspect = selectedRatio ?? imageAspect;

          final maxWidth = screenSize.width - 24;
          final maxHeight = screenSize.height * 0.55;

          double viewW, viewH;
          if (maxWidth / displayAspect <= maxHeight) {
            viewW = maxWidth;
            viewH = maxWidth / displayAspect;
          } else {
            viewH = maxHeight;
            viewW = maxHeight * displayAspect;
          }

          _videoDisplaySize = Size(viewW, viewH);

          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              key: _videoContainerKey,
              width: viewW,
              height: viewH,
              child: _buildImageStack(viewW, viewH),
            ),
          );
        }

        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) {
          return Center(
            child: Icon(Icons.broken_image_outlined,
                color: _ReelEditTheme.of(context).textDim, size: 40),
          );
        }

        final videoAspect = controller.value.aspectRatio;
        final selectedRatio =
            _aspectRatios[_editorState.aspectRatioIndex].ratio;
        final displayAspect = selectedRatio ?? videoAspect;

        final maxWidth = screenSize.width - 24;
        final maxHeight = screenSize.height * 0.55;

        double viewW, viewH;
        if (maxWidth / displayAspect <= maxHeight) {
          viewW = maxWidth;
          viewH = maxWidth / displayAspect;
        } else {
          viewH = maxHeight;
          viewW = maxHeight * displayAspect;
        }

        _videoDisplaySize = Size(viewW, viewH);

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            key: _videoContainerKey,
            width: viewW,
            height: viewH,
            child: _buildVideoStack(controller, viewW, viewH),
          ),
        );
      },
    );
  }

  Widget _buildVideoStack(
      VideoPlayerController controller, double width, double height) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: _onCanvasTap,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Video layer with effects
          Positioned.fill(
            child: RepaintBoundary(
              child: _buildVideoWithEffects(controller),
            ),
          ),

          // ALL OVERLAYS in one RepaintBoundary for capture
          // This captures: drawings, text, stickers
          Positioned.fill(
            child: RepaintBoundary(
              key: _overlayKey,
              child: Stack(
                children: [
                  // Drawing canvas (CustomPaint for strokes)
                  ValueListenableBuilder<List<Offset?>>(
                    valueListenable: _currentStroke,
                    builder: (context, stroke, _) {
                      return ListenableBuilder(
                        listenable:
                        Listenable.merge([_layerState, _brushState]),
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size(width, height),
                            painter: _LayerPainter(
                              layers: _layerState.layers,
                              currentStroke: stroke,
                              currentColor: _brushState.color,
                              currentStrokeWidth: _brushState.size,
                              currentBrush: _brushState.type,
                            ),
                            isComplex: true,
                            willChange: stroke.isNotEmpty,
                          );
                        },
                      );
                    },
                  ),

                  // Text and Sticker layers
                  _buildOverlayLayers(),
                ],
              ),
            ),
          ),

          // Crop overlay (NOT part of export)
          if (_editorState.activeTool == _Tool.crop)
            Positioned.fill(
              child: _CropOverlay(
                rect: _editorState.cropRect,
                onRectChanged: (rect) {
                  _editorState.cropRect = rect;
                  _editorState.notifyAdjustmentChanged();
                },
              ),
            ),

          // Vignette (applied via FFmpeg, but preview here)
          if (_editorState.vignette > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: _VignetteOverlay(intensity: _editorState.vignette),
              ),
            ),

          // Play button
          _buildPlayButton(),
        ],
      ),
    );
  }

  Widget _buildVideoWithEffects(VideoPlayerController controller) {
    Widget video = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );

    final colorFilter = _computeColorFilter();
    if (colorFilter != null) {
      video = ColorFiltered(colorFilter: colorFilter, child: video);
    }

    final blur = _effectiveBlur;
    if (blur > 0) {
      video = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: video,
      );
    }

    return video;
  }

  Widget _buildImageWithEffects() {
    final w = _imagePixelW!;
    final h = _imagePixelH!;
    Widget image = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: w,
          height: h,
          child: Image.file(
            widget.mediaFile,
            fit: BoxFit.cover,
            width: w,
            height: h,
          ),
        ),
      ),
    );

    final colorFilter = _computeColorFilter();
    if (colorFilter != null) {
      image = ColorFiltered(colorFilter: colorFilter, child: image);
    }

    final blur = _effectiveBlur;
    if (blur > 0) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: image,
      );
    }

    return image;
  }

  Widget _buildImageStack(double width, double height) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: _onCanvasTap,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: _fullImageExportKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: _buildImageWithEffects()),
                  Positioned.fill(
                    child: RepaintBoundary(
                      key: _overlayKey,
                      child: Stack(
                        children: [
                          ValueListenableBuilder<List<Offset?>>(
                            valueListenable: _currentStroke,
                            builder: (context, stroke, _) {
                              return ListenableBuilder(
                                listenable:
                                    Listenable.merge([_layerState, _brushState]),
                                builder: (context, _) {
                                  return CustomPaint(
                                    size: Size(width, height),
                                    painter: _LayerPainter(
                                      layers: _layerState.layers,
                                      currentStroke: stroke,
                                      currentColor: _brushState.color,
                                      currentStrokeWidth: _brushState.size,
                                      currentBrush: _brushState.type,
                                    ),
                                    isComplex: true,
                                    willChange: stroke.isNotEmpty,
                                  );
                                },
                              );
                            },
                          ),
                          _buildOverlayLayers(),
                        ],
                      ),
                    ),
                  ),
                  if (_editorState.vignette > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child:
                            _VignetteOverlay(intensity: _editorState.vignette),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_editorState.activeTool == _Tool.crop)
            Positioned.fill(
              child: _CropOverlay(
                rect: _editorState.cropRect,
                onRectChanged: (rect) {
                  _editorState.cropRect = rect;
                  _editorState.notifyAdjustmentChanged();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    if (widget.isImageMode) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: _isPlaying,
      builder: (context, isPlaying, _) {
        if (isPlaying || _editorState.activeTool != _Tool.none) {
          return const SizedBox.shrink();
        }

        return Center(
          child: GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }

  // Build overlay layers - hide selection UI during export
  Widget _buildOverlayLayers() {
    return ListenableBuilder(
      listenable: _layerState,
      builder: (context, _) {
        final children = <Widget>[];

        for (int i = 0; i < _layerState.layers.length; i++) {
          final layer = _layerState.layers[i];
          if (layer is _DrawLayer) continue; // Handled by CustomPaint

          children.add(
            _InteractiveLayerWidget(
              key: ValueKey(layer.id),
              layer: layer,
              // Hide selection border during export
              isSelected: _layerState.selectedIndex == i && !_isExporting,
              onTap: () {
                if (_layerState.selectedIndex == i) {
                  if (layer is _TextLayer) {
                    _showTextEditor(editIndex: i);
                  }
                } else {
                  _layerState.selectedIndex = i;
                }
              },
              onTransformUpdate: (position, scale, rotation) {
                _layerState.updateLayerTransform(
                  i,
                  position: position,
                  scale: scale,
                  rotation: rotation,
                );
              },
              onDelete: () => _layerState.removeLayer(i),
              hideControls: _isExporting,
            ),
          );
        }

        return Stack(children: children);
      },
    );
  }

  Widget _buildToolPanel() {
    return ListenableBuilder(
      listenable: _editorState,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _buildToolPanelContent(),
        );
      },
    );
  }

  Widget _buildToolPanelContent() {
    return switch (_editorState.activeTool) {
      _Tool.paint =>
          _PaintPanel(key: const ValueKey('paint'), brushState: _brushState),
      _Tool.filter => _FilterPanel(
        key: const ValueKey('filter'),
        selectedIndex: _editorState.filterIndex,
        onFilterSelected: (index) => _editorState.filterIndex = index,
      ),
      _Tool.adjust =>
          _AdjustPanel(key: const ValueKey('adjust'), editorState: _editorState),
      _Tool.crop => _CropPanel(
        key: const ValueKey('crop'),
        selectedIndex: _editorState.aspectRatioIndex,
        onAspectRatioSelected: (index) {
          _editorState.aspectRatioIndex = index;
          _editorState.notifyAdjustmentChanged();
        },
      ),
      _Tool.trim => widget.isImageMode
          ? const SizedBox.shrink(key: ValueKey('trim_none'))
          : _TrimPanel(
              key: const ValueKey('trim'),
              controller: _videoController,
              trimStart: _editorState.trimStart,
              trimEnd: _editorState.trimEnd,
              isPlaying: _isPlaying,
              onTrimChanged: (start, end) {
                _editorState.trimStart = start;
                _editorState.trimEnd = end;
                _editorState.notifyAdjustmentChanged();
                final c = _videoController;
                if (c != null) _syncPlaybackState(c);
              },
              onTogglePlay: _togglePlay,
              onSeek: (position) {
                final duration =
                    _videoController?.value.duration ?? Duration.zero;
                _videoController?.seekTo(Duration(
                  milliseconds: (duration.inMilliseconds * position).round(),
                ));
              },
            ),
      _Tool.audio => widget.isImageMode
          ? const SizedBox.shrink(key: ValueKey('audio_none'))
          : ReelAudioTimelinePanel(
              key: const ValueKey('audio'),
              videoFilePath: widget.mediaFile.path,
              onTogglePlay: _togglePlay,
              onSeekRelativeSec: (sec) async {
                final controller = _videoController;
                if (controller == null || !controller.value.isInitialized) {
                  return;
                }
                final duration = controller.value.duration;
                final trimStartMs =
                    (duration.inMilliseconds * _editorState.trimStart).round();
                await controller.seekTo(
                  Duration(milliseconds: trimStartMs + (sec * 1000).round()),
                );
                _syncPlaybackState(controller);
                if (!controller.value.isPlaying) {
                  await controller.play();
                  _isPlaying.value = true;
                  _syncPlaybackState(controller);
                }
                _applyVideoAudioMute();
              },
            ),
      _ => const SizedBox.shrink(key: ValueKey('none')),
    };
  }

  Widget _buildTabBar() {
    final tabs = <(IconData, String, _Tool)>[
      if (!widget.isImageMode)
        (Icons.content_cut_rounded, 'TRIM', _Tool.trim),
      if (!widget.isImageMode)
        (Icons.library_music_outlined, 'AUDIO', _Tool.audio),
      (Icons.crop_rounded, 'CROP', _Tool.crop),
      (Icons.filter_rounded, 'FILTER', _Tool.filter),
      (Icons.tune_rounded, 'ADJUST', _Tool.adjust),
      (Icons.edit_rounded, 'DRAW', _Tool.paint),
      (Icons.title_rounded, 'TEXT', _Tool.text),
      (Icons.emoji_emotions_rounded, 'STICKER', _Tool.sticker),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _ReelEditTheme.of(context).surface,
        border: Border(
            top: BorderSide(color: _ReelEditTheme.of(context).border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: ListenableBuilder(
          listenable: _editorState,
          builder: (context, _) {
            return Row(
              children: tabs.map((tab) {
                final isActive = _editorState.activeTool == tab.$3;
                return _TabButton(
                  icon: tab.$1,
                  label: tab.$2,
                  isActive: isActive,
                  onTap: () => _selectTool(tab.$3),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
