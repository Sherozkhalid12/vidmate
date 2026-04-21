import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/livestream_model.dart';
import '../../services/calls/livestream_service.dart';
import 'socket_instance_provider_riverpod.dart';

/// Active livestreams for the Stories tab: seeded from the API, then kept in sync
/// with `livestreams:started` / `livestreams:ended` from [SocketService.livestreamSocket].
final activeLivestreamsProvider = AutoDisposeAsyncNotifierProvider<
    ActiveLivestreamsNotifier, List<LivestreamModel>>(
  ActiveLivestreamsNotifier.new,
);

class ActiveLivestreamsNotifier
    extends AutoDisposeAsyncNotifier<List<LivestreamModel>> {
  StreamSubscription<Map<String, dynamic>>? _startedSub;
  StreamSubscription<Map<String, dynamic>>? _endedSub;

  /// Streams received over the socket while the initial HTTP request is in flight.
  final List<LivestreamModel> _pendingDuringLoad = [];

  @override
  Future<List<LivestreamModel>> build() async {
    final socket = ref.read(socketServiceProvider);
    _startedSub?.cancel();
    _endedSub?.cancel();
    _startedSub = socket.livestreamSocket.onStarted.listen(_onSocketStarted);
    _endedSub = socket.livestreamSocket.onEnded.listen(_onSocketEnded);
    ref.onDispose(() {
      _startedSub?.cancel();
      _endedSub?.cancel();
      _startedSub = null;
      _endedSub = null;
    });

    final res = await LivestreamService().getActive(limit: 20);
    var list = <LivestreamModel>[];
    if (res.success && res.data != null) {
      list = List.of(res.data!);
    }
    for (final extra in _pendingDuringLoad) {
      if (!list.any((e) => e.streamId == extra.streamId)) {
        list = [extra, ...list];
      }
    }
    _pendingDuringLoad.clear();
    return list;
  }

  void _onSocketStarted(Map<String, dynamic> map) {
    final stream = _tryParseStream(map);
    if (stream == null || stream.streamId.isEmpty) return;

    final cur = state.valueOrNull;
    if (cur == null) {
      if (!_pendingDuringLoad.any((e) => e.streamId == stream.streamId)) {
        _pendingDuringLoad.add(stream);
      }
      return;
    }
    if (cur.any((e) => e.streamId == stream.streamId)) return;
    state = AsyncData([stream, ...cur]);
  }

  void _onSocketEnded(Map<String, dynamic> map) {
    final id = _extractStreamId(map);
    if (id.isEmpty) return;

    final cur = state.valueOrNull;
    if (cur == null) {
      _pendingDuringLoad.removeWhere((e) => e.streamId == id);
      return;
    }
    final next = cur.where((e) => e.streamId != id).toList();
    if (next.length != cur.length) {
      state = AsyncData(next);
    }
  }

  static LivestreamModel? _tryParseStream(Map<String, dynamic> map) {
    try {
      dynamic nested = map['stream'] ?? map['livestream'] ?? map['payload'];
      if (nested is Map) {
        final m = Map<String, dynamic>.from(nested);
        if (m['streamId'] != null ||
            m['_id'] != null ||
            m['channelName'] != null) {
          return LivestreamModel.fromJson(m);
        }
      }
      if (map['streamId'] != null ||
          map['_id'] != null ||
          map['channelName'] != null) {
        return LivestreamModel.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  static String _extractStreamId(Map<String, dynamic> map) {
    final direct =
        map['streamId']?.toString() ?? map['_id']?.toString() ?? '';
    if (direct.isNotEmpty) return direct;
    final nested = map['stream'];
    if (nested is Map) {
      final m = Map<String, dynamic>.from(nested);
      return m['streamId']?.toString() ?? m['_id']?.toString() ?? '';
    }
    return '';
  }

  /// Refetch from API (e.g. pull-to-refresh). Socket listeners stay attached for [build]'s lifetime.
  Future<void> refreshFromNetwork() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final res = await LivestreamService().getActive(limit: 20);
      if (!res.success || res.data == null) return const <LivestreamModel>[];
      return res.data!;
    });
  }
}
