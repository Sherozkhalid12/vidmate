import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'stories_viewer_screen.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/providers/stories_provider_riverpod.dart';
import '../../core/providers/auth_provider_riverpod.dart';
import '../../core/providers/active_livestreams_provider_riverpod.dart';
import '../../core/providers/livestream_controller_riverpod.dart';
import '../../core/models/story_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/livestream_model.dart';
import '../feed/create_content_screen.dart';
import '../live/live_join_overlay_screen.dart';
import '../live/live_stream_studio_screen.dart';
import '../live/live_stream_watch_screen.dart';
import 'current_user_story_live_viewer_screen.dart';

/// Story Page - Grid layout like WhatsApp Status (data from API via Riverpod)
class StoryPage extends ConsumerStatefulWidget {
  final double bottomPadding;

  const StoryPage({super.key, required this.bottomPadding});

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage> {

  void _openStoryViewer(
    int userIndex,
    int storyIndex,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoriesViewerScreen(
          initialUserIndex: userIndex,
          initialStoryIndex: storyIndex,
          users: users,
          userStoriesMap: userStoriesMap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storiesState = ref.watch(storiesProvider);
    final users = storiesState.users;
    final userStoriesMap = storiesState.userStoriesMap;
    final isLoading = storiesState.isLoading;
    final error = storiesState.error;
    final currentUser = ref.watch(authProvider).currentUser;
    final liveAsync = ref.watch(activeLivestreamsProvider);
    final liveCtrlState = ref.watch(livestreamControllerProvider);

    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Stories',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Stories layout: "Your story" at top center, then 2 columns below
            Expanded(
              child: isLoading && users.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ThemeHelper.getAccentColor(context),
                      ),
                    )
                  : error != null && users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                error,
                                style: TextStyle(
                                  color: ThemeHelper.getTextPrimary(context),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    ref.read(storiesProvider.notifier).refresh(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                  : RefreshIndicator(
                          onRefresh: () =>
                              ref.read(storiesProvider.notifier).refresh(),
                          color: ThemeHelper.getAccentColor(context),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                _buildStoriesRow(
                                  currentUser,
                                  users,
                                  userStoriesMap,
                                  liveAsync,
                                ),
                                const SizedBox(height: 12),
                                _buildLivesList(liveAsync),
                                if (users.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 18),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.auto_stories_outlined,
                                          size: 48,
                                          color: ThemeHelper.getTextSecondary(context),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No stories or live streams yet',
                                          style: TextStyle(
                                            color: ThemeHelper.getTextPrimary(context),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    AsyncValue<List<LivestreamModel>> liveAsync,
    {required LivestreamControllerState liveCtrlState}
  ) {
    return liveAsync.when(
      loading: () => _buildTopRowData(
        currentUser,
        users,
        userStoriesMap,
        const [],
        liveCtrlState: liveCtrlState,
      ),
      error: (_, __) => _buildTopRowData(
        currentUser,
        users,
        userStoriesMap,
        const [],
        liveCtrlState: liveCtrlState,
      ),
      data: (streams) => _buildTopRowData(
        currentUser,
        users,
        userStoriesMap,
        streams,
        liveCtrlState: liveCtrlState,
      ),
    );
  }

  Widget _buildTopRowData(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    List<LivestreamModel> streams,
    {required LivestreamControllerState liveCtrlState}
  ) {
    final effectiveCurrentUser = currentUser ?? (users.isNotEmpty ? users.first : null);
    final myId = effectiveCurrentUser?.id ?? '';
    final myStories =
        myId.isNotEmpty ? (userStoriesMap[myId] ?? []) : const <StoryModel>[];
    if (effectiveCurrentUser == null) return const SizedBox.shrink();
    return SizedBox(
      height: 150,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _buildCurrentUserStoriesLivesTile(
          currentUser: effectiveCurrentUser,
          stories: myStories,
          lives: const [],
        ),
      ),
    );
  }

  Widget _buildCurrentUserStoriesLivesTile({
    required UserModel currentUser,
    required List<StoryModel> stories,
    required List<LivestreamModel> lives,
  }) {
    final hasStories = stories.isNotEmpty;
    final hasLives = lives.isNotEmpty;
    final showPlus = true;

    final accent = ThemeHelper.getAccentColor(context);
    final bg = ThemeHelper.getBackgroundColor(context);

    final ringGradient = hasLives
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFEF4444), const Color(0xFFF97316), accent],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent,
              accent.withAlpha((0.6 * 255).round()),
            ],
          );

    final innerImage = hasStories && stories.first.mediaUrl.isNotEmpty
        ? CachedNetworkImageProvider(stories.first.mediaUrl)
        : (currentUser.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(currentUser.avatarUrl) : null);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CurrentUserStoryLiveViewerScreen(
              currentUser: currentUser,
              stories: stories,
              lives: lives,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ringGradient,
              boxShadow: [
                BoxShadow(
                  color: accent.withAlpha((0.26 * 255).round()),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    child: innerImage != null
                        ? Image(
                            image: innerImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: ThemeHelper.getSurfaceColor(context),
                              child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context)),
                            ),
                          )
                        : Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(Icons.person, color: ThemeHelper.getTextSecondary(context)),
                          ),
                  ),
                  if (showPlus)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(999)),
                        onTap: () async {
                          await _showCurrentUserAddSheet();
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ThemeHelper.getAccentColor(context),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ThemeHelper.getBackgroundColor(context),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            color: ThemeHelper.getOnAccentColor(context),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              'Your story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New horizontal stories row (Instagram-style)
  Widget _buildStoriesRow(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    AsyncValue<List<LivestreamModel>> liveAsync,
  ) {
    final accent = ThemeHelper.getAccentColor(context);
    final ring = LinearGradient(
      colors: [accent, accent.withOpacity(0.6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final streams = liveAsync.value ?? const <LivestreamModel>[];

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 8, right: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final cu = currentUser;
            return _storyBubble(
              name: 'Your story',
              imageUrl: cu?.avatarUrl ?? '',
              showPlus: true,
              ring: ring,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateContentScreen(initialType: ContentType.story),
                ),
              ),
            );
          }
          final user = users[index - 1];
          final stories = userStoriesMap[user.id] ?? const <StoryModel>[];
          if (stories.isEmpty) return const SizedBox.shrink();
          final isLive = streams.any((s) => s.hostId == user.id);
          return _storyBubble(
            name: user.username,
            imageUrl: user.avatarUrl,
            ring: isLive
                ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)])
                : ring,
            badge: isLive ? 'LIVE' : null,
            onTap: () => _openStoryViewer(
              users.indexOf(user),
              0,
              users,
              userStoriesMap,
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: users.length + 1,
      ),
    );
  }

  Widget _storyBubble({
    required String name,
    required String imageUrl,
    required Gradient ring,
    VoidCallback? onTap,
    bool showPlus = false,
    String? badge,
  }) {
    final bg = ThemeHelper.getBackgroundColor(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: ring),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                      : Icon(Icons.person, size: 36, color: ThemeHelper.getTextSecondary(context)),
                ),
              ),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              if (showPlus)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ThemeHelper.getAccentColor(context),
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLivesList(
    AsyncValue<List<LivestreamModel>> liveAsync,
  ) {
    return liveAsync.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (streams) {
        if (streams.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live now',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${streams.length}',
                    style: TextStyle(
                      color: ThemeHelper.getTextSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ...streams.map((s) => _liveCard(s)).toList(),
          ],
        );
      },
    );
  }

  Widget _liveCard(LivestreamModel stream) {
    final host = stream.host;
    final image = (stream.thumbnail?.isNotEmpty == true)
        ? stream.thumbnail!
        : (host?.profilePicture ?? '');
    final title = stream.title?.isNotEmpty == true ? stream.title! : stream.channelName;
    final subtitle = stream.description?.isNotEmpty == true
        ? stream.description!
        : 'Hosted by ${host?.username ?? 'creator'}';
    return GestureDetector(
      onTap: () async {
        final ok = await ref.read(livestreamControllerProvider.notifier).joinAsViewer(
              streamId: stream.streamId,
            );
        if (!mounted) return;
        if (ok) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveStreamWatchScreen(streamId: stream.streamId),
            ),
          );
        } else {
          final err = ref.read(livestreamControllerProvider).errorMessage ??
              'Livestream is no longer active.';
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Stream unavailable'),
              content: Text(err),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: ThemeHelper.getSurfaceColor(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
              )
            else
              Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: Icon(Icons.person, size: 56, color: ThemeHelper.getTextSecondary(context)),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_tethering, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '${stream.viewerCount} watching',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCurrentUserAddSheet() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = ThemeHelper.getBackgroundColor(ctx);
        final surfaceColor = ThemeHelper.getSurfaceColor(ctx);
        final borderColor = ThemeHelper.getBorderColor(ctx);
        final textPrimary = ThemeHelper.getTextPrimary(ctx);
        final textSecondary = ThemeHelper.getTextSecondary(ctx);
        final accent = ThemeHelper.getAccentColor(ctx);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor.withAlpha(isDark ? 120 : 80), width: 1),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.auto_stories_outlined, color: accent),
                    title: Text('Add Story', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateContentScreen(initialType: ContentType.story),
                        ),
                      );
                    },
                  ),
                  Divider(color: ThemeHelper.getBorderColor(ctx)),
                  ListTile(
                    leading: Icon(Icons.live_tv_rounded, color: accent),
                    title: Text('Go Live', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LiveStreamStudioScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoryBubble(
    UserModel user,
    List<StoryModel> stories,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final firstStory = stories.first;
    return GestureDetector(
      onTap: () {
        final userIndex = users.indexWhere((u) => u.id == user.id);
        if (userIndex >= 0) _openStoryViewer(userIndex, 0, users, userStoriesMap);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeHelper.getAccentColor(context),
                  ThemeHelper.getAccentColor(context).withAlpha((0.6 * 255).round()),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getAccentColor(context).withAlpha((0.24 * 255).round()),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeHelper.getBackgroundColor(context),
              ),
              child: CircleAvatar(
                backgroundImage: firstStory.mediaUrl.isNotEmpty
                    ? CachedNetworkImageProvider(firstStory.mediaUrl)
                    : (user.avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.avatarUrl)
                        : null),
                backgroundColor: ThemeHelper.getSurfaceColor(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              user.displayName,
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourStoryCard(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final user = currentUser ??
        (users.isNotEmpty ? users.first : null);
    if (user == null) {
      return const SizedBox.shrink();
    }
    final currentUserStories = userStoriesMap[user.id] ?? [];
    final hasStories = currentUserStories.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (hasStories) {
          _showYourStoryOptions(user, users, userStoriesMap);
        } else {
          // No story - navigate to create content screen with stories tab
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateContentScreen(
                initialType: ContentType.story,
              ),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smaller circular story widget
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeHelper.getAccentColor(context),
                  ThemeHelper.getAccentColor(context).withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getAccentColor(context).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeHelper.getBackgroundColor(context),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircleAvatar(
                    backgroundImage: hasStories && currentUserStories.first.mediaUrl.isNotEmpty
                        ? CachedNetworkImageProvider(currentUserStories.first.mediaUrl)
                        : (user.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.avatarUrl)
                            : null),
                    backgroundColor: ThemeHelper.getSurfaceColor(context),
                    onBackgroundImageError: (hasStories && currentUserStories.first.mediaUrl.isNotEmpty) || user.avatarUrl.isNotEmpty
                        ? (exception, stackTrace) {}
                        : null,
                  ),
                  // Plus icon overlay
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ThemeHelper.getAccentColor(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ThemeHelper.getBackgroundColor(context),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: ThemeHelper.getOnAccentColor(context),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your story',
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOtherStoriesAndLivesWrap(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    AsyncValue<List<LivestreamModel>> liveAsync,
    {required LivestreamControllerState liveCtrlState}
  ) {
    return liveAsync.when(
      loading: () => _buildOtherStoriesAndLivesWrapData(
        currentUser,
        users,
        userStoriesMap,
        const [],
        liveCtrlState: liveCtrlState,
      ),
      error: (_, __) => _buildOtherStoriesAndLivesWrapData(
        currentUser,
        users,
        userStoriesMap,
        const [],
        liveCtrlState: liveCtrlState,
      ),
      data: (streams) => _buildOtherStoriesAndLivesWrapData(
        currentUser,
        users,
        userStoriesMap,
        streams,
        liveCtrlState: liveCtrlState,
      ),
    );
  }

  Widget _buildOtherStoriesAndLivesWrapData(
    UserModel? currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
    List<LivestreamModel> streams,
    {required LivestreamControllerState liveCtrlState}
  ) {
    final effectiveCurrentUser = currentUser ?? (users.isNotEmpty ? users.first : null);
    final myId = effectiveCurrentUser?.id ?? '';

    String streamHostId(LivestreamModel s) {
      if (s.hostId.isNotEmpty) return s.hostId;
      final h = s.host;
      if (h != null && h.id.isNotEmpty) return h.id;
      return '';
    }

    var mergedStreams = streams;
    if (myId.isNotEmpty &&
        liveCtrlState.state == LiveStreamState.live &&
        liveCtrlState.stream?.hostId == myId &&
        liveCtrlState.stream != null) {
      final ctrlStream = liveCtrlState.stream!;
      if (!mergedStreams.any((e) => e.streamId == ctrlStream.streamId)) {
        mergedStreams = [...mergedStreams, ctrlStream];
      }
    }

    final otherLives = myId.isNotEmpty
        ? mergedStreams.where((s) => streamHostId(s) != myId).toList()
        : mergedStreams;
    final otherStoryUsers = myId.isNotEmpty
        ? users
            .where((u) => u.id != myId && (userStoriesMap[u.id]?.isNotEmpty ?? false))
            .toList()
        : users.where((u) => (userStoriesMap[u.id]?.isNotEmpty ?? false)).toList();

    if (otherLives.isEmpty && otherStoryUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in otherLives)
          _LiveTile(
            stream: s,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LiveJoinOverlayScreen(stream: s)),
              );
            },
          ),
        for (final user in otherStoryUsers)
          _buildStoryBubble(
            user,
            userStoriesMap[user.id] ?? const <StoryModel>[],
            otherStoryUsers,
            userStoriesMap,
          ),
      ],
    );
  }

  Widget _buildStoryCard(
    UserModel user,
    List<StoryModel> stories,
    int userIndex,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final firstStory = stories.first;

    return GestureDetector(
      onTap: () => _openStoryViewer(userIndex, 0, users, userStoriesMap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smaller circular story widget
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeHelper.getAccentColor(context),
                  ThemeHelper.getAccentColor(context).withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getAccentColor(context).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeHelper.getBackgroundColor(context),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Story media background using CircleAvatar
                  firstStory.isVideo
                      ? CircleAvatar(
                          backgroundColor: Colors.black,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_circle_filled,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : CircleAvatar(
                          backgroundImage: firstStory.mediaUrl.isNotEmpty
                              ? CachedNetworkImageProvider(firstStory.mediaUrl)
                              : null,
                          backgroundColor: ThemeHelper.getSurfaceColor(context),
                          onBackgroundImageError: firstStory.mediaUrl.isNotEmpty
                              ? (exception, stackTrace) {}
                              : null,
                        ),
                  // Story count badge (if multiple stories)
                  if (stories.length > 1)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ThemeHelper.getAccentColor(context),
                              ThemeHelper.getAccentColor(context).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getAccentColor(context).withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${stories.length}',
                          style: TextStyle(
                            color: ThemeHelper.getOnAccentColor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // User name below circle
          Text(
            user.displayName,
            style: TextStyle(
              color: ThemeHelper.getTextPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showYourStoryOptions(
    UserModel currentUser,
    List<UserModel> users,
    Map<String, List<StoryModel>> userStoriesMap,
  ) {
    final currentUserStories = userStoriesMap[currentUser.id] ?? [];
    final userIndex = users.indexWhere((u) => u.id == currentUser.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.visibility,
                color: ThemeHelper.getAccentColor(context),
              ),
              title: Text(
                'View Story',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (userIndex >= 0) {
                  _openStoryViewer(userIndex, 0, users, userStoriesMap);
                }
              },
            ),
            Divider(color: ThemeHelper.getBorderColor(context)),
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: ThemeHelper.getAccentColor(context),
              ),
              title: Text(
                'Add Story',
                style: TextStyle(
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateContentScreen(
                      initialType: ContentType.story,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  final LivestreamModel stream;
  final VoidCallback onTap;
  const _LiveTile({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = ThemeHelper.getAccentColor(context);
    final bg = ThemeHelper.getBackgroundColor(context);
    final border = ThemeHelper.getBorderColor(context);
    final text = ThemeHelper.getTextPrimary(context);
    final muted = ThemeHelper.getTextSecondary(context);

    // Distinct ring for live streams (different feel from story ring).
    final ring = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFEF4444),
        const Color(0xFFF97316),
        accent,
      ],
    );

    final avatar = stream.host?.profilePicture ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ring,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withAlpha((0.22 * 255).round()),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
              ),
              padding: const EdgeInsets.all(2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    child: avatar.isNotEmpty
                        ? Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: ThemeHelper.getSurfaceColor(context),
                              alignment: Alignment.center,
                              child: Icon(Icons.person, color: muted),
                            ),
                          )
                        : Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            alignment: Alignment.center,
                            child: Icon(Icons.person, color: muted),
                          ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.55 * 255).round()),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withAlpha((0.14 * 255).round()),
                        ),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getSurfaceColor(context).withAlpha((0.92 * 255).round()),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: border.withAlpha((0.7 * 255).round())),
                      ),
                      child: Text(
                        '👁 ${stream.viewerCount}',
                        style: TextStyle(
                          color: text,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              stream.host?.username ?? 'Live',
              style: TextStyle(
                color: text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
