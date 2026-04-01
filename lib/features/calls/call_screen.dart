import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/agora_call_provider_riverpod.dart';
import '../../core/providers/calls_provider_riverpod.dart';
import '../../core/models/call_model.dart';
import '../../core/utils/theme_helper.dart';

class CallScreen extends ConsumerStatefulWidget {
  static const String routeName = '/call';

  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;

  Timer? _durationTimer;
  int _seconds = 0;
  bool _rtcBootstrapped = false;
  Timer? _callerWaitTimeout;
  String? _callerWaitForCallId;
  bool _rtcJoinInFlight = false;
  Offset _pipOffset = const Offset(16, 110);

  Future<void> _ensureRtcJoined({
    required CallsState callsState,
    required CallModel call,
  }) async {
    if (!mounted) return;
    if (_rtcJoinInFlight) return;

    final appId = callsState.agoraAppId;
    final token = callsState.agoraToken;
    final uid = callsState.agoraUid ?? 0;
    if (appId == null || appId.isEmpty) return;
    if (token == null || token.isEmpty) return;
    if (call.channelName.isEmpty) return;

    final rtc = ref.read(agoraCallProvider);
    if (rtc.joined) return;

    _rtcJoinInFlight = true;
    try {
      // Call type defaults:
      // - Voice call: mic only (camera OFF, speaker OFF)
      // - Video call: mic + camera + speaker ON as soon as we join
      if (callsState.startWithVideo) {
        await ref.read(agoraCallProvider.notifier).setSpeakerOn(true);
        await ref.read(agoraCallProvider.notifier).setCameraOn(true);
      } else {
        await ref.read(agoraCallProvider.notifier).setSpeakerOn(false);
        await ref.read(agoraCallProvider.notifier).setCameraOn(false);
      }

      // Init is idempotent (provider guards initialized).
      await ref.read(agoraCallProvider.notifier).init(
            appId: appId,
            enableVideo: true,
          );
      await ref.read(agoraCallProvider.notifier).join(
            token: token,
            channelName: call.channelName,
            uid: uid,
          );
    } catch (e) {
      // Do not crash. Surface to snackbar via provider listener below.
      debugPrint('[CallScreen] ensureRtcJoined error: $e');
    } finally {
      _rtcJoinInFlight = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();

    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callerWaitTimeout?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startTimerIfNeeded(CallsState state) {
    if (state.status != CallUiStatus.inCall) return;
    if (_durationTimer != null) return;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  void _stopTimerIfNeeded(CallsState state) {
    if (state.status == CallUiStatus.inCall) return;
    _durationTimer?.cancel();
    _durationTimer = null;
    _seconds = 0;
  }

  String _formatDuration() {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final callsState = ref.watch(callsProvider);
    final me = ref.watch(currentUserProvider);
    final rtcState = ref.watch(agoraCallProvider);

    final call = callsState.currentCall ?? callsState.incomingCall?.call;
    final isIncoming = callsState.status == CallUiStatus.incoming;
    final isOutgoing = callsState.status == CallUiStatus.startingOutgoing;
    final isInCall = callsState.status == CallUiStatus.inCall;
    final isEnding = callsState.status == CallUiStatus.ending;
    final isEnded = callsState.status == CallUiStatus.ended;

    // Bootstraps Agora only when we should actually connect:
    // - Outgoing caller: startingOutgoing/inCall
    // - Receiver: only after pressing Accept (status becomes inCall)
    if (!_rtcBootstrapped &&
        call != null &&
        call.channelName.isNotEmpty &&
        (callsState.status == CallUiStatus.inCall ||
            callsState.status == CallUiStatus.startingOutgoing)) {
      _rtcBootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _ensureRtcJoined(callsState: callsState, call: call);
      });
    }

    // Timer lifecycle
    if (isInCall) {
      _startTimerIfNeeded(callsState);
    } else {
      _stopTimerIfNeeded(callsState);
    }

    // Caller timeout: if remote never joins, leave and end call.
    final isCaller = call != null && me != null && call.callerId == me.id;
    final callIdNow = call?.callId ?? '';

    // Critical: cancel any previous "caller wait" timer if role/call changed.
    if (!isCaller || callIdNow.isEmpty || (_callerWaitForCallId != null && _callerWaitForCallId != callIdNow)) {
      _callerWaitTimeout?.cancel();
      _callerWaitTimeout = null;
      _callerWaitForCallId = null;
    }

    if (isCaller &&
        (callsState.status == CallUiStatus.startingOutgoing ||
            callsState.status == CallUiStatus.inCall) &&
        rtcState.remoteUid == null &&
        _callerWaitTimeout == null) {
      _callerWaitForCallId = callIdNow;
      _callerWaitTimeout = Timer(const Duration(seconds: 35), () async {
        if (!mounted) return;
        final stillNoRemote = ref.read(agoraCallProvider).remoteUid == null;
        final latest = ref.read(callsProvider).currentCall;
        final myId = ref.read(currentUserProvider)?.id ?? '';
        final currentCallId = latest?.callId ?? '';

        // Only end if we're still the caller for the same callId.
        final amStillCaller = latest != null && myId.isNotEmpty && latest.callerId == myId;
        final sameCall = _callerWaitForCallId != null && _callerWaitForCallId == currentCallId;
        final stillActive = ref.read(callsProvider).status == CallUiStatus.inCall ||
            ref.read(callsProvider).status == CallUiStatus.startingOutgoing;
        final callStatus = (latest?.status ?? '').toLowerCase();
        final acceptedByServer = callStatus == 'accepted';

        // Important: once the receiver accepted, do NOT auto-end from the "ringing timeout".
        // At that stage we're waiting for RTC join, which can take longer on some devices.
        if (stillNoRemote &&
            stillActive &&
            amStillCaller &&
            sameCall &&
            !acceptedByServer &&
            currentCallId.isNotEmpty) {
          await ref.read(agoraCallProvider.notifier).leave();
          await ref.read(callsProvider.notifier).endCurrentCall(callId: currentCallId);
        }
      });
    }
    if (rtcState.remoteUid != null) {
      _callerWaitTimeout?.cancel();
      _callerWaitTimeout = null;
    }

    ref.listen<CallsState>(callsProvider, (prev, next) {
      if (prev == next) return;

      // Critical: when caller receives `calls:accepted`, token/appId are present but
      // we might have missed the initial join attempt (or it failed silently).
      // Retry joining RTC whenever we're in-call and not yet joined.
      final nextCall = next.currentCall ?? next.incomingCall?.call;
      if (next.status == CallUiStatus.inCall &&
          nextCall != null &&
          !ref.read(agoraCallProvider).joined) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _ensureRtcJoined(callsState: next, call: nextCall);
        });
      }

      if (next.status == CallUiStatus.ended) {
        // Ensure RTC leaves quickly.
        ref.read(agoraCallProvider.notifier).leave();
        final navigator = Navigator.of(context);
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          if (navigator.canPop()) navigator.pop();
          ref.read(callsProvider.notifier).reset();
          // Reset for next call session.
          _rtcBootstrapped = false;
        });
      }
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: ThemeHelper.getAccentColor(context),
          ),
        );
      }
    });

    // Show Agora/RTC errors (speaker not-ready, join errors, etc.) without crashing.
    ref.listen<AgoraCallState>(agoraCallProvider, (prev, next) {
      if (prev?.error == next.error) return;
      final msg = next.error;
      if (msg == null || msg.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ThemeHelper.getAccentColor(context),
        ),
      );
    });

    final accent = ThemeHelper.getAccentColor(context);
    final bg = ThemeHelper.getBackgroundColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final textPrimary = ThemeHelper.getTextPrimary(context);
    final muted = ThemeHelper.getTextMuted(context);

    final isMeCaller = call != null && me != null && call.callerId == me.id;
    final remoteName = (callsState.remoteUsername != null &&
            callsState.remoteUsername!.trim().isNotEmpty)
        ? callsState.remoteUsername!.trim()
        : (isIncoming ? 'Incoming call' : 'Calling…');
    final remoteAvatar = callsState.remoteProfilePicture ?? '';

    final hasRemote = rtcState.remoteUid != null;
    final title = isInCall
        ? (hasRemote ? 'Connected' : (isMeCaller ? 'Calling' : 'Connecting'))
        : isIncoming
            ? 'Incoming call'
            : isOutgoing
                ? 'Calling'
                : isEnding
                    ? 'Ending call'
                    : isEnded
                        ? 'Call ended'
                        : 'Call';

    final subtitle = isInCall
        ? (hasRemote ? _formatDuration() : (isMeCaller ? 'Ringing…' : 'Joining…'))
        : isIncoming
            ? remoteName
            : isOutgoing
                ? 'Connecting…'
                : isEnding
                    ? 'Please wait…'
                    : '';

    final engine = ref.read(agoraCallProvider.notifier).engine;
    final remoteUid = rtcState.remoteUid;
    final showRemoteVideo = isInCall &&
        engine != null &&
        remoteUid != null &&
        rtcState.remoteVideoAvailable;
    final showLocalPip =
        isInCall && engine != null && rtcState.joined && rtcState.cameraOn;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showRemoteVideo)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: remoteUid),
                connection: RtcConnection(channelId: call?.channelName ?? ''),
              ),
            ),

          // When remote video is shown, do not cover it with frosted UI.
          if (!showRemoteVideo) ...[
            // Smooth gradient background
            AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    bg,
                    surface,
                    accent.withAlpha((0.10 * 255).round()),
                  ],
                ),
              ),
            ),

            // Frosted glass overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(color: Colors.transparent),
            ),
          ] else ...[
            // Subtle vignette for readability over video
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
          ],

          if (showLocalPip)
            Positioned(
              left: _pipOffset.dx,
              top: _pipOffset.dy,
              child: GestureDetector(
                onPanUpdate: (d) {
                  if (!mounted) return;
                  setState(() {
                    _pipOffset = Offset(
                      (_pipOffset.dx + d.delta.dx).clamp(8, MediaQuery.of(context).size.width - 140),
                      (_pipOffset.dy + d.delta.dy).clamp(60, MediaQuery.of(context).size.height - 220),
                    );
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 128,
                    height: 176,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.55 * 255).round()),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.25 * 255).round()),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  children: [
                      Row(
                      children: [
                        _IconGlassButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          onTap: () {
                            // Prevent accidental close while in-call; user should end call.
                            if (isInCall || isEnding) return;
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                            ref.read(callsProvider.notifier).reset();
                          },
                        ),
                        const Spacer(),
                          // Removed callId/channelName pill (avoid leaking internal ids in UI)
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Avatar + pulse rings
                    if (!showRemoteVideo)
                      Expanded(
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulse,
                                builder: (context, _) {
                                  final t = _pulse.value;
                                  return Container(
                                    width: 240 + (t * 22),
                                    height: 240 + (t * 22),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accent.withAlpha(((0.06 + (t * 0.04)) * 255).round()),
                                      border: Border.all(
                                        color: accent.withAlpha(((0.18 + (t * 0.10)) * 255).round()),
                                        width: 1.2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: surface,
                                  border: Border.all(color: border, width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha((0.12 * 255).round()),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _Avatar(url: remoteAvatar),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    const SizedBox(height: 8),

                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      child: Text(
                        subtitle,
                        key: ValueKey(subtitle),
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Controls (animated)
                    _ControlsRow(
                      disabled: isEnding || isEnded,
                      micOn: !rtcState.micMuted,
                      speakerOn: rtcState.speakerOn,
                      videoOn: rtcState.cameraOn,
                      onToggleMic: () => ref.read(agoraCallProvider.notifier).toggleMic(),
                      onToggleSpeaker: () => ref.read(agoraCallProvider.notifier).toggleSpeaker(),
                      onToggleVideo: () async {
                        // WhatsApp-like behavior: when enabling video, ensure speaker is ON.
                        final turningOn = !ref.read(agoraCallProvider).cameraOn;
                        await ref.read(agoraCallProvider.notifier).toggleCamera();
                        if (turningOn) {
                          await ref.read(agoraCallProvider.notifier).setSpeakerOn(true);
                        }
                      },
                    ),

                    const SizedBox(height: 22),

                    // Primary action row
                    if (isIncoming) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Decline',
                              color: const Color(0xFFEF4444),
                              onTap: () => ref
                                  .read(callsProvider.notifier)
                                  .declineIncomingCall(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ActionButton(
                              label: 'Accept',
                              color: const Color(0xFF22C55E),
                              onTap: () async => ref
                                  .read(callsProvider.notifier)
                                  .acceptIncomingCall(),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      _ActionButton(
                        label: isInCall
                            ? 'End call'
                            : isOutgoing
                                ? 'Cancel'
                                : 'Close',
                        color: const Color(0xFFEF4444),
                        loading: isEnding,
                        onTap: () async {
                          if (call == null) {
                            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                            ref.read(callsProvider.notifier).reset();
                            return;
                          }
                          await ref.read(agoraCallProvider.notifier).leave();
                          await ref.read(callsProvider.notifier).endCurrentCall(
                                callId: call.callId,
                              );
                        },
                      ),
                    ],

                    if (isOutgoing && isMeCaller) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Waiting for receiver…',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final bg = ThemeHelper.getSurfaceColor(context);
    final icon = ThemeHelper.getTextMuted(context);
    if (url.isEmpty) {
      return Container(
        color: bg,
        child: Icon(Icons.person_rounded, size: 54, color: icon),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, imageUrl) => Container(color: bg),
      errorWidget: (context, imageUrl, error) => Container(
        color: bg,
        child: Icon(Icons.person_rounded, size: 54, color: icon),
      ),
    );
  }
}

// _Pill removed (we no longer display callId/channelName in UI)

class _IconGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconGlassButton({required this.icon, required this.onTap});

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
                border: Border.all(color: border.withAlpha((0.7 * 255).round()), width: 1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlsRow extends StatelessWidget {
  final bool disabled;
  final bool micOn;
  final bool speakerOn;
  final bool videoOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleVideo;

  const _ControlsRow({
    required this.disabled,
    required this.micOn,
    required this.speakerOn,
    required this.videoOn,
    required this.onToggleMic,
    required this.onToggleSpeaker,
    required this.onToggleVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MiniControl(
            icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: 'Mic',
            selected: micOn,
            onTap: disabled ? null : onToggleMic,
          ),
          _MiniControl(
            icon: speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label: 'Speaker',
            selected: speakerOn,
            onTap: disabled ? null : onToggleSpeaker,
          ),
          _MiniControl(
            icon: videoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: 'Video',
            selected: videoOn,
            onTap: disabled ? null : onToggleVideo,
          ),
        ],
      ),
    );
  }
}

class _MiniControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _MiniControl({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = ThemeHelper.getSurfaceColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final iconColor = ThemeHelper.getHighContrastIconColor(context);
    final text = ThemeHelper.getTextMuted(context);
    final accent = ThemeHelper.getAccentColor(context);
    final onAccent = ThemeHelper.getOnAccentColor(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: selected
                  ? accent.withAlpha((0.22 * 255).round())
                  : surface.withAlpha((0.35 * 255).round()),
              child: InkWell(
                onTap: onTap,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? accent.withAlpha((0.70 * 255).round())
                          : border.withAlpha((0.80 * 255).round()),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? onAccent : iconColor,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = Colors.white;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              color,
              color.withAlpha((0.88 * 255).round()),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha((0.35 * 255).round()),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            child: loading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onColor,
                    ),
                  )
                : Text(
                    key: const ValueKey('label'),
                    label,
                    style: TextStyle(
                      color: onColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

