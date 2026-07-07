import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-[videoUrl] flags so embedded suggested switches do not share one bool across
/// URLs (autoDispose.family drops the previous URL's slot when unwatched).
final videoPlayerEmbeddedDetailsReadyProvider =
    StateProvider.autoDispose.family<bool, String>((ref, videoUrl) => false);

final videoPlayerEmbeddedSuggestedReadyProvider =
    StateProvider.autoDispose.family<bool, String>((ref, videoUrl) => false);
