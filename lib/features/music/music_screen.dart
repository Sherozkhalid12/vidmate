import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:ui';
import '../../core/utils/theme_helper.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/models/music_model.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/widgets/glass_card.dart';
import 'music_player_screen.dart';

/// Beautiful modern music screen with theme awareness
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> with TickerProviderStateMixin {
  final List<MusicModel> _tracks = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Rock', 'Pop', 'Hip-Hop', 'Jazz', 'Electronic'];

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _loadTracks() {
    setState(() {
      _tracks.addAll(MockDataService.getMockMusic());
    });
  }

  List<MusicModel> get _filteredTracks {
    var filtered = _tracks;
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((track) {
        return track.title.toLowerCase().contains(query) ||
            track.artist.toLowerCase().contains(query) ||
            track.album.toLowerCase().contains(query);
      }).toList();
    }
    
    if (_selectedCategory != 'All') {
      filtered = filtered.where((track) => 
        track.genre?.toLowerCase() == _selectedCategory.toLowerCase()
      ).toList();
    }
    
    return filtered;
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (_showSearch) {
        _searchAnimationController.forward();
      } else {
        _searchAnimationController.reverse();
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // Enhanced App Bar
              SliverToBoxAdapter(
                child: _buildAppBar(),
              ),
              
              // Animated Search Bar
              SliverToBoxAdapter(
                child: SizeTransition(
                  sizeFactor: _searchAnimation,
                  child: _buildSearchBar(),
                ),
              ),

              // Category Chips
              SliverToBoxAdapter(
                child: _buildCategoryChips(),
              ),

              // Stats Bar
              SliverToBoxAdapter(
                child: _buildStatsBar(),
              ),

              // Content
              _buildMusicListSliver(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Music',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_tracks.length} tracks available',
                style: TextStyle(
                  color: ThemeHelper.getTextSecondary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildHeaderButton(
            icon: CupertinoIcons.search,
            onTap: _toggleSearch,
            isActive: _showSearch,
          ),
          const SizedBox(width: 8),
          _buildHeaderButton(
            icon: CupertinoIcons.line_horizontal_3_decrease,
            onTap: () {
              // Filter options
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: isActive
              ? ThemeHelper.getAccentColor(context).withOpacity(0.2)
              : ThemeHelper.getSurfaceColor(context).withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? ThemeHelper.getAccentColor(context).withOpacity(0.4)
                : ThemeHelper.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive
              ? ThemeHelper.getAccentColor(context)
              : ThemeHelper.getTextPrimary(context),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeHelper.getSurfaceColor(context).withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ThemeHelper.getBorderColor(context),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: ThemeHelper.getAccentColor(context).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums...',
                hintStyle: TextStyle(
                  color: ThemeHelper.getTextMuted(context),
                ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              ThemeHelper.getAccentColor(context),
                              ThemeHelper.getAccentColor(context).withOpacity(0.8),
                            ],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : ThemeHelper.getSurfaceColor(context).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? ThemeHelper.getAccentColor(context)
                          : ThemeHelper.getBorderColor(context),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeHelper.getAccentColor(context)
                                  .withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    category,
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

  Widget _buildStatsBar() {
    final totalDuration = _filteredTracks.fold<Duration>(
      Duration.zero,
      (prev, track) => prev + track.duration,
    );
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeHelper.getAccentColor(context).withOpacity(0.1),
            ThemeHelper.getAccentColor(context).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ThemeHelper.getAccentColor(context).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: CupertinoIcons.music_note_2,
            label: 'Tracks',
            value: '${_filteredTracks.length}',
          ),
          Container(
            width: 1,
            height: 30,
            color: ThemeHelper.getBorderColor(context),
          ),
          _buildStatItem(
            icon: CupertinoIcons.time,
            label: 'Duration',
            value: _formatDuration(totalDuration),
          ),
          Container(
            width: 1,
            height: 30,
            color: ThemeHelper.getBorderColor(context),
          ),
          _buildStatItem(
            icon: CupertinoIcons.heart_fill,
            label: 'Liked',
            value: '${_tracks.where((t) => t.isLiked).length}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: ThemeHelper.getAccentColor(context),
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: ThemeHelper.getTextPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: ThemeHelper.getTextSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMusicListSliver() {
    if (_filteredTracks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: ThemeHelper.getSurfaceColor(context).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.music_note_2,
                  size: 50,
                  color: ThemeHelper.getTextMuted(context),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isEmpty ? 'No music available' : 'No results found',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isEmpty
                    ? 'Add some tracks to get started'
                    : 'Try searching for something else',
                style: TextStyle(
                  color: ThemeHelper.getTextMuted(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      sliver: AnimationLimiter(
        child: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = _filteredTracks[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 400),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildEnhancedTrackCard(track, index),
                  ),
                ),
              );
            },
            childCount: _filteredTracks.length,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedTrackCard(MusicModel track, int index) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MusicPlayerScreen(
              track: track,
              tracks: _filteredTracks,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Row(
                children: [
                  // Enhanced Album Cover with Gradient Overlay
                  Stack(
                    children: [
                      Hero(
                        tag: 'track_${track.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: track.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: track.coverUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: ThemeHelper.getSurfaceColor(context),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: CupertinoActivityIndicator(
                                        color: ThemeHelper.getTextSecondary(context),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: ThemeHelper.getSurfaceColor(context),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.music_note_2,
                                      color: ThemeHelper.getTextSecondary(context),
                                      size: 32,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: ThemeHelper.getSurfaceColor(context),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.music_note_2,
                                    color: ThemeHelper.getTextSecondary(context),
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.transparent,
                                ThemeHelper.getAccentColor(context)
                                    .withOpacity(0.15),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Play indicator on hover/active
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: ThemeHelper.getSurfaceColor(context).withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.play_fill,
                                color: ThemeHelper.getTextPrimary(context),
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  
                  // Track Info
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
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          track.artist,
                          style: TextStyle(
                            color: ThemeHelper.getTextSecondary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeHelper.getAccentColor(context)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.play_circle_fill,
                                    size: 12,
                                    color: ThemeHelper.getAccentColor(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatCount(track.plays),
                                    style: TextStyle(
                                      color: ThemeHelper.getAccentColor(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              CupertinoIcons.time,
                              size: 12,
                              color: ThemeHelper.getTextMuted(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(track.duration),
                              style: TextStyle(
                                color: ThemeHelper.getTextMuted(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Like Button with Animation
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        final trackIndex = _tracks.indexWhere((t) => t.id == track.id);
                        if (trackIndex != -1) {
                          _tracks[trackIndex] = track.copyWith(
                            isLiked: !track.isLiked,
                            likes: track.isLiked ? track.likes - 1 : track.likes + 1,
                          );
                        }
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: track.isLiked
                            ? Colors.red.withOpacity(0.15)
                            : ThemeHelper.getSurfaceColor(context).withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: track.isLiked
                              ? Colors.red.withOpacity(0.3)
                              : ThemeHelper.getBorderColor(context),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        track.isLiked
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        color: track.isLiked
                            ? Colors.red
                            : ThemeHelper.getTextSecondary(context),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
