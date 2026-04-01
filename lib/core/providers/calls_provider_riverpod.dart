import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/call_model.dart';
import '../../services/calls/calls_service.dart';
import '../constants/agora_constants.dart';
import 'auth_provider_riverpod.dart';
import 'socket_instance_provider_riverpod.dart';

enum CallUiStatus {
  idle,
  startingOutgoing,
  inCall,
  incoming,
  ending,
  ended,
}

class CallsState {
  final CallUiStatus status;
  final IncomingCallPayload? incomingCall;
  final CallModel? currentCall;
  final String? agoraAppId;
  final String? agoraToken;
  final int? agoraUid;
  final String? activeCallId; // used to dedupe socket events & prevent multi-call races
  final String? remoteUserId;
  final String? remoteUsername;
  final String? remoteProfilePicture;
  final bool startWithVideo;
  final String? errorMessage;

  const CallsState({
    this.status = CallUiStatus.idle,
    this.incomingCall,
    this.currentCall,
    this.agoraAppId,
    this.agoraToken,
    this.agoraUid,
    this.activeCallId,
    this.remoteUserId,
    this.remoteUsername,
    this.remoteProfilePicture,
    this.startWithVideo = false,
    this.errorMessage,
  });

  CallsState copyWith({
    CallUiStatus? status,
    IncomingCallPayload? incomingCall,
    CallModel? currentCall,
    String? agoraAppId,
    String? agoraToken,
    int? agoraUid,
    String? activeCallId,
    String? remoteUserId,
    String? remoteUsername,
    String? remoteProfilePicture,
    bool? startWithVideo,
    String? errorMessage,
    bool clearAgora = false,
    bool clearRemote = false,
  }) {
    return CallsState(
      status: status ?? this.status,
      incomingCall: incomingCall ?? this.incomingCall,
      currentCall: currentCall ?? this.currentCall,
      agoraAppId: clearAgora ? null : (agoraAppId ?? this.agoraAppId),
      agoraToken: clearAgora ? null : (agoraToken ?? this.agoraToken),
      agoraUid: clearAgora ? null : (agoraUid ?? this.agoraUid),
      activeCallId: activeCallId ?? this.activeCallId,
      remoteUserId: clearRemote ? null : (remoteUserId ?? this.remoteUserId),
      remoteUsername: clearRemote ? null : (remoteUsername ?? this.remoteUsername),
      remoteProfilePicture: clearRemote ? null : (remoteProfilePicture ?? this.remoteProfilePicture),
      startWithVideo: startWithVideo ?? this.startWithVideo,
      errorMessage: errorMessage,
    );
  }
}

class CallsNotifier extends StateNotifier<CallsState> {
  final CallsService _callsService;
  final Ref _ref;

  CallsNotifier(this._ref)
      : _callsService = CallsService(),
        super(const CallsState());

  /// Socket: incoming call event
  void onIncomingCall(IncomingCallPayload payload) {
    final me = _ref.read(currentUserProvider);
    final myId = me?.id ?? '';
    if (myId.isEmpty) return;

    // Role based: only treat as incoming if I'm the receiver.
    if (payload.receiverId != myId && payload.call.receiverId != myId) return;

    final callId = payload.call.callId;
    if (callId.isEmpty) return;

    // De-dupe: same incoming call repeated by socket / retries.
    if (state.activeCallId == callId &&
        (state.status == CallUiStatus.incoming ||
            state.status == CallUiStatus.inCall ||
            state.status == CallUiStatus.ending)) {
      return;
    }

    // If already in another active call, ignore new incoming to avoid auto-races.
    if (state.activeCallId != null &&
        state.activeCallId!.isNotEmpty &&
        state.activeCallId != callId &&
        (state.status == CallUiStatus.incoming ||
            state.status == CallUiStatus.inCall ||
            state.status == CallUiStatus.ending ||
            state.status == CallUiStatus.startingOutgoing)) {
      return;
    }

    state = state.copyWith(
      status: CallUiStatus.incoming,
      incomingCall: payload,
      currentCall: payload.call,
      // Use incoming payload Agora token if provided (receiver will use it after Accept).
      agoraAppId: (payload.appId != null && payload.appId!.trim().isNotEmpty)
          ? payload.appId
          : (state.agoraAppId ?? AgoraConstants.appId),
      agoraToken: payload.token ?? payload.call.token,
      agoraUid: payload.uid,
      remoteUserId: payload.callerId,
      remoteUsername: payload.call.caller?.username,
      remoteProfilePicture: payload.call.caller?.profilePicture,
      activeCallId: callId,
      errorMessage: null,
    );
  }

