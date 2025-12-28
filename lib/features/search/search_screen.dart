import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';
import '../profile/profile_screen.dart';

class ExploreItem {
  final String imageUrl;
  final UserModel user;
  final double aspectRatio;

  ExploreItem({
    required this.imageUrl,
    required this.user,
    required this.aspectRatio,
  });
}

/// Instagram-style Search Screen
class SearchScreen extends StatefulWidget {
  final double? bottomPadding;

  const SearchScreen({super.key, this.bottomPadding});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UserModel> _filteredUsers = [];
  List<String> _recentSearches = [
    'john_doe',
    'jane_smith',
    'design',
    'tech',
  ];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      if (_isSearching) {
        _filteredUsers = MockDataService.mockUsers
            .where((user) =>
        user.username.toLowerCase().contains(query) ||
            user.displayName.toLowerCase().contains(query))
            .toList();
      } else {
        _filteredUsers = [];
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _removeRecentSearch(String search) {
    setState(() {
      _recentSearches.remove(search);
    });
  }

  void _clearAllRecent() {
    setState(() {
      _recentSearches.clear();
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
          children: [
            // Top bar with back button and search
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: ThemeHelper.getBorderColor(context).withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // iOS-style back button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.back,
                      color: ThemeHelper.getAccentColor(context),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search bar
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: ThemeHelper.getBorderColor(context),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.search,
                            color: ThemeHelper.getTextSecondary(context),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              autofocus: true,
                              style: TextStyle(
                                color: ThemeHelper.getTextPrimary(context),
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: TextStyle(
                                  color: ThemeHelper.getTextSecondary(context),
                                  fontSize: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                  width: 0,
                                  color: Colors.transparent
                                 ),
                                ),

                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      width: 0,
                                      color: Colors.transparent                                  ),
                                ),
                                fillColor: Colors.transparent,
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      width: 0,
                                      color: Colors.transparent                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      width: 0,
                                      color: Colors.transparent                                  ),
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: _clearSearch,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: ThemeHelper.getTextMuted(context).withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: ThemeHelper.getTextPrimary(context),
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildRecentSearches(),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 80,
              color: ThemeHelper.getTextMuted(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent searches',
              style: TextStyle(
                color: ThemeHelper.getTextMuted(context),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        bottom: (widget.bottomPadding ?? 0) + 16,
      ),
      children: [
        // Recent header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 2,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getAccentColor(context),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearAllRecent,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: ThemeHelper.getAccentColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Recent searches list
        ...AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(child: widget),
          ),
          children: _recentSearches.map((search) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ThemeHelper.getBorderColor(context).withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      color: ThemeHelper.getTextSecondary(context),
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            search,
                            style: TextStyle(
                              color: ThemeHelper.getTextPrimary(context),
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 1.5,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: ThemeHelper.getAccentColor(context),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeRecentSearch(search),
                      child: Icon(
                        Icons.close,
                        color: ThemeHelper.getTextMuted(context),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 80,
              color: ThemeHelper.getTextMuted(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Text(
                  'No results found',
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  width: 120,
                  height: 2,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getAccentColor(context),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: (widget.bottomPadding ?? 0) + 16,
        top: 8,
      ),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return AnimationConfiguration.staggeredList(
          position: index,
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(user: user),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: ThemeHelper.getBorderColor(context).withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipOval(
                              child: Image.network(
                                user.avatarUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 50,
                                    height: 50,
                                    color: ThemeHelper.getSurfaceColor(context),
                                    child: Icon(
                                      Icons.person,
                                      color: ThemeHelper.getTextSecondary(context),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (user.isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: ThemeHelper.getAccentColor(context),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ThemeHelper.getBackgroundColor(context),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.username,
                                    style: TextStyle(
                                      color: ThemeHelper.getTextPrimary(context),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    width: 60,
                                    height: 1.5,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: ThemeHelper.getAccentColor(context),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.displayName,
                                style: TextStyle(
                                  color: ThemeHelper.getTextMuted(context),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}