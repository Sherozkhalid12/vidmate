import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/socket/socket_service.dart';

/// Provides the single long-lived socket instance used across the app.
///
/// Important: keep this provider in a separate file to avoid circular imports
/// between feature providers (like calls) and socket orchestration.
final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

