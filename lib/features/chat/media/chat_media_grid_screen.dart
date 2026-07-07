import 'package:flutter/material.dart';

import '../../../core/utils/theme_helper.dart';
import '../../../core/widgets/ios_back_button.dart';
import 'chat_media_image.dart';
import 'chat_media_models.dart';
import 'chat_media_viewer.dart';

/// Grid of every media item in a collage / conversation run.
/// Tapping a cell opens the swipeable full-screen viewer at that index.
class ChatMediaGridScreen extends StatelessWidget {
  final List<ChatMediaItem> items;
  final String title;

  const ChatMediaGridScreen({
    super.key,
    required this.items,
    this.title = 'Media',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        elevation: 0,
        leading: const IosBackButton(),
        title: Text(
          title,
          style: TextStyle(
            color: ThemeHelper.getTextPrimary(context),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(3),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          childAspectRatio: 1,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => openChatMediaViewer(context, items, initialIndex: i),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: item.heroTag,
                  child: ChatMediaImage(url: item.url, targetWidth: 160),
                ),
                if (item.isVideo)
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
