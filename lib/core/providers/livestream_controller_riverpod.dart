import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../models/livestream_model.dart';
import '../../services/calls/livestream_service.dart';
import '../../services/calls/agora_livestream_engine_service.dart';
import 'auth_provider_riverpod.dart';
import 'socket_instance_provider_riverpod.dart';

enum LiveStreamState {
  idle,
  loading, // starting host
  live, // host live (publishing)
  joining, // viewer joining backend
  watching, // viewer watching (subscribed)
  reconnecting,
  ended,
  error,
}

class LivestreamControllerState {
  final LiveStreamState state;
  final LivestreamModel? stream;
  final LivestreamAgoraAuth? auth;
  final int viewerCount;
  final int likeCount;
  final bool likedByMe;
  final List<Map<String, dynamic>> messages;
  final String? errorMessage;
  final LivestreamRtcSnapshot rtc;

  const LivestreamControllerState({
    this.state = LiveStreamState.idle,
    this.stream,
    this.auth,
    this.viewerCount = 0,
    this.likeCount = 0,
    this.likedByMe = false,
    this.messages = const [],
    this.errorMessage,
    this.rtc = const LivestreamRtcSnapshot(
      connection: LivestreamRtcConnection.disconnected,
      joined: false,
      localUid: null,
      remoteUids: {},
      micMuted: false,
      cameraOn: true,
      speakerOn: true,
      lastError: null,
    ),
  });

  LivestreamControllerState copyWith({
    LiveStreamState? state,
    LivestreamModel? stream,
    LivestreamAgoraAuth? auth,
    int? viewerCount,
    int? likeCount,
    bool? likedByMe,
    List<Map<String, dynamic>>? messages,
    String? errorMessage,
    LivestreamRtcSnapshot? rtc,
    bool clearError = false,
  }) {
    return LivestreamControllerState(
      state: state ?? this.state,
      stream: stream ?? this.stream,
      auth: auth ?? this.auth,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      rtc: rtc ?? this.rtc,
    );
  }
}

final livestreamControllerProvider =
    StateNotifierProvider<LivestreamController, LivestreamControllerState>((ref) {
  return LivestreamController(ref);
});

class LivestreamController extends StateNotifier<LivestreamControllerState> {
  LivestreamController(this._ref)
      : _service = LivestreamService(),
        _rtc = AgoraLivestreamEngineService(),
        super(LivestreamControllerState(rtc: LivestreamRtcSnapshot.initial())) {
    _wireRtc();
  }

  final Ref _ref;
  final LivestreamService _service;
  final AgoraLivestreamEngineService _rtc;

  StreamSubscription<LivestreamRtcSnapshot>? _rtcSub;
  StreamSubscription<void>? _tokenExpireSub;
  StreamSubscription<Map<String, dynamic>>? _socketMsgSub;
  StreamSubscription<Map<String, dynamic>>? _socketLikesSub;
  StreamSubscription<int>? _socketViewerCountSub;
  StreamSubscription<Map<String, dynamic>>? _socketEndedSub;

  bool _busy = false;
  bool _socketWired = false;

  /// Exposes the underlying Agora engine for video views only.
  /// UI should not store this in state (keeps state lightweight).
  RtcEngine? get engine => _rtc.engine;

  void _wireRtc() {
    _rtcSub?.cancel();
    _rtcSub = _rtc.snapshots.listen((snap) {
      // Map connection state to controller state when appropriate.
      final isLiveOrWatching =
          state.state == LiveStreamState.live || state.state == LiveStreamState.watching;
      final nextState = isLiveOrWatching && snap.connection == LivestreamRtcConnection.reconnecting
          ? LiveStreamState.reconnecting
          : state.state;
      state = state.copyWith(state: nextState, rtc: snap);
    });

    _tokenExpireSub?.cancel();
    _tokenExpireSub = _rtc.onTokenPrivilegeWillExpire.listen((_) async {
      await _refreshTokenIfPossible();
    });
  }

