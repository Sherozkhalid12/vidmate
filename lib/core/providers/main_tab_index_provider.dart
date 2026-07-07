import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom nav: 0 Reels, 1 Long Videos, 2 Story, 3 Notifications, 4 Music.
const kReelsTabIndex = 0;
const kLongVideosTabIndex = 1;
const kStoryTabIndex = 2;
const kNotificationsTabIndex = 3;
const kMusicTabIndex = 4;

final mainTabIndexProvider = StateProvider<int>((ref) => kReelsTabIndex);