  /// Socket: call ended event
  void onCallEnded(CallEndedPayload payload) {
    final currentUser = _ref.read(currentUserProvider);
    final myId = currentUser?.id ?? '';
    if (myId.isEmpty) return;

    final isInvolved = payload.callerId == myId ||
        payload.receiverId == myId ||
        payload.call.callerId == myId ||
        payload.call.receiverId == myId;
    if (!isInvolved) return;

    state = state.copyWith(
      status: CallUiStatus.ended,
      incomingCall: null,
      currentCall: payload.call,
      clearAgora: true,
      activeCallId: payload.call.callId.isNotEmpty ? payload.call.callId : state.activeCallId,
      errorMessage: null,
    );
  }

  /// Socket: calls:accepted
  void onCallAccepted(CallAcceptedPayload payload) {
    final myId = _ref.read(currentUserProvider)?.id ?? '';
    if (myId.isEmpty) return;

    final callId = payload.call.callId;
    if (callId.isEmpty) return;

    final isInvolved =
        payload.callerId == myId ||
        payload.receiverId == myId ||
        payload.call.callerId == myId ||
        payload.call.receiverId == myId;
    if (!isInvolved) return;

    // If we have an active call and it doesn't match, ignore as stale event.
    if (state.activeCallId != null &&
        state.activeCallId!.isNotEmpty &&
        state.activeCallId != callId) {
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[Calls] calls:accepted handled myId=$myId callId=$callId '
        'token=${(payload.token ?? payload.call.token ?? "").isNotEmpty ? "present" : "missing"} '
        'prevStatus=${state.status}',
      );
    }

    final amCaller = payload.call.callerId == myId || payload.callerId == myId;
    final remote = amCaller ? payload.call.receiver : payload.call.caller;

