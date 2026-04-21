import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/audio/music_preview_player.dart';
import '../../core/models/music_model.dart';
import '../../core/utils/preview_url_expiry.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/music/music_library_cache_service.dart';
import '../../services/music/music_service.dart';

/// Picker for story/post/reel music: Deezer playlists and track `previewUrl`.
class SelectMusicScreen extends StatefulWidget {
  const SelectMusicScreen({super.key});

  @override
  State<SelectMusicScreen> createState() => _SelectMusicScreenState();
}

class _SelectMusicScreenState extends State<SelectMusicScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MusicService _musicService = MusicService();
  late final MusicPreviewPlayer _preview;

  String _searchQuery = '';
  bool _loading = true;
  bool _loadingPlaylist = false;
  String? _error;
  List<DeezerPlaylistSummary> _playlists = const [];
  List<MusicModel> _tracks = const [];
  String? _activePlaylistId;

  int? _playingIndexInFiltered;

  @override
  void initState() {
    super.initState();
    _preview = MusicPreviewPlayer(
      onIsPlayingChanged: (playing) {
        if (!mounted) return;
        setState(() {
          if (!playing) _playingIndexInFiltered = null;
        });
      },
    );
    unawaited(_bootstrapScreen());
  }

  @override
  void dispose() {
    _searchController.dispose();
    unawaited(_preview.dispose());
    super.dispose();
  }

  Future<void> _bootstrapScreen() async {
    final cached = await MusicLibraryCacheService.instance.readBrowseCache();
    if (!mounted) return;
    if (cached != null &&
        (cached.songs.isNotEmpty || cached.playlists.isNotEmpty)) {
      setState(() {
        _playlists = cached.playlists;
        _tracks = cached.songs;
        _activePlaylistId = cached.activePlaylistId ??
            (cached.playlists.isNotEmpty ? cached.playlists.first.id : null);
        _loading = false;
        _error = null;
      });
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
    if (snap == null ||
        (snap.songs.isEmpty && snap.playlists.isEmpty)) {
      setState(() {
        _loading = false;
        if (!ok) {
          _error = 'Could not load music';
          _tracks = const [];
          _playlists = const [];
        }
      });
      return;
    }
    setState(() {
      _loading = false;
      _playlists = snap.playlists;
      _tracks = snap.songs;
      _activePlaylistId = snap.activePlaylistId ??
          (snap.playlists.isNotEmpty ? snap.playlists.first.id : null);
      _error = ok ? null : 'Could not refresh; showing saved music.';
    });
  }

  Future<void> _onSelectPlaylist(String playlistId) async {
    if (playlistId == _activePlaylistId && !_loadingPlaylist) return;
    await _preview.stop();
    if (!mounted) return;
    setState(() {
      _activePlaylistId = playlistId;
      _loadingPlaylist = true;
      _playingIndexInFiltered = null;
    });
    final result = await _musicService.fetchDeezerPlaylistSongs(
      playlistId,
      limit: 40,
    );
    if (!mounted) return;
    setState(() {
      _loadingPlaylist = false;
      if (result.success) {
        _tracks = MusicLibraryCacheService.instance.mergeSongsByPreviewExpiry(
          stored: _tracks,
          fresh: result.tracks,
        );
      } else {
        _error = result.errorMessage;
      }
    });
  }

  List<MusicModel> _filteredTracks(List<MusicModel> source) {
    if (_searchQuery.isEmpty) return source;
    final q = _searchQuery.toLowerCase();
    return source
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q) ||
              t.album.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<MusicModel?> _freshTrackIfPreviewExpired(MusicModel track) async {
    if (track.audioUrl.trim().isEmpty || !isPreviewUrlExpired(track.audioUrl)) {
      return track;
    }
    final pid = _activePlaylistId;
    if (pid == null || pid.isEmpty) return track;
    final result = await _musicService.fetchDeezerPlaylistSongs(
      pid,
      limit: 40,
    );
    if (!mounted || !result.success) return track;
    final merged = MusicLibraryCacheService.instance.mergeSongsByPreviewExpiry(
      stored: _tracks,
      fresh: result.tracks,
    );
    final idx = merged.indexWhere((t) => t.id == track.id);
    if (idx < 0) return track;
    setState(() => _tracks = merged);
    return merged[idx];
  }

  Future<void> _togglePlay(MusicModel track, int filteredIndex) async {
    final resolved = await _freshTrackIfPreviewExpired(track);
    if (!mounted) return;
    final url = (resolved ?? track).audioUrl.trim();
    if (url.isEmpty) {
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
    await _preview.toggle(url);
    if (!mounted) return;
    setState(() {
      _playingIndexInFiltered =
          _preview.isPlaying ? filteredIndex : null;
    });
  }

  Future<void> _selectTrack(MusicModel track) async {
    final resolved = await _freshTrackIfPreviewExpired(track);
    if (!mounted) return;
    final effective = resolved ?? track;
    final url = effective.audioUrl.trim();
    unawaited(_preview.stop());
    final musicName = effective.title.trim();
    final musicTitle = effective.artist.trim();
    Navigator.pop(context, {
      'id': track.id,
      'previewUrl': url,
      'musicName': musicName,
      'musicTitle': musicTitle,
      // Backward compatibility for callers still reading these keys:
      'name': musicName.isNotEmpty && musicTitle.isNotEmpty
          ? '$musicName — $musicTitle'
          : (musicName.isNotEmpty ? musicName : musicTitle),
      'audioUrl': url,
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredTracks = _filteredTracks(_tracks);

    return Scaffold(
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
              _buildPlaylistStrip(),
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
                    if (_loadingPlaylist && filteredTracks.isEmpty) {
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
                        if (_loadingPlaylist)
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
            onPressed: () => Navigator.pop(context),
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
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(
            color: ThemeHelper.getTextPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search songs, artists, albums…',
            hintStyle: TextStyle(color: ThemeHelper.getTextMuted(context)),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: ThemeHelper.getAccentColor(context),
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
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

  Widget _buildPlaylistStrip() {
    if (_playlists.isEmpty) {
      return const SizedBox(height: 8);
    }
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final p = _playlists[index];
          final selected = p.id == _activePlaylistId;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => unawaited(_onSelectPlaylist(p.id)),
              child: Container(
                width: 132,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: ThemeHelper.getSurfaceColor(context),
                  border: Border.all(
                    color: selected
                        ? ThemeHelper.getAccentColor(context)
                        : ThemeHelper.getBorderColor(context),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: p.picture.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: p.picture,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => ColoredBox(
                                  color: ThemeHelper.getSecondaryBackgroundColor(
                                      context),
                                  child: Icon(
                                    Icons.queue_music_rounded,
                                    color: ThemeHelper.getTextMuted(context),
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: ThemeHelper.getSecondaryBackgroundColor(
                                    context),
                                child: Icon(
                                  Icons.queue_music_rounded,
                                  color: ThemeHelper.getTextMuted(context),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                      child: Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ThemeHelper.getTextPrimary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
            _searchQuery.isEmpty ? 'No tracks in this playlist' : 'No results',
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
    final isPlaying = _playingIndexInFiltered == index;
    final hasPreview = track.audioUrl.trim().isNotEmpty;
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
                        ? () => unawaited(_togglePlay(track, index))
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: hasPreview
                              ? ThemeHelper.getAccentColor(context)
                                  .withValues(alpha: 0.92)
                              : ThemeHelper.getSecondaryBackgroundColor(context),
                          shape: BoxShape.circle,
                          border: hasPreview
                              ? null
                              : Border.all(
                                  color: ThemeHelper.getBorderColor(context)
                                      .withValues(alpha: 0.65),
                                  width: 1,
                                ),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: hasPreview
                              ? ThemeHelper.getOnAccentColor(context)
                              : ThemeHelper.getTextMuted(context),
                          size: 24,
                        ),
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
