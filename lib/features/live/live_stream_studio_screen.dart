import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/livestream_controller_riverpod.dart';
import '../../core/utils/theme_helper.dart';

class LiveStreamStudioScreen extends ConsumerStatefulWidget {
  static const routeName = '/live/studio';
  const LiveStreamStudioScreen({super.key});

  @override
  ConsumerState<LiveStreamStudioScreen> createState() =>
      _LiveStreamStudioScreenState();
}

class _LiveStreamStudioScreenState extends ConsumerState<LiveStreamStudioScreen> {
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  bool _booting = true;
  String? _bootError;
  bool _detailsSaved = false;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _thumbCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();

  Timer? _disposeTimer;

  @override
  void initState() {
    super.initState();
    // No setState-driven UI state; we only set up camera controller.
    unawaited(_bootCamera());
  }

  @override
  void dispose() {
    _disposeTimer?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _thumbCtrl.dispose();
    _chatCtrl.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _bootCamera() async {
    try {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!cam.isGranted || !mic.isGranted) {
        _bootError = 'Camera and microphone permission required';
        _booting = false;
        if (mounted) setState(() {});
        return;
      }

      _cameras = await availableCameras();
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.isNotEmpty ? _cameras.first : throw StateError('No camera'),
      );
      _camera = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _camera!.initialize();
      _booting = false;
      if (mounted) setState(() {});
    } catch (e) {
      _bootError = e.toString();
      _booting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty) return;
    final current = _camera?.description;
    if (current == null) return;
    final next = _cameras.firstWhere(
      (c) => c.lensDirection != current.lensDirection,
      orElse: () => current,
    );
    if (next.name == current.name) return;

