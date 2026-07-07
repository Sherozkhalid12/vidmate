import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/media/app_media_cache.dart';
import '../../core/widgets/create_content_sheet.dart';
import '../search/explore_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';

/// App bar for the Reels tab — white text/icons over full-screen media.
class ReelsAppBar extends ConsumerWidget {
  const ReelsAppBar({super.key});

  static const Color _barForeground = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(top: 24.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Text(
              'VidConnect',
              style: TextStyle(
                color: _barForeground,
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatListScreen(),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.only(left: 10.w, right: 8.w),
                padding: EdgeInsets.all(6.w),
                child: Transform.rotate(
                  angle: -0.785398,
                  child: Icon(
                    Icons.send,
                    color: _barForeground,
                    size: 24.r,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExploreScreen(),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 10.w),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1.w,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search,
                        size: 18.r,
                        color: _barForeground.withValues(alpha: 0.85),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          'Search',
                          style: TextStyle(
                            color: _barForeground.withValues(alpha: 0.85),
                            fontSize: 14.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => showCreateContentSheet(context),
              child: Container(
                padding: EdgeInsets.all(6.w),
                child: Icon(
                  CupertinoIcons.plus,
                  color: _barForeground,
                  size: 26.r,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: Consumer(
                builder: (context, ref, _) {
                  final currentUser = ref.watch(currentUserProvider);
                  final avatarUrl = currentUser?.avatarUrl ?? '';
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  final avatarPx = (32.w * dpr).round().clamp(1, 512);
                  return ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 32.w,
                            height: 32.w,
                            fit: BoxFit.cover,
                            memCacheWidth: avatarPx,
                            memCacheHeight: avatarPx,
                            cacheManager: AppMediaCache.feedMedia,
                            placeholder: (context, url) => Container(
                              width: 32.w,
                              height: 32.w,
                              color: Colors.white24,
                              child: Icon(
                                Icons.person,
                                size: 18.r,
                                color: _barForeground,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 32.w,
                              height: 32.w,
                              color: Colors.white24,
                              child: Icon(
                                Icons.person,
                                size: 18.r,
                                color: _barForeground,
                              ),
                            ),
                          )
                        : Container(
                            width: 32.w,
                            height: 32.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 18.r,
                              color: _barForeground,
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
