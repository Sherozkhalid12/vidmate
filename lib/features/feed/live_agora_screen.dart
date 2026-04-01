import 'dart:ui';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/livestream_controller_riverpod.dart';
import '../../core/utils/theme_helper.dart';

/// Agora-based Live screen for the host (publisher).
///
/// Flow: start API -> get appId/token/channel/uid -> join RTC as broadcaster.
class LiveAgoraScreen extends ConsumerStatefulWidget {
  const LiveAgoraScreen({super.key});

  @override
  ConsumerState<LiveAgoraScreen> createState() => _LiveAgoraScreenState();
}

class _LiveAgoraScreenState extends ConsumerState<LiveAgoraScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(livestreamControllerProvider);
    final auth = ctrl.auth;
    final rtc = ctrl.rtc;

    final bg = ThemeHelper.getBackgroundColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final accent = ThemeHelper.getAccentColor(context);
    final text = ThemeHelper.getTextPrimary(context);
    final muted = ThemeHelper.getTextMuted(context);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bg, surface, accent.withAlpha((0.10 * 255).round())],
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(color: Colors.transparent),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _GlassIcon(
                        icon: Icons.close_rounded,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await ref.read(livestreamControllerProvider.notifier).endHost();
                          if (!mounted) return;
                          if (navigator.canPop()) {
                            navigator.pop();
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth?.stream.title.isNotEmpty == true
                              ? auth!.stream.title
                              : 'Live',
                          style: TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _Pill(
                        text: rtc.joined ? 'Live' : 'Starting…',
                        border: border,
                        surface: surface,
                        textColor: muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ref.read(livestreamControllerProvider.notifier).engine == null
                              ? _LoadingPreview(accent: accent, muted: muted)
                              : AgoraVideoView(
                                  controller: VideoViewController(
                                    rtcEngine: ref.read(livestreamControllerProvider.notifier).engine!,
                                    canvas: const VideoCanvas(uid: 0),
                                  ),
                                ),
                          Positioned(
                            left: 14,
                            top: 14,
                            child: _LiveBadge(accent: accent, pulse: _pulse),
                          ),
                          Positioned(
                            right: 14,
                            top: 14,
                            child: _Pill(
                              text: 'UID ${rtc.localUid ?? auth?.uid ?? 0}',
                              border: border,
                              surface: surface,
                              textColor: muted,
                            ),
                          ),
                          if (rtc.lastError != null && rtc.lastError!.isNotEmpty)
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 14,
                              child: _ErrorCard(
                                message: rtc.lastError!,
                                border: border,
                                surface: surface,
                                text: text,
                                muted: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'End Live',
                          color: const Color(0xFFEF4444),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            await ref.read(livestreamControllerProvider.notifier).endHost();
                            if (!mounted) return;
                            if (navigator.canPop()) navigator.pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RoundAction(
                        icon: Icons.mic_rounded,
                        onTap: () async => ref.read(livestreamControllerProvider.notifier).toggleMic(),
                        border: border,
                        surface: surface,
                        iconColor: ThemeHelper.getHighContrastIconColor(context),
                      ),
                      const SizedBox(width: 10),
                      _RoundAction(
                        icon: Icons.cameraswitch_rounded,
                        onTap: () async => ref.read(livestreamControllerProvider.notifier).switchCamera(),
                        border: border,
                        surface: surface,
                        iconColor: ThemeHelper.getHighContrastIconColor(context),
                      ),
                    ],
                  ),
                  if (rtc.remoteUids.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Viewers connected: ${rtc.remoteUids.length}',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPreview extends StatelessWidget {
  final Color accent;
  final Color muted;
  const _LoadingPreview({required this.accent, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
            const SizedBox(height: 14),
            Text('Preparing live…', style: TextStyle(color: muted)),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final Color accent;
  final Animation<double> pulse;
  const _LiveBadge({required this.accent, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha((0.45 * 255).round()),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accent.withAlpha(((0.35 + pulse.value * 0.25) * 255).round()),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color border;
  final Color surface;
  final Color textColor;
  const _Pill({
    required this.text,
    required this.border,
    required this.surface,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surface.withAlpha((0.55 * 255).round()),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border.withAlpha((0.8 * 255).round())),
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final iconColor = ThemeHelper.getHighContrastIconColor(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: surface.withAlpha((0.35 * 255).round()),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border.withAlpha((0.8 * 255).round())),
              ),
              child: Icon(icon, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color border;
  final Color surface;
  final Color iconColor;
  const _RoundAction({
    required this.icon,
    required this.onTap,
    required this.border,
    required this.surface,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: surface.withAlpha((0.35 * 255).round()),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border.withAlpha((0.85 * 255).round())),
              ),
              child: Icon(icon, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [color, color.withAlpha((0.88 * 255).round())],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha((0.35 * 255).round()),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Color border;
  final Color surface;
  final Color text;
  final Color muted;
  const _ErrorCard({
    required this.message,
    required this.border,
    required this.surface,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface.withAlpha((0.7 * 255).round()),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border.withAlpha((0.85 * 255).round())),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

