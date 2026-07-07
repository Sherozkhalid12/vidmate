import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/music_model.dart';
import '../../core/providers/music_picker_preview_provider_riverpod.dart';
import '../../core/utils/preview_url_expiry.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/music/music_library_cache_service.dart';
import '../../services/music/music_service.dart';

/// Picker for story/post/reel music: Jamendo trending, search, and `previewUrl`.
class SelectMusicScreen extends ConsumerStatefulWidget {
  const SelectMusicScreen({super.key});

  @override
  ConsumerState<SelectMusicScreen> createState() => _SelectMusicScreenState();
}

class _SelectMusicScreenState extends ConsumerState<SelectMusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MusicService _musicService = MusicService();

  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _loading = true;
  bool _loadingSearch = false;
  String? _error;
  List<MusicModel> _trendingTracks = const [];
  List<MusicModel> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapScreen());
  }

  void _prefetchPreviewUrls(Iterable<MusicModel> tracks) {
    for (final track in tracks.take(10)) {
      final url = track.audioUrl.trim();
      if (url.isNotEmpty && !isPreviewUrlExpired(url)) continue;
      unawaited(_refreshTrackPreviewUrl(track));
    }
  }

  Future<void> _refreshTrackPreviewUrl(MusicModel track) async {
    final fresh = await _musicService.fetchJamendoTrack(track.id);
    if (!mounted || fresh == null) return;
    final merged = fresh.copyWith(isLiked: track.isLiked);
    final url = merged.audioUrl.trim();
    if (url.isEmpty) return;

    setState(() {
      final isSearch = _searchQuery.trim().isNotEmpty;
      if (isSearch) {
        _searchResults = _searchResults
            .map((t) => t.id == track.id ? merged : t)
            .toList();
      } else {
        _trendingTracks = _trendingTracks
            .map((t) => t.id == track.id ? merged : t)
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    unawaited(ref.read(musicPickerPreviewProvider.notifier).stop());
    super.dispose();
  }

  Future<void> _bootstrapScreen() async {
    final cached = await MusicLibraryCacheService.instance.readBrowseCache();
    if (!mounted) return;
    if (cached != null && cached.songs.isNotEmpty) {
      setState(() {
        _trendingTracks = List<MusicModel>.from(cached.songs);
        _loading = false;
        _error = null;
      });
      _prefetchPreviewUrls(_trendingTracks);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    await _refreshBrowseFromNetwork(
      showBlockingSpinner: cached == null || cached.songs.isEmpty,
    );
  }

  Future<void> _refreshBrowseFromNetwork({
    required bool showBlockingSpinner,
  }) async {
    if (showBlockingSpinner && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final ok =
        await MusicLibraryCacheService.instance.syncBrowseFromNetwork();
    if (!mounted) return;
    final snap = await MusicLibraryCacheService.instance.readBrowseCache();
    if (snap == null || snap.songs.isEmpty) {
      setState(() {
        _loading = false;
        if (!ok) {
          _error = 'Could not load music';
          _trendingTracks = const [];
        }
      });
      return;
    }
    setState(() {
      _loading = false;
      _trendingTracks = List<MusicModel>.from(snap.songs);
      _error = ok ? null : 'Could not refresh; showing saved music.';
    });
    _prefetchPreviewUrls(_trendingTracks);
  }

  List<MusicModel> get _visibleTracks {
    final q = _searchQuery.trim();
    if (q.isEmpty) return _trendingTracks;
    return _searchResults;
  }

  void _onSearchTextChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _loadingSearch = false;
        _searchResults = const [];
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        _loadingSearch = true;
        _error = null;
      });
      final result = await _musicService.fetchJamendoSearch(query: q, limit: 20);
      if (!mounted) return;
      setState(() {
        _loadingSearch = false;
        if (result.success) {
          _searchResults = result.tracks;
        } else {
          _error = result.errorMessage;
          _searchResults = const [];
        }
      });
      if (result.success) {
        _prefetchPreviewUrls(_searchResults);
      }
    });
  }

  Future<MusicModel?> _freshTrackIfPreviewExpired(MusicModel track) async {
    final url = track.audioUrl.trim();
    if (url.isNotEmpty && !isPreviewUrlExpired(url)) {
      return track;
    }
    final fresh = await _musicService.fetchJamendoTrack(track.id);
    if (!mounted || fresh == null) return track;
    final merged = fresh.copyWith(isLiked: track.isLiked);
    final isServerSearch = _searchQuery.trim().isNotEmpty;
    setState(() {
      if (isServerSearch) {
        _searchResults = _searchResults
            .map((t) => t.id == track.id ? merged : t)
            .toList();
      } else {
        _trendingTracks = _trendingTracks
            .map((t) => t.id == track.id ? merged : t)
            .toList();
      }
    });
    return merged;
  }

  Future<void> _togglePlay(MusicModel track) async {
    final cachedUrl = track.audioUrl.trim();
    final preview = ref.read(musicPickerPreviewProvider.notifier);

    if (cachedUrl.isNotEmpty && !isPreviewUrlExpired(cachedUrl)) {
      unawaited(preview.toggle(cachedUrl));
      return;
    }

    preview.markLoading(cachedUrl.isNotEmpty ? cachedUrl : track.id);

    final resolved = await _freshTrackIfPreviewExpired(track);
    if (!mounted) return;
    final url = (resolved ?? track).audioUrl.trim();
    if (url.isEmpty) {
      await preview.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No preview is available for this track.',
              style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
            ),
            backgroundColor: ThemeHelper.getSurfaceColor(context),
          ),
        );
      }
      return;
    }
    unawaited(preview.toggle(url));
  }

  Future<void> _exitScreen() async {
    await ref.read(musicPickerPreviewProvider.notifier).stop();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _selectTrack(MusicModel track) async {
    final resolved = await _freshTrackIfPreviewExpired(track);
    if (!mounted) return;
    final effective = resolved ?? track;
    final url = effective.audioUrl.trim();
    await ref.read(musicPickerPreviewProvider.notifier).stop();
    if (!mounted) return;
    final musicName = effective.title.trim();
    final musicTitle = effective.artist.trim();
    Navigator.pop(context, {
      'id': track.id,
      'previewUrl': url,
      'musicName': musicName,
      'musicTitle': musicTitle,
      'name': musicName.isNotEmpty && musicTitle.isNotEmpty
          ? '$musicName — $musicTitle'
          : (musicName.isNotEmpty ? musicName : musicTitle),
      'audioUrl': url,
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredTracks = _visibleTracks;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exitScreen());
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(),
              _buildSearchBar(),
              _buildSectionHeader(),
              if (_error != null && !_loading)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(_refreshBrowseFromNetwork(
                          showBlockingSpinner: false,
                        )),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            color: ThemeHelper.getAccentColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_loading && filteredTracks.isEmpty) {
                      return Center(
                        child: CupertinoActivityIndicator(
                          color: ThemeHelper.getAccentColor(context),
                        ),
                      );
                    }
                    if (_loadingSearch &&
                        _searchQuery.trim().isNotEmpty &&
                        filteredTracks.isEmpty) {
                      return Center(
                        child: CupertinoActivityIndicator(
                          color: ThemeHelper.getAccentColor(context),
                        ),
                      );
                    }
                    if (filteredTracks.isEmpty) {
                      return _buildEmpty();
                    }
                    return Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: filteredTracks.length,
                          itemBuilder: (context, index) {
                            final track = filteredTracks[index];
                            return KeyedSubtree(
                              key: ValueKey<String>(track.id),
                              child: _buildMusicTile(track, index),
                            );
                          },
                        ),
                        if (_loadingSearch && _searchQuery.trim().isNotEmpty)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              color: ThemeHelper.getAccentColor(context),
                              backgroundColor:
                                  ThemeHelper.getSurfaceColor(context),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: ThemeHelper.getTextPrimary(context),
              size: 22,
            ),
            onPressed: () => unawaited(_exitScreen()),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add music',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeHelper.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ThemeHelper.getBorderColor(context),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchTextChanged,
          style: TextStyle(
            color: ThemeHelper.getTextPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search songs…',
            hintStyle: TextStyle(color: ThemeHelper.getTextMuted(context)),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: ThemeHelper.getAccentColor(context),
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchDebounce?.cancel();
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _searchResults = const [];
                        _loadingSearch = false;
                      });
                    },
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: ThemeHelper.getTextSecondary(context),
                      size: 20,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    final q = _searchQuery.trim();
    final label = q.isEmpty ? 'Popular songs' : 'Search results';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ThemeHelper.getTextSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.music_note_2,
            size: 64,
            color: ThemeHelper.getTextMuted(context),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.trim().isEmpty
                ? 'No trending songs yet'
                : 'No results',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMusicTile(MusicModel track, int index) {
    final url = track.audioUrl.trim();
    final hasPreview = url.isNotEmpty;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(20),
      onTap: () => unawaited(_selectTrack(track)),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: track.coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 72,
                          height: 72,
                          color: ThemeHelper.getSurfaceColor(context),
                          child: Icon(
                            CupertinoIcons.music_note_2,
                            color: ThemeHelper.getTextMuted(context),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: ThemeHelper.getSurfaceColor(context),
                          child: Icon(
                            CupertinoIcons.music_note_2,
                            color: ThemeHelper.getTextMuted(context),
                          ),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Icon(
                          CupertinoIcons.music_note_2,
                          color: ThemeHelper.getTextMuted(context),
                        ),
                      ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: hasPreview
                        ? () => unawaited(_togglePlay(track))
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: _MusicTilePreviewButton(
                        trackId: track.id,
                        url: url,
                        hasPreview: hasPreview,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  style: TextStyle(
                    color: ThemeHelper.getTextSecondary(context),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!hasPreview) ...[
                  const SizedBox(height: 6),
                  Text(
                    'No preview available',
                    style: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Play/pause control for one row — selective Riverpod watches avoid rebuilding
/// the whole list on every progress tick.
class _MusicTilePreviewButton extends ConsumerWidget {
  final String trackId;
  final String url;
  final bool hasPreview;

  const _MusicTilePreviewButton({
    required this.trackId,
    required this.url,
    required this.hasPreview,
  });

  String get _trackKey => url.isNotEmpty ? url : trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(
      musicPickerPreviewProvider.select(
        (s) => musicPreviewActiveKey(s, _trackKey),
      ),
    );
    final isPlaying = ref.watch(
      musicPickerPreviewProvider.select(
        (s) => musicPreviewActiveKey(s, _trackKey) && s.isPlaying,
      ),
    );
    final isLoading = ref.watch(
      musicPickerPreviewProvider.select(
        (s) => musicPreviewActiveKey(s, _trackKey) && s.isLoading,
      ),
    );
    final progress = ref.watch(
      musicPickerPreviewProvider.select(
        (s) => musicPreviewActiveKey(s, _trackKey) ? s.progress : 0.0,
      ),
    );

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive && !isLoading)
            CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 2.5,
              backgroundColor: ThemeHelper.getBorderColor(
                context,
              ).withValues(alpha: 0.45),
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeHelper.getOnAccentColor(context),
              ),
            ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: hasPreview
                  ? ThemeHelper.getAccentColor(context).withValues(alpha: 0.92)
                  : ThemeHelper.getSecondaryBackgroundColor(context),
              shape: BoxShape.circle,
              border: hasPreview
                  ? null
                  : Border.all(
                      color: ThemeHelper.getBorderColor(
                        context,
                      ).withValues(alpha: 0.65),
                      width: 1,
                    ),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ThemeHelper.getOnAccentColor(context),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: hasPreview
                        ? ThemeHelper.getOnAccentColor(context)
                        : ThemeHelper.getTextMuted(context),
                    size: 22,
                  ),
          ),
        ],
      ),
    );
  }
}
