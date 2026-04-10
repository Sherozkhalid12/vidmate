import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom nav / PageView index: 0 Home, 1 Reels, 2 Story, 3 Long Videos, 4 Music.
final mainTabIndexProvider = StateProvider<int>((ref) => 0);