    final old = _camera;
    _camera = CameraController(next, ResolutionPreset.high, enableAudio: false);
    try {
      await _camera!.initialize();
      if (mounted) setState(() {});
    } finally {
      _disposeTimer?.cancel();
      _disposeTimer = Timer(const Duration(milliseconds: 600), () {
        old?.dispose();
      });
    }
  }

  Future<void> _startLive() async {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    // Go Live immediately; mark details as saved to update UI pills.
    _detailsSaved = true;
    final channelName =
        'stream_${me.id}_${DateTime.now().millisecondsSinceEpoch}';
    final started = await ref.read(livestreamControllerProvider.notifier).startHost(
          channelName: channelName,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          thumbnail: _thumbCtrl.text.trim().isNotEmpty ? _thumbCtrl.text.trim() : null,
        );
    if (started) {
      // Release CameraPreview to avoid dual capture/backpressure once Agora takes over.
      await _camera?.dispose();
      _camera = null;
    }
  }

  Future<bool> _confirmEndIfLive(BuildContext context) async {
    final s = ref.read(livestreamControllerProvider);
    final isActive = s.state == LiveStreamState.live || s.state == LiveStreamState.loading;
    if (!isActive) return true;
    final shouldEnd = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('End livestream?'),
            content: const Text('If you leave, the livestream will end.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('End & Leave'),
              ),
            ],
          ),
        ) ??
        false;
    if (shouldEnd) {
      await ref.read(livestreamControllerProvider.notifier).endHost();
    }
    return shouldEnd;
  }

  Future<void> _openDetailsSheet() async {
    final bgColor = ThemeHelper.getBackgroundColor(context);
    final surfaceColor = ThemeHelper.getSurfaceColor(context);
    final borderColor = ThemeHelper.getBorderColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final textSecondary = ThemeHelper.getTextSecondary(context);
    final accent = ThemeHelper.getAccentColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor.withAlpha((0.6 * 255).round()), width: 1),
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: textPrimary.withAlpha((isDark ? 0.25 : 0.12 * 255).round()),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Live details',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          splashRadius: 20,
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Add a title & description (optional).',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleCtrl,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Description',
                        hintStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _thumbCtrl,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Thumbnail URL (optional)',
                        hintStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: ThemeHelper.getOnAccentColor(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _detailsSaved = true);
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(livestreamControllerProvider);
    final accent = ThemeHelper.getAccentColor(context);
    final bg = ThemeHelper.getBackgroundColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final text = ThemeHelper.getTextPrimary(context);
    final muted = ThemeHelper.getTextSecondary(context);

    final isLive = s.state == LiveStreamState.live;
    final isPublisher = s.auth?.role == 'publisher';

    return WillPopScope(
      onWillPop: () => _confirmEndIfLive(context),
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
          // Full-screen camera/Agora
          if (isLive)
            (ref.read(livestreamControllerProvider.notifier).engine == null)
                ? Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  )
                : AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: ref.read(livestreamControllerProvider.notifier).engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  )
          else if (_booting)
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else if (_bootError != null)
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Text(
                _bootError!,
                style: TextStyle(color: Colors.white.withAlpha((0.9 * 255).round())),
                textAlign: TextAlign.center,
              ),
            )
          else if (_camera?.value.isInitialized == true)
            CameraPreview(_camera!)
          else
            Container(color: Colors.black),

          // Vignette
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha((0.55 * 255).round()),
                    Colors.transparent,
                    Colors.black.withAlpha((0.65 * 255).round()),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Stack(
                children: [
                  // Top bar
                  Row(
                    children: [
                      _CircleAction(
                        icon: Icons.close_rounded,
                        bg: surface,
                        border: border,
                        color: text,
                        onTap: () async {
                          final nav = Navigator.of(context);
                          if (isLive) {
                            await ref.read(livestreamControllerProvider.notifier).endHost();
                          }
                          if (nav.canPop()) nav.pop();
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isLive ? 'Live' : 'Go Live',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.92 * 255).round()),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isLive)
                        _CircleAction(
                          icon: Icons.tune_rounded,
                          bg: surface,
                          border: border,
                          color: text,
                          onTap: () async => _openDetailsSheet(),
                        ),
                      const SizedBox(width: 10),
                      if (!isLive)
                        _CircleAction(
                          icon: Icons.cameraswitch_rounded,
                          bg: surface,
                          border: border,
                          color: text,
                          onTap: () async => _switchCamera(),
                        ),
                    ],
                  ),

                  // Pills
                  Positioned(
                    left: 0,
                    top: 58,
                    child: _Pill(
                      text: isLive ? 'LIVE' : (_detailsSaved ? 'READY' : 'DETAILS'),
                      bg: surface,
                      border: border,
                      fg: isLive ? const Color(0xFFEF4444) : accent,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 58,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Pill(text: '👁 ${s.viewerCount}', bg: surface, border: border, fg: text),
                        const SizedBox(height: 10),
                        if (!isPublisher)
                          _Pill(text: '♥ ${s.likeCount}', bg: surface, border: border, fg: text),
                      ],
                    ),
                  ),

                  // Bottom controls: chat + actions
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isLive) ...[
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha((0.35 * 255).round()),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                              border: Border.all(
                                color: Colors.white.withAlpha((0.10 * 255).round()),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _titleCtrl.text.trim().isNotEmpty
                                      ? _titleCtrl.text.trim()
                                      : 'Ready to go live',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((0.92 * 255).round()),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 52,
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _startLive,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accent,
                                      foregroundColor:
                                          ThemeHelper.getOnAccentColor(context),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Go Live',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (isPublisher) ...[
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha((0.35 * 255).round()),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                              border: Border.all(
                                color: Colors.white.withAlpha((0.10 * 255).round()),
                                width: 1,
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          ref.read(livestreamControllerProvider.notifier).toggleMic(),
                                      icon: const Icon(Icons.mic_rounded),
                                      label: Text(
                                        s.rtc.micMuted ? 'Mic Off' : 'Mic On',
                                        style: TextStyle(
                                          color: text,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: border),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _CircleAction(
                                    icon: Icons.cameraswitch_rounded,
                                    bg: surface,
                                    border: border,
                                    color: text,
                                    onTap: () async => ref
                                        .read(livestreamControllerProvider.notifier)
                                        .switchCamera(),
                                  ),
                                  const SizedBox(width: 10),
                                  _CircleAction(
                                    icon: Icons.stop_circle_rounded,
                                    bg: const Color(0xFFEF4444),
                                    border: Colors.transparent,
                                    color: Colors.white,
                                    onTap: () async {
                                      final nav = Navigator.of(context);
                                      await ref
                                          .read(livestreamControllerProvider.notifier)
                                          .endHost();
                                      if (!mounted) return;
                                      if (nav.canPop()) nav.pop();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          // Subscriber-like controls (should not be used on publisher mode).
                          const SizedBox.shrink(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ), // Scaffold
  ); // WillPopScope
  } // build
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  final Color fg;
  const _Pill({
    required this.text,
    required this.bg,
    required this.border,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withAlpha((0.88 * 255).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withAlpha((0.7 * 255).round())),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color border;
  final Color color;
  const _CircleAction({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.border,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