  void _wireSocket() {
    if (_socketWired) return;
    _socketWired = true;

    final socket = _ref.read(socketServiceProvider).livestreamSocket;
    final currentUserId = _ref.read(currentUserProvider)?.id ?? '';
    if (currentUserId.isNotEmpty) {
      socket.register(currentUserId);
    }
    _socketMsgSub?.cancel();
    _socketMsgSub = socket.onMessage.listen((payload) {
      final next = List<Map<String, dynamic>>.from(state.messages);
      final normalized = _normalizeSocketMessage(payload);
      final mid = normalized['messageId']?.toString() ?? '';
      if (mid.isNotEmpty && next.any((m) => m['messageId']?.toString() == mid)) {
        return;
      }
      final messageText = normalized['message']?.toString() ?? '';
      if (messageText.isEmpty) return;
      next.add(normalized);
      // Keep it lightweight: only last 50 messages in memory.
      if (next.length > 50) next.removeRange(0, next.length - 50);
      state = state.copyWith(messages: next);
    });

    _socketViewerCountSub?.cancel();
    _socketViewerCountSub = socket.onViewerCount.listen((count) {
      state = state.copyWith(viewerCount: count);
    });

    _socketLikesSub?.cancel();
    _socketLikesSub = socket.onLikesUpdated.listen((payload) {
      final countRaw = payload['likeCount'] ?? payload['likesCount'] ?? payload['count'];
      final count = countRaw is int ? countRaw : int.tryParse(countRaw?.toString() ?? '') ?? state.likeCount;

      // Keep likedByMe in sync when the server pushes like events.
      final currentUserId = _ref.read(currentUserProvider)?.id ?? '';
      final liked = payload['liked'] == true || payload['isLiked'] == true;
      final likedBy = payload['likedBy'] is Map ? Map<String, dynamic>.from(payload['likedBy'] as Map) : null;
      final likedById = likedBy?['id']?.toString() ?? '';
      final likedByMe =
          likedById.isNotEmpty && likedById == currentUserId ? liked : state.likedByMe;

      state = state.copyWith(likeCount: count, likedByMe: likedByMe);
    });

    _socketEndedSub?.cancel();
    _socketEndedSub = socket.onEnded.listen((payload) async {
      final endedStream = payload['stream'] as Map<String, dynamic>?;
      final endedStreamId = endedStream?['streamId']?.toString() ?? '';
      final currentStreamId =
          state.auth?.stream.streamId ?? state.stream?.streamId ?? '';

      if (currentStreamId.isNotEmpty &&
          endedStreamId.isNotEmpty &&
          endedStreamId != currentStreamId) {
        return;
      }

      state = state.copyWith(state: LiveStreamState.ended, clearError: true);
      if (state.auth?.role == 'subscriber' && currentStreamId.isNotEmpty) {
        _ref.read(socketServiceProvider).livestreamSocket.leave(currentStreamId);
      }
      await _rtc.leave();
    });
  }

  Future<void> _refreshTokenIfPossible() async {
    final auth = state.auth;
    if (auth == null) return;
    final streamId = auth.stream.streamId;
    if (streamId.isEmpty) return;

    // Use role from the last auth response.
    final role = auth.role;
    final res = await _service.tokenForLive(streamId: streamId, role: role);
    if (!res.success || res.data == null) return;
    state = state.copyWith(auth: res.data);
    await _rtc.renewToken(res.data!.token);
  }

  /// HOST FLOW: /live/start -> init rtc publisher -> join
  Future<bool> startHost({
    required String channelName,
    int uid = 0,
    String? title,
    String? description,
    String? thumbnail,
  }) async {
    if (_busy) return false;
    _busy = true;
    state = state.copyWith(state: LiveStreamState.loading, clearError: true);
    try {
      var res = await _service.startLive(
        channelName: channelName,
        uid: uid,
        title: title,
        description: description,
        thumbnail: thumbnail,
      );
      // If backend says an active livestream already exists, end all then retry once.
      if (!res.success &&
          (res.errorMessage ?? '').toLowerCase().contains('active livestream')) {
        await _service.endAllActive();
        res = await _service.startLive(
          channelName: channelName,
          uid: uid,
          title: title,
          description: description,
          thumbnail: thumbnail,
        );
      }
      if (!res.success || res.data == null) {
        state = state.copyWith(
          state: LiveStreamState.error,
          errorMessage: res.errorMessage ?? 'Failed to start livestream',
        );
        return false;
      }

      final auth = res.data!;
      await _rtc.init(appId: auth.appId, role: LivestreamRtcRole.publisher);
      await _rtc.join(token: auth.token, channelName: auth.channelName, uid: auth.uid);

      _wireSocket();
      _ref.read(socketServiceProvider).livestreamSocket.joinHost(
            streamId: auth.stream.streamId,
            hostId: auth.stream.hostId,
          );
      _ref.read(socketServiceProvider).livestreamSocket.hostOnline(
            streamId: auth.stream.streamId,
            hostId: auth.stream.hostId,
          );

      state = state.copyWith(
        state: LiveStreamState.live,
        auth: auth,
        stream: auth.stream,
        viewerCount: auth.stream.viewerCount,
        clearError: true,
      );

      // Initial overlay data
      await _loadInitialOverlay(auth.stream.streamId);
      return true;
    } finally {
      _busy = false;
    }
  }

