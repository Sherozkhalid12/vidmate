import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/models/user_model.dart';
import '../profile/profile_screen.dart';
import 'search_screen.dart';

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

/// Instagram-style Explore screen with staggered grid
class ExploreScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final double? bottomPadding;

  const ExploreScreen({super.key, this.onBackToHome, this.bottomPadding});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final List<ExploreItem> _exploreItems = [];

  @override
  void initState() {
    super.initState();
    _generateExploreItems();
  }

  void _generateExploreItems() {
    final items = <ExploreItem>[];
    for (int i = 0; i < 50; i++) {
      final user = MockDataService.mockUsers[i % MockDataService.mockUsers.length];
      items.add(ExploreItem(
        imageUrl: user.avatarUrl,
        user: user,
        aspectRatio: _getRandomAspectRatio(i),
      ));
    }
    _exploreItems.addAll(items);
  }

  double _getRandomAspectRatio(int index) {
    final patterns = [1.0, 1.0, 0.75, 1.0, 1.33, 1.0, 1.0];
    return patterns[index % patterns.length];
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
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
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
                    onPressed: () {
                      if (widget.onBackToHome != null) {
                        widget.onBackToHome!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.back,
                          color: ThemeHelper.getAccentColor(context),
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search bar
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchScreen(
                              bottomPadding: widget.bottomPadding,
                            ),
                          ),
                        );
                      },
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
                            Text(
                              'Search',
                              style: TextStyle(
                                color: ThemeHelper.getTextSecondary(context),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Staggered grid
            Expanded(
              child: _buildExploreGrid(),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildExploreGrid() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: (widget.bottomPadding ?? 0),
      ),
      child: MasonryGridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        itemCount: _exploreItems.length,
        itemBuilder: (context, index) {
          final item = _exploreItems[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildExploreItem(item),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExploreItem(ExploreItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(user: item.user),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: item.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: ThemeHelper.getSurfaceColor(context),
                  child: Icon(
                    Icons.person,
                    color: ThemeHelper.getTextMuted(context),
                    size: 40,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}