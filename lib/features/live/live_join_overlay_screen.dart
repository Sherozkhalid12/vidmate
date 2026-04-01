import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/livestream_model.dart';
import '../../core/providers/livestream_controller_riverpod.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/utils/theme_helper.dart';
import 'live_stream_watch_screen.dart';
import 'live_stream_studio_screen.dart';

class LiveJoinOverlayScreen extends ConsumerWidget {
  final LivestreamModel stream;
  const LiveJoinOverlayScreen({super.key, required this.stream});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = ThemeHelper.getBackgroundColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final text = ThemeHelper.getTextPrimary(context);
    final muted = ThemeHelper.getTextSecondary(context);
    final accent = ThemeHelper.getAccentColor(context);
    final currentUser = ref.watch(currentUserProvider);
    final myId = currentUser?.id ?? '';
    final isHost = stream.hostId == myId;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (stream.thumbnail.isNotEmpty)
            Image.network(
              stream.thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: surface),
            )
          else
            Container(color: surface),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha((0.55 * 255).round()),
                  Colors.transparent,
                  Colors.black.withAlpha((0.75 * 255).round()),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: text),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withAlpha((0.95 * 255).round()),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: bg.withAlpha((0.92 * 255).round()),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: border.withAlpha((0.7 * 255).round())),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          stream.title.isNotEmpty ? stream.title : 'Live stream',
                          style: TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stream.description.isNotEmpty
                              ? stream.description
                              : 'Join now to watch live.',
                          style: TextStyle(color: muted, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: (stream.host?.profilePicture ?? '').isNotEmpty
                                  ? NetworkImage(stream.host!.profilePicture)
                                  : null,
                              backgroundColor: surface,
                              child: (stream.host?.profilePicture ?? '').isEmpty
                                  ? Icon(Icons.person, color: muted)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stream.host?.username ?? 'Host',
                                style: TextStyle(
                                  color: text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: border),
                              ),
                              child: Text(
                                '👁 ${stream.viewerCount}',
                                style: TextStyle(
                                  color: text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
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
                            onPressed: () async {
                              if (isHost) {
                                final ok = await ref
                                    .read(livestreamControllerProvider.notifier)
                                    .enterAsHostExisting(
                                      streamId: stream.streamId,
                                      uid: stream.hostUid,
                                    );
                                if (!context.mounted) return;
                                if (ok) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          LiveStreamStudioScreen(),
                                    ),
                                  );
                                }
                                return;
                              }

                              final ok = await ref
                                  .read(livestreamControllerProvider.notifier)
                                  .joinAsViewer(streamId: stream.streamId);
                              if (!context.mounted) return;
                              if (ok) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LiveStreamWatchScreen(streamId: stream.streamId),
                                  ),
                                );
                              } else {
                                final err = ref
                                        .read(livestreamControllerProvider)
                                        .errorMessage ??
                                    'Livestream is no longer active.';
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Stream unavailable'),
                                    content: Text(err),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            child: Text(
                              isHost ? 'Go Live' : 'Join',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

