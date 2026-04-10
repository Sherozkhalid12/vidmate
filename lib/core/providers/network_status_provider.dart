import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set to true when a feed/API call fails with a connection-style [DioException].
/// Cleared on successful refresh. Do not use [connectivity_plus] alone for offline UX.
final apiOfflineSignalProvider = StateProvider<bool>((ref) => false);

/// Alias: authoritative offline signal is still [apiOfflineSignalProvider] (API failures).
final isOfflineProvider = Provider<bool>((ref) => ref.watch(apiOfflineSignalProvider));
