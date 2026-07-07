import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/message_model.dart';
import '../../../../core/providers/chat_shared_media_provider.dart';
import '../../../../core/utils/theme_helper.dart';
import '../../utils/chat_message_filters.dart';

/// Instagram-style shared media tabs for chat and group profiles.
class ChatSharedMediaTabs extends ConsumerWidget {
  final ChatSharedMediaKey mediaKey;

  const ChatSharedMediaTabs({super.key, required this.mediaKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatSharedMediaProvider(mediaKey));
    final accent = ThemeHelper.getAccentColor(context);
    final muted = ThemeHelper.getTextMuted(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            labelColor: accent,
            unselectedLabelColor: muted,
            indicatorColor: accent,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: ThemeHelper.getBorderColor(context).withValues(alpha: 0.35),
            tabs: const [
              Tab(icon: Icon(CupertinoIcons.photo_on_rectangle, size: 22)),
              Tab(icon: Icon(CupertinoIcons.play_rectangle_fill, size: 22)),
              Tab(icon: Icon(CupertinoIcons.paperclip, size: 22)),
            ],
          ),
          SizedBox(
            height: 280,
            child: state.loading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : state.error != null
                    ? Center(
                        child: Text(
                          state.error!,
                          style: TextStyle(color: muted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : TabBarView(
                        children: [
                          _MediaGrid(
                            items: state.photosAndVideos,
                            emptyLabel: 'No photos or videos yet',
                          ),
                          _MediaGrid(
                            items: state.reelsAndLongVideos,
                            emptyLabel: 'No reels or long videos yet',
                            showPlayBadge: true,
                          ),
                          _LinksList(
                            items: state.linksAndFiles,
                            emptyLabel: 'No links or files yet',
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final List<MessageModel> items;
  final String emptyLabel;
  final bool showPlayBadge;

  const _MediaGrid({
    required this.items,
    required this.emptyLabel,
    this.showPlayBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyTab(label: emptyLabel);
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final url = ChatMessageFilters.thumbnailUrl(item) ?? '';
        final isVideo = item.type == MessageType.video ||
            item.effectiveAttachments.any((a) => a.isVideo);

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isNotEmpty)
                _ThumbImage(url: url)
              else
                ColoredBox(
                  color: ThemeHelper.getSurfaceColor(context),
                  child: Icon(
                    isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                    color: ThemeHelper.getTextMuted(context),
                  ),
                ),
              if (showPlayBadge || isVideo)
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ThumbImage extends StatelessWidget {
  final String url;
  const _ThumbImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (!url.startsWith('http')) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: ThemeHelper.getSurfaceColor(context),
          child: Icon(Icons.broken_image_outlined, color: ThemeHelper.getTextMuted(context)),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => ColoredBox(
        color: ThemeHelper.getSurfaceColor(context),
        child: Icon(Icons.broken_image_outlined, color: ThemeHelper.getTextMuted(context)),
      ),
    );
  }
}

class _LinksList extends StatelessWidget {
  final List<MessageModel> items;
  final String emptyLabel;

  const _LinksList({required this.items, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyTab(label: emptyLabel);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final label = ChatMessageFilters.linkLabel(item);
        final isLink = RegExp(r'https?://', caseSensitive: false).hasMatch(label);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ThemeHelper.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ThemeHelper.getBorderColor(context).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isLink ? Icons.link_rounded : Icons.insert_drive_file_outlined,
                color: ThemeHelper.getAccentColor(context),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String label;
  const _EmptyTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ThemeHelper.getTextMuted(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
