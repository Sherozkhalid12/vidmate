import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/media/app_media_cache.dart';
import '../../core/models/story_model.dart';
import '../../core/models/story_viewer_model.dart';
import '../../core/utils/theme_helper.dart';
import '../../services/posts/stories_service.dart';

const double _kViewerRowHeight = 72;
const double _kSheetHeaderHeight = 52;
const double _kSheetEmptyBodyHeight = 88;
const double _kSheetMaxHeightFraction = 0.55;

/// WhatsApp-style viewers sheet: grows with list size, scrolls after max height.
Future<void> showStoryViewersSheet(BuildContext context, StoryModel story) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (ctx) => _StoryViewersSheet(story: story),
  );
}

double _sheetHeightForViewerCount(
  int viewerCount,
  double screenHeight,
  double safeBottom,
) {
  const minHeight = _kSheetHeaderHeight + _kSheetEmptyBodyHeight + 12;
  final maxHeight = screenHeight * _kSheetMaxHeightFraction;
  final bodyHeight = viewerCount <= 0
      ? _kSheetEmptyBodyHeight
      : viewerCount * _kViewerRowHeight;
  final desired = _kSheetHeaderHeight + bodyHeight + safeBottom + 8;
  return desired.clamp(minHeight, maxHeight);
}

class _StoryViewersSheet extends StatefulWidget {
  final StoryModel story;

  const _StoryViewersSheet({required this.story});

  @override
  State<_StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<_StoryViewersSheet> {
  late List<StoryViewerModel> _viewers;
  late int _viewCount;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _viewers = widget.story.viewers;
    _viewCount = widget.story.viewCount > 0
        ? widget.story.viewCount
        : widget.story.viewers.length;
    unawaited(_refreshViewers());
  }

  Future<void> _refreshViewers() async {
    final storyId = widget.story.parentStoryId.isNotEmpty
        ? widget.story.parentStoryId
        : widget.story.id;
    if (storyId.isEmpty) return;

    if (mounted) setState(() => _loading = true);

    final result = await StoriesService().getStoryViewers(storyId);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success) {
        if (result.viewers.isNotEmpty) _viewers = result.viewers;
        if (result.viewCount > 0) _viewCount = result.viewCount;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = ThemeHelper.getBackgroundColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final count = _viewCount > 0 ? _viewCount : _viewers.length;
    final sheetHeight = _sheetHeightForViewerCount(
      _viewers.isEmpty ? 0 : _viewers.length,
      screenH,
      safeBottom,
    );
    final listMaxHeight = sheetHeight - _kSheetHeaderHeight - safeBottom - 8;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: sheetHeight,
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Viewed by $count',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ThemeHelper.getAccentColor(context),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: border.withValues(alpha: 0.35)),
            SizedBox(
              height: listMaxHeight,
              child: _viewers.isEmpty
                  ? Center(
                      child: Text(
                        _loading ? 'Loading views…' : 'No views yet',
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          fontSize: 15,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: safeBottom),
                      itemCount: _viewers.length,
                      itemBuilder: (context, index) {
                        return _ViewerRow(viewer: _viewers[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerRow extends StatelessWidget {
  final StoryViewerModel viewer;

  const _ViewerRow({required this.viewer});

  String _relativeTime(DateTime? viewedAt) {
    if (viewedAt == null) return '';
    final diff = DateTime.now().difference(viewedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _relativeTime(viewer.viewedAt);

    return SizedBox(
      height: _kViewerRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: ThemeHelper.getSecondaryBackgroundColor(context),
              backgroundImage: viewer.image.isNotEmpty
                  ? CachedNetworkImageProvider(
                      viewer.image,
                      cacheManager: AppMediaCache.feedMedia,
                    )
                  : null,
              child: viewer.image.isEmpty
                  ? Icon(
                      Icons.person_rounded,
                      color: ThemeHelper.getTextMuted(context),
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          viewer.name.isNotEmpty ? viewer.name : 'User',
                          style: TextStyle(
                            color: ThemeHelper.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (viewer.verified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: ThemeHelper.getAccentColor(context),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: ThemeHelper.getTextSecondary(context),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: ThemeHelper.getTextSecondary(context),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
