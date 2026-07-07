import 'low_ram_stub.dart' if (dart.library.io) 'low_ram_io.dart' as impl;

bool detectLowRamForImageCache() => impl.detectLowRamForImageCache();
