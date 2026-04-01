import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/livestream_controller_riverpod.dart';
import '../../core/utils/theme_helper.dart';

class LiveStreamWatchScreen extends ConsumerWidget {
  static const routeName = '/live/watch';
  final String streamId;
  const LiveStreamWatchScreen({super.key, required this.streamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(livestreamControllerProvider);
    if (s.state == LiveStreamState.ended) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Livestream ended',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.92 * 255).round()),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await ref.read(livestreamControllerProvider.notifier).leave();
                      if (nav.canPop()) nav.pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: ThemeHelper.getAccentColor(context),
                      foregroundColor:
                          ThemeHelper.getOnAccentColor(context),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final accent = ThemeHelper.getAccentColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final text = ThemeHelper.getTextPrimary(context);
    final muted = ThemeHelper.getTextSecondary(context);

    final engine = ref.read(livestreamControllerProvider.notifier).engine;
    final remoteUid = s.rtc.remoteUids.isNotEmpty ? s.rtc.remoteUids.first : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (engine == null || remoteUid == null)
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: remoteUid),
                connection: RtcConnection(channelId: s.auth?.channelName ?? ''),
              ),
            ),
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
                  Row(
                    children: [
                      _CircleAction(
                        icon: Icons.close_rounded,
                        bg: surface,
                        border: border,
                        color: text,
                        onTap: () async {
                          final nav = Navigator.of(context);
                          await ref.read(livestreamControllerProvider.notifier).leave();
                          if (nav.canPop()) nav.pop();
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.stream?.title.isNotEmpty == true ? s.stream!.title : 'Live',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.92 * 255).round()),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _Pill(text: '👁 ${s.viewerCount}', bg: surface, border: border, fg: text),
                      const SizedBox(width: 10),
                      _Pill(text: '♥ ${s.likeCount}', bg: surface, border: border, fg: text),
                    ],
                  ),
                  // Messaging & like UI temporarily disabled for subscribers
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  final Color fg;
  const _Pill({required this.text, required this.bg, required this.border, required this.fg});

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
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800),
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

