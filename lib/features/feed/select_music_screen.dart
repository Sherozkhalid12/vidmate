import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/models/music_model.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/widgets/glass_card.dart';

/// Full-screen music selection for reel creation.
/// Shows genres, search, and music tiles like Music screen with play/pause.
/// Returns selected audio id and name when user taps a tile.
class SelectMusicScreen extends StatefulWidget {
  const SelectMusicScreen({super.key});

  @override
  State<SelectMusicScreen> createState() => _SelectMusicScreenState();
}

class _SelectMusicScreenState extends State<SelectMusicScreen> {
  final List<MusicModel> _tracks = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Rock', 'Pop', 'Hip-Hop', 'Jazz', 'Electronic', 'Ambient'];
  int? _playingIndex;

  @override
  void initState() {
    super.initState();
    _tracks.addAll(MockDataService.getMockMusic());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MusicModel> get _filteredTracks {
    var filtered = _tracks;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.artist.toLowerCase().contains(q) ||
        (t.album.toLowerCase().contains(q))
      ).toList();
    }
    if (_selectedCategory != 'All') {
      filtered = filtered.where((t) =>
        t.genre?.toLowerCase() == _selectedCategory.toLowerCase()
      ).toList();
    }
    return filtered;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _togglePlay(int index) {
    setState(() {
      _playingIndex = _playingIndex == index ? null : index;
    });
  }

  void _selectTrack(MusicModel track) {
    Navigator.pop(context, {
      'id': track.id,
      'name': '${track.title} - ${track.artist}',
      'audioUrl': track.audioUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _buildCategoryChips(),
              Expanded(
                child: _filteredTracks.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: _filteredTracks.length,
                        itemBuilder: (context, index) {
                          final track = _filteredTracks[index];
                          return _buildMusicTile(track, index);
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
            icon: Icon(Icons.arrow_back_ios_new, color: ThemeHelper.getTextPrimary(context), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select Music',
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
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
          border: Border.all(color: ThemeHelper.getBorderColor(context), width: 1),
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
            hintText: 'Search songs, artists...',
            hintStyle: TextStyle(color: ThemeHelper.getTextMuted(context)),
            prefixIcon: Icon(CupertinoIcons.search, color: ThemeHelper.getAccentColor(context), size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: Icon(CupertinoIcons.clear_circled_solid, color: ThemeHelper.getTextSecondary(context), size: 20),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ThemeHelper.getAccentColor(context)
                      : ThemeHelper.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? ThemeHelper.getAccentColor(context)
                        : ThemeHelper.getBorderColor(context),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? ThemeHelper.getOnAccentColor(context)
                          : ThemeHelper.getTextSecondary(context),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
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
            _searchQuery.isEmpty ? 'No music available' : 'No results found',
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
    final isPlaying = _playingIndex == index;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(20),
      onTap: () => _selectTrack(track),
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
                          child: Icon(CupertinoIcons.music_note_2, color: ThemeHelper.getTextMuted(context)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: ThemeHelper.getSurfaceColor(context),
                          child: Icon(CupertinoIcons.music_note_2, color: ThemeHelper.getTextMuted(context)),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Icon(CupertinoIcons.music_note_2, color: ThemeHelper.getTextMuted(context)),
                      ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _togglePlay(index),
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ThemeHelper.getSurfaceColor(context).withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: ThemeHelper.getTextPrimary(context),
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
                const SizedBox(height: 6),
                Text(
                  _formatDuration(track.duration),
                  style: TextStyle(
                    color: ThemeHelper.getTextMuted(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