    state = state.copyWith(
      status: CallUiStatus.inCall,
      currentCall: payload.call,
      incomingCall: state.incomingCall,
      agoraAppId: state.agoraAppId ?? AgoraConstants.appId,
      agoraToken: payload.token ?? payload.call.token ?? state.agoraToken,
      activeCallId: callId,
      remoteUserId: remote?.id.isNotEmpty == true
          ? remote!.id
          : (amCaller ? payload.call.receiverId : payload.call.callerId),
      remoteUsername: remote?.username.isNotEmpty == true ? remote!.username : state.remoteUsername,
      remoteProfilePicture: remote?.profilePicture.isNotEmpty == true
          ? remote!.profilePicture
          : state.remoteProfilePicture,
      errorMessage: null,
    );
  }

  /// Socket: calls:rejected
  void onCallRejected(CallRejectedPayload payload) {
    final myId = _ref.read(currentUserProvider)?.id ?? '';
    if (myId.isEmpty) return;

    final callId = payload.call.callId;
    if (callId.isEmpty) return;

    final isInvolved =
        payload.callerId == myId ||
        payload.receiverId == myId ||
        payload.call.callerId == myId ||
        payload.call.receiverId == myId;
    if (!isInvolved) return;

    if (state.activeCallId != null &&
        state.activeCallId!.isNotEmpty &&
        state.activeCallId != callId) {
      return;
    }

    state = state.copyWith(
      status: CallUiStatus.ended,
      incomingCall: null,
      currentCall: payload.call,
      clearAgora: true,
      activeCallId: callId,
      errorMessage: 'Call rejected',
    );
  }

  /// Start an outgoing call (optimistic).
  Future<void> startOutgoingCall({
    required String channelName,
    required String receiverId,
    int uid = 0,
    String? receiverUsername,
    String? receiverProfilePicture,
    bool startWithVideo = false,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    final callerId = currentUser?.id ?? '';
    if (callerId.isEmpty) {
      state = state.copyWith(
        status: CallUiStatus.idle,
        errorMessage: 'Not authenticated',
      );
      return;
    }
    if (receiverId.isEmpty || receiverId == callerId) {
      state = state.copyWith(
        status: CallUiStatus.idle,
        errorMessage: 'Invalid receiver',
      );
      return;
    }

    // Debounce: prevent double taps causing double POST /calls/agora/token.
    if (state.status == CallUiStatus.startingOutgoing) return;

    // Only allow one active call session at a time.
    if (state.activeCallId != null &&
        state.activeCallId!.isNotEmpty &&
        (state.status == CallUiStatus.incoming ||
            state.status == CallUiStatus.inCall ||
            state.status == CallUiStatus.ending ||
            state.status == CallUiStatus.startingOutgoing)) {
      state = state.copyWith(
        status: state.status,
        errorMessage: 'Another call is already active',
      );
      return;
    }

    // Agora channel name must be < 64 bytes. Keep it short and URL-safe.
    // Backend uses this channelName to mint the Agora token, so we must ensure validity
    // BEFORE calling `/calls/agora/token`.
    final safeChannelName = _sanitizeCallChannelName(
      proposed: channelName,
      callerId: callerId,
      receiverId: receiverId,
    );

    // Optimistic placeholder: server will provide actual callId once started.
    state = state.copyWith(
      status: CallUiStatus.startingOutgoing,
      currentCall: CallModel(
        callId: '',
        channelName: safeChannelName,
        callerId: callerId,
        receiverId: receiverId,
        status: 'starting',
        startTime: DateTime.now(),
        endTime: null,
        caller: null,
      ),
      incomingCall: null,
      activeCallId: null,
      remoteUserId: receiverId,
      remoteUsername: receiverUsername,
      remoteProfilePicture: receiverProfilePicture,
      startWithVideo: startWithVideo,
      errorMessage: null,
    );

    final result = await _callsService.startAgoraCall(
      channelName: safeChannelName,
      receiverId: receiverId,
      uid: uid,
      callerId: callerId,
    );

    if (!result.success || result.data == null) {
      state = state.copyWith(
        status: CallUiStatus.idle,
        incomingCall: null,
        clearAgora: true,
        errorMessage: result.errorMessage ?? 'Failed to start call',
      );
      return;
    }

    final callId = result.data!.callId;

    // Optimistic: join socket room immediately if socket is already connected.
    _ref.read(socketServiceProvider).callsSocket.join(callId);

    state = state.copyWith(
      status: CallUiStatus.inCall,
      currentCall: CallModel(
        callId: callId,
        channelName: result.data!.channelName,
        callerId: callerId,
        receiverId: receiverId,
        status: 'started',
        startTime: DateTime.now(),
        endTime: null,
        caller: null,
      ),
      agoraAppId: result.data!.appId,
      agoraToken: result.data!.token,
      agoraUid: result.data!.uid,
      incomingCall: null,
      activeCallId: callId,
      remoteUserId: receiverId,
      remoteUsername: receiverUsername,
      remoteProfilePicture: receiverProfilePicture,
      errorMessage: null,
    );
  }

  /// End call (optimistic).
  Future<void> endCurrentCall({String? callId}) async {
    final currentCallId = callId ?? state.currentCall?.callId ?? '';
    if (currentCallId.isEmpty) return;
    final me = _ref.read(currentUserProvider);
    final myId = me?.id ?? '';
    final call = state.currentCall ?? state.incomingCall?.call;
    if (call == null || myId.isEmpty) return;
    final involved = call.callerId == myId || call.receiverId == myId;
    if (!involved) return;
    final existingCall = state.currentCall;

    if (kDebugMode) {
      debugPrint(
        '[Calls] endCurrentCall invoked myId=$myId callId=$currentCallId role='
        '${call.callerId == myId ? "caller" : (call.receiverId == myId ? "receiver" : "unknown")} '
        'status=${state.status}',
      );
    }

    state = state.copyWith(
      status: CallUiStatus.ending,
      errorMessage: null,
    );

    // Optimistic: leave room right away.
    _ref.read(socketServiceProvider).callsSocket.leave(currentCallId);

    final result = await _callsService.endCall(currentCallId);
    if (!result.success) {
      state = state.copyWith(
        status: CallUiStatus.inCall,
        errorMessage: result.errorMessage ?? 'Failed to end call',
      );
      return;
    }

    state = state.copyWith(
      status: CallUiStatus.ended,
      errorMessage: null,
      incomingCall: null,
      clearAgora: true,
      activeCallId: currentCallId,
      currentCall: CallModel(
        callId: currentCallId,
        channelName: existingCall?.channelName ?? '',
        callerId: existingCall?.callerId ?? '',
        receiverId: existingCall?.receiverId ?? '',
        status: 'ended',
        startTime: existingCall?.startTime,
        endTime: DateTime.now(),
        caller: existingCall?.caller,
      ),
    );
  }

  /// Receiver-side: join the socket room for an incoming call.
  ///
  /// This is optimistic and does not call the REST API (Agora token handling
  /// depends on your backend design).
  void joinCurrentCallRoom() {
    final callId = state.currentCall?.callId ?? state.incomingCall?.call.callId ?? '';
    if (callId.isEmpty) return;
    final me = _ref.read(currentUserProvider);
    final myId = me?.id ?? '';
    final call = state.currentCall ?? state.incomingCall?.call;
    if (call == null || myId.isEmpty) return;
    if (call.callerId != myId && call.receiverId != myId) return;
    _ref.read(socketServiceProvider).callsSocket.join(callId);
  }

  /// Leave current socket room (optimistic).
  void leaveCurrentCallRoom() {
    final callId = state.currentCall?.callId ?? state.incomingCall?.call.callId ?? '';
    if (callId.isEmpty) return;
    final me = _ref.read(currentUserProvider);
    final myId = me?.id ?? '';
    final call = state.currentCall ?? state.incomingCall?.call;
    if (call == null || myId.isEmpty) return;
    if (call.callerId != myId && call.receiverId != myId) return;
    _ref.read(socketServiceProvider).callsSocket.leave(callId);
  }

  /// Receiver-side: accept the incoming call (optimistic).
  Future<void> acceptIncomingCall() async {
    final incoming = state.incomingCall;
    final call = state.currentCall ?? incoming?.call;
    if (call == null || call.callId.isEmpty) return;
    final me = _ref.read(currentUserProvider);
    final myId = me?.id ?? '';
    if (myId.isEmpty) return;
    // Role based: only receiver can accept.
    if (call.receiverId != myId) return;
    joinCurrentCallRoom();
    state = state.copyWith(
      status: CallUiStatus.inCall,
      incomingCall: incoming,
      currentCall: call,
      // Keep Agora credentials from incoming payload (token/appId/uid) so receiver can join.
      agoraAppId: state.agoraAppId ?? AgoraConstants.appId,
      errorMessage: null,
    );

    final result = await _callsService.acceptCall(call.callId);
    if (!result.success) {
      // If accept fails, revert UI state so the user can retry/decline.
      leaveCurrentCallRoom();
      state = state.copyWith(
        status: CallUiStatus.incoming,
        errorMessage: result.errorMessage ?? 'Failed to accept call',
      );
      return;
    }

    // If backend returned an updated call payload, sync it (token/status/etc.).
    final updatedCall = result.call;
    if (updatedCall != null) {
      state = state.copyWith(
        currentCall: updatedCall,
        agoraToken: updatedCall.token ?? state.agoraToken,
        errorMessage: null,
      );
    }
  }

  /// Receiver-side: decline the incoming call (ends it).
  Future<void> declineIncomingCall() async {
    final callId = state.incomingCall?.call.callId ?? state.currentCall?.callId ?? '';
    if (callId.isEmpty) return;
    final me = _ref.read(currentUserProvider);
    final myId = me?.id ?? '';
    final call = state.incomingCall?.call ?? state.currentCall;
    if (call == null || myId.isEmpty) return;
    // Role based: only receiver can decline.
    if (call.receiverId != myId) return;

    state = state.copyWith(
      status: CallUiStatus.ending,
      errorMessage: null,
    );

    // Receiver rejects the call (documented as PATCH /reject/:id).
    final result = await _callsService.rejectCall(callId);
    if (!result.success) {
      state = state.copyWith(
        status: CallUiStatus.incoming,
        errorMessage: result.errorMessage ?? 'Failed to reject call',
      );
      return;
    }

    state = state.copyWith(
      status: CallUiStatus.ended,
      incomingCall: null,
      currentCall: result.call ?? call,
      clearAgora: true,
      activeCallId: callId,
      errorMessage: 'Call rejected',
    );
  }

  /// Utility: clear state for UI.
  void reset() {
    state = const CallsState();
  }
}

String _sanitizeCallChannelName({
  required String proposed,
  required String callerId,
  required String receiverId,
}) {
  final trimmed = proposed.trim();
  // 64 bytes max; we stay well below to be safe with any encoding.
  if (trimmed.isNotEmpty && trimmed.length <= 48) return trimmed;

  final ts = DateTime.now().millisecondsSinceEpoch;
  final c = callerId.isNotEmpty ? callerId.substring(0, callerId.length >= 6 ? 6 : callerId.length) : 'caller';
  final r = receiverId.isNotEmpty ? receiverId.substring(0, receiverId.length >= 6 ? 6 : receiverId.length) : 'recv';
  return 'call_${c}_${r}_$ts';
}

final callsProvider =
    StateNotifierProvider<CallsNotifier, CallsState>((ref) {
  return CallsNotifier(ref);
});

