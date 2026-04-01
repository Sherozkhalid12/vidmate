import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/livestream_model.dart';
import '../../services/calls/livestream_service.dart';

/// Active livestreams list for "stories row" / discovery.
final activeLivestreamsProvider =
    FutureProvider.autoDispose<List<LivestreamModel>>((ref) async {
  final service = LivestreamService();
  final res = await service.getActive(limit: 20);
  if (!res.success || res.data == null) return const [];
  return res.data!;
});

