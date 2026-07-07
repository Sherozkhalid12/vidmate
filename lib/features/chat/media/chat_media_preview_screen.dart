import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/app_media_cache.dart';
import 'chat_media_image.dart';
import 'chat_media_models.dart';

/// Instagram-style full-screen media viewer.
///
/// Horizontal [PageView] swipes through every item one-by-one. Images support
/// pinch-zoom + double-tap; videos initialize lazily and only the visible page
/// ever holds a decoder. Neighboring images are precached for instant swipes.
class ChatMediaPreviewScreen extends StatefulWidget {
  final List<ChatMediaItem> items;
  final int initialIndex;

  const ChatMediaPreviewScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<ChatMediaPreviewScreen> createState() => _ChatMediaPreviewScreenState();
}

class _ChatMediaPreviewScreenState extends State<ChatMediaPreviewScreen> {
  late final PageController _controller;
  late final ValueNotifier<int> _index;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    _index = ValueNotifier<int>(widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNeighbors(widget.initialIndex));
  }

  @override
  void dispose() {
    _controller.dispose();
    _index.dispose();
    super.dispose();
  }

  void _precacheNeighbors(int center) {
    for (final i in [center - 1, center + 1]) {
      if (i < 0 || i >= widget.items.length) continue;
      final item = widget.items[i];
      if (item.isVideo || item.isLocal) continue;
      precacheImage(
        CachedNetworkImageProvider(item.url, cacheManager: AppMediaCache.chatMedia),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: ValueListenableBuilder<int>(
          valueListenable: _index,
          builder: (_, value, __) => Text(
            '${value + 1} / ${widget.items.length}',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (i) {
          _index.value = i;
          _precacheNeighbors(i);
        },
        itemBuilder: (context, i) {
          final item = widget.items[i];
          if (item.isVideo) {
            return _VideoPage(
              key: ValueKey(item.heroTag),
              item: item,
              pageIndex: i,
              activeIndex: _index,
            );
          }
          return _ImagePage(item: item);
        },
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  final ChatMediaItem item;
  const _ImagePage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: item.heroTag,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: ChatMediaImage(
            url: item.url,
            fit: BoxFit.contain,
            highQuality: true,
          ),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final ChatMediaItem item;
  final int pageIndex;
  final ValueListenable<int> activeIndex;

  const _VideoPage({
    super.key,
    required this.item,
    required this.pageIndex,
    required this.activeIndex,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    widget.activeIndex.addListener(_onActiveChanged);
    if (widget.activeIndex.value == widget.pageIndex) {
      _ensureInitialized();
    }
  }

  @override
  void dispose() {
    widget.activeIndex.removeListener(_onActiveChanged);
    _controller?.dispose();
    super.dispose();
  }

  bool get _isActive => widget.activeIndex.value == widget.pageIndex;

  void _onActiveChanged() {
    if (_isActive) {
      _ensureInitialized();
    } else {
      _controller?.pause();
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized || _initializing) {
      if (_initialized && _isActive) _controller?.play();
      return;
    }
    _initializing = true;
    final controller = widget.item.isLocal
        ? VideoPlayerController.file(File(widget.item.url))
        : VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() => _initialized = true);
      if (_isActive) controller.play();
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      _initializing = false;
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_initialized) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_initialized || c == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: widget.item.heroTag,
            child: ChatMediaImage(url: widget.item.url, fit: BoxFit.contain, highQuality: true),
          ),
          const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: Center(
        child: Hero(
          tag: widget.item.heroTag,
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(c),
                AnimatedOpacity(
                  opacity: c.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(playedColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
