import 'dart:io' show File, Platform;

/// Android: total RAM from `/proc/meminfo` (MemTotal). Other platforms: false.
bool detectLowRamForImageCache() {
  try {
    if (!Platform.isAndroid) return false;
    final mem = File('/proc/meminfo').readAsStringSync();
    for (final raw in mem.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('MemTotal:')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) return false;
      final kb = int.tryParse(parts[1]) ?? 0;
      final mb = kb ~/ 1024;
      return mb > 0 && mb < 4096;
    }
  } catch (_) {}
  return false;
}