  /// VIEWER FLOW: /live/join -> /live/token(subscriber) -> init rtc subscriber -> join
  Future<bool> joinAsViewer({
    required String streamId,
    int uid = 0,
  }) async {
    if (_busy) return false;
    _busy = true;
    state = state.copyWith(state: LiveStreamState.joining, clearError: true);
    try {
      final joinRes = await _service.join(streamId);
      if (!joinRes.success || joinRes.data == null) {
        state = state.copyWith(
          state: LiveStreamState.error,
          errorMessage: joinRes.errorMessage ?? 'Failed to join livestream',
        );
        return false;
      }

      final tokenRes =
          await _service.tokenForLive(streamId: streamId, uid: uid, role: 'subscriber');
      if (!tokenRes.success || tokenRes.data == null) {
        state = state.copyWith(
          state: LiveStreamState.error,
          errorMessage: tokenRes.errorMessage ?? 'Failed to get livestream token',
        );
        return false;
      }

      final auth = tokenRes.data!;
      await _rtc.init(appId: auth.appId, role: LivestreamRtcRole.subscriber);
      await _rtc.join(token: auth.token, channelName: auth.channelName, uid: auth.uid);

      _wireSocket();
      _ref.read(socketServiceProvider).livestreamSocket.join(streamId);

      state = state.copyWith(
        state: LiveStreamState.watching,
        auth: auth,
        stream: auth.stream,
        viewerCount: auth.stream.viewerCount,
      );

      await _loadInitialOverlay(streamId);
      return true;
    } finally {
      _busy = false;
    }
  }

  /// HOST FLOW (re-enter existing live): /live/token(publisher) -> init rtc publisher -> join
  /// This avoids calling `/live/start` again (backend may reject with 409).
  Future<bool> enterAsHostExisting({
    required String streamId,
    required int uid,
  }) async {
    if (_busy) return false;
    _busy = true;
    state = state.copyWith(state: LiveStreamState.loading, clearError: true);
    try {
      final tokenRes = await _service.tokenForLive(
        streamId: streamId,
        uid: uid,
        role: 'publisher',
      );
      if (!tokenRes.success || tokenRes.data == null) {
        state = state.copyWith(
          state: LiveStreamState.error,
          errorMessage: tokenRes.errorMessage ?? 'Failed to enter host live',
        );
        return false;
      }

      final auth = tokenRes.data!;
      await _rtc.init(appId: auth.appId, role: LivestreamRtcRole.publisher);
      await _rtc.join(
        token: auth.token,
        channelName: auth.channelName,
        uid: auth.uid,
      );

      _wireSocket();
      _ref.read(socketServiceProvider).livestreamSocket.joinHost(
            streamId: streamId,
            hostId: auth.stream.hostId,
          );
      _ref.read(socketServiceProvider).livestreamSocket.hostOnline(
            streamId: streamId,
            hostId: auth.stream.hostId,
          );

      state = state.copyWith(
        state: LiveStreamState.live,
        auth: auth,
        stream: auth.stream,
        viewerCount: auth.stream.viewerCount,
        clearError: true,
      );

      await _loadInitialOverlay(streamId);
      return true;
    } finally {
      _busy = false;
    }
  }

  Future<void> _loadInitialOverlay(String streamId) async {
    final msgsRes = await _service.getMessages(streamId: streamId, limit: 50);
    if (msgsRes.success && msgsRes.data != null) {
      final normalized = msgsRes.data!.map(_normalizeSocketMessage).toList();
      state = state.copyWith(messages: normalized);
    }
    final likesRes = await _service.getLikes(streamId: streamId);
    if (likesRes.success && likesRes.data != null) {
      final map = likesRes.data!;
      final countRaw = map['likeCount'] ?? map['likesCount'] ?? map['count'] ?? map['totalLikes'];
      final count = countRaw is int ? countRaw : int.tryParse(countRaw?.toString() ?? '') ?? state.likeCount;
      final liked = map['liked'] == true || map['isLiked'] == true || map['likedByMe'] == true;
      state = state.copyWith(likeCount: count, likedByMe: liked);
    }
  }

  Future<void> sendChatMessage(String message) async {
    final streamId = state.auth?.stream.streamId ?? state.stream?.streamId ?? '';
    if (streamId.isEmpty) return;
    final res = await _service.sendMessage(streamId: streamId, message: message);
    if (!res.success) {
      state = state.copyWith(errorMessage: res.errorMessage ?? 'Failed to send message');
    }
  }

  Future<void> toggleLike() async {
    final streamId = state.auth?.stream.streamId ?? state.stream?.streamId ?? '';
    if (streamId.isEmpty) return;
    final res = await _service.toggleLike(streamId: streamId);
    if (!res.success || res.data == null) {
      state = state.copyWith(errorMessage: res.errorMessage ?? 'Failed to like');
      return;
    }
    final map = res.data!;
    final liked = map['liked'] == true || map['isLiked'] == true || map['likedByMe'] == true;
    final countRaw = map['likeCount'] ?? map['likesCount'] ?? map['count'] ?? map['totalLikes'];
    final count = countRaw is int ? countRaw : int.tryParse(countRaw?.toString() ?? '') ?? state.likeCount;
    state = state.copyWith(likedByMe: liked, likeCount: count);
  }

  Future<void> leave() async {
    final auth = state.auth;
    final streamId = auth?.stream.streamId ?? state.stream?.streamId ?? '';
    if (streamId.isNotEmpty) {
      // Best effort backend leave (viewer).
      _ref.read(socketServiceProvider).livestreamSocket.leave(streamId);
      await _service.leave(streamId);
    }
    await _rtc.leave();
    state = LivestreamControllerState(rtc: LivestreamRtcSnapshot.initial());
  }

  Future<void> endHost() async {
    final auth = state.auth;
    final streamId = auth?.stream.streamId ?? '';
    if (streamId.isEmpty) return;
    state = state.copyWith(state: LiveStreamState.ended, clearError: true);
    final hostId = auth?.stream.hostId ?? '';
    if (hostId.isNotEmpty) {
      _ref.read(socketServiceProvider).livestreamSocket.leaveHost(
            streamId: streamId,
            hostId: hostId,
          );
      _ref.read(socketServiceProvider).livestreamSocket.hostOffline(
            streamId: streamId,
            hostId: hostId,
          );
    }
    await _service.end(streamId);
    await _rtc.leave();
  }

  Future<void> toggleMic() async => _rtc.setMicMuted(!state.rtc.micMuted);
  Future<void> toggleCamera() async => _rtc.setCameraOn(!state.rtc.cameraOn);
  Future<void> toggleSpeaker() async => _rtc.setSpeakerOn(!state.rtc.speakerOn);

  Future<void> switchCamera() async {
    await _rtc.engine?.switchCamera();
  }

  /// Normalizes both HTTP and socket livestream message shapes into the keys
  /// the UI expects:
  /// - `message`: string
  /// - `user`: map containing at least `username` / `name`
  Map<String, dynamic> _normalizeSocketMessage(dynamic payload) {
    if (payload is! Map) return const {};
    final raw = Map<String, dynamic>.from(payload);

    // Socket wrapper shape: { streamId: ..., message: LiveMessageObject }
    final nestedMessage = raw['message'] is Map
        ? Map<String, dynamic>.from(raw['message'] as Map)
        : null;
    final msg = nestedMessage ?? raw;

    final streamId = raw['streamId']?.toString() ?? msg['streamId']?.toString();
    final text = (msg['message'] ?? msg['text'] ?? msg['content'] ?? '').toString();

    final sender = msg['sender'] is Map
        ? Map<String, dynamic>.from(msg['sender'] as Map)
        : null;
    final userFromPayload = msg['user'] is Map
        ? Map<String, dynamic>.from(msg['user'] as Map)
        : null;

    final user = sender ??
        userFromPayload ??
        <String, dynamic>{
          'id': msg['senderId']?.toString() ?? '',
          'username': msg['username']?.toString() ?? '',
          'name': msg['name']?.toString() ?? '',
          'profilePicture': msg['profilePicture']?.toString() ?? '',
        };

    return {
      'messageId': msg['messageId']?.toString() ?? msg['id']?.toString(),
      'streamId': streamId,
      'message': text,
      'createdAt': msg['createdAt'],
      'user': user,
    };
  }

  @override
  void dispose() {
    _rtcSub?.cancel();
    _tokenExpireSub?.cancel();
    _socketMsgSub?.cancel();
    _socketLikesSub?.cancel();
    _socketViewerCountSub?.cancel();
    _socketEndedSub?.cancel();
    // Dispose engine in background to keep UI responsive.
    Future.microtask(() => _rtc.dispose());
    super.dispose();
  }
}

