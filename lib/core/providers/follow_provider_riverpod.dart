import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'auth_provider_riverpod.dart';
import 'posts_provider_riverpod.dart';
import '../../services/follow/follow_service.dart';

/// State for follow lists and instant follow-status cache.
class FollowState {
  final List<UserModel> followingList;
  final List<UserModel> followersList;
  final Set<String> followingIds;
  /// For private accounts: outgoing pending requests (targetUserId -> requestId).
  final Map<String, String> outgoingPendingRequests;
  final bool isLoadingFollowing;
  final bool isLoadingFollowers;
  final String? errorFollowing;
  final String? errorFollowers;

  FollowState({
    this.followingList = const [],
    this.followersList = const [],
    Set<String>? followingIds,
    this.outgoingPendingRequests = const {},
    this.isLoadingFollowing = false,
    this.isLoadingFollowers = false,
    this.errorFollowing,
    this.errorFollowers,
  }) : followingIds = followingIds ?? {};

  FollowState copyWith({
    List<UserModel>? followingList,
    List<UserModel>? followersList,
    Set<String>? followingIds,
    Map<String, String>? outgoingPendingRequests,
    bool? isLoadingFollowing,
    bool? isLoadingFollowers,
    String? errorFollowing,
    String? errorFollowers,
    bool clearErrorFollowing = false,
    bool clearErrorFollowers = false,
  }) {
    return FollowState(
      followingList: followingList ?? this.followingList,
      followersList: followersList ?? this.followersList,
      followingIds: followingIds ?? this.followingIds,
      outgoingPendingRequests:
          outgoingPendingRequests ?? this.outgoingPendingRequests,
      isLoadingFollowing: isLoadingFollowing ?? this.isLoadingFollowing,
      isLoadingFollowers: isLoadingFollowers ?? this.isLoadingFollowers,
      errorFollowing: clearErrorFollowing ? null : (errorFollowing ?? this.errorFollowing),
      errorFollowers: clearErrorFollowers ? null : (errorFollowers ?? this.errorFollowers),
    );
  }
}

/// Notifier for follow/unfollow and follow lists. Optimistic updates for instant UI;
/// after API success refreshes following list and syncs posts + followState providers.
class FollowNotifier extends StateNotifier<FollowState> {
  FollowNotifier(this._ref) : super(FollowState()) {
    _followService = FollowService();
  }

  final Ref _ref;
  late final FollowService _followService;

  bool isFollowing(String userId) => state.followingIds.contains(userId);
  bool isPending(String userId) => state.outgoingPendingRequests.containsKey(userId);

  /// Refresh following list from API and update followingIds cache.
  Future<void> refreshFollowings() async {
    state = state.copyWith(isLoadingFollowing: true, clearErrorFollowing: true);
    final result = await _followService.getFollowings();
    if (!result.success) {
      state = state.copyWith(
        isLoadingFollowing: false,
        errorFollowing: result.errorMessage ?? 'Failed to load following',
      );
      return;
    }
    final ids = result.users.map((u) => u.id).toSet();
    state = state.copyWith(
      followingList: result.users,
      followingIds: ids,
      isLoadingFollowing: false,
    );
  }

  /// Refresh followers list from API.
  Future<void> refreshFollowers() async {
    state = state.copyWith(isLoadingFollowers: true, clearErrorFollowers: true);
    final result = await _followService.getFollowers();
    if (!result.success) {
      state = state.copyWith(
        isLoadingFollowers: false,
        errorFollowers: result.errorMessage ?? 'Failed to load followers',
      );
      return;
    }
    state = state.copyWith(
      followersList: result.users,
      isLoadingFollowers: false,
    );
  }

  /// Ensure follow lists are loaded once when user is logged in (e.g. for profile).
  Future<void> ensureFollowListsLoaded() async {
    if (state.followingList.isEmpty && !state.isLoadingFollowing) {
      await refreshFollowings();
    }
    if (state.followersList.isEmpty && !state.isLoadingFollowers) {
      await refreshFollowers();
    }
  }

  /// Follow user: optimistic update, API call, then refresh following list and sync UI.
  Future<bool> follow(String userId) async {
    final previousIds = Set<String>.from(state.followingIds);
    final previousPending =
        Map<String, String>.from(state.outgoingPendingRequests);

    final result = await _followService.follow(userId);
    if (!result.success) {
      state = state.copyWith(
        followingIds: previousIds,
        outgoingPendingRequests: previousPending,
      );
      return false;
    }

    final status = result.status ?? 'following';
    if (status == 'pending') {
      // Do not add to followingIds. Track as pending request.
      final requestId = result.requestId ?? '';
      if (requestId.isNotEmpty) {
        state = state.copyWith(
          outgoingPendingRequests: {
            ...state.outgoingPendingRequests,
            userId: requestId,
          },
        );
      }
      _ref.read(followStateProvider.notifier).setStatus(
            userId,
            FollowRelationshipStatus.pending,
          );
      return true;
    }

    // following (or already following)
    state = state.copyWith(followingIds: {...state.followingIds, userId});
    _ref.read(followStateProvider.notifier).setStatus(
          userId,
          FollowRelationshipStatus.following,
        );
    _ref.read(postsProvider.notifier).toggleFollow(userId);
    await refreshFollowings();
    return true;
  }

  /// Unfollow user: optimistic update, API call, then refresh following list and sync UI.
  Future<bool> unfollow(String userId) async {
    final previousIds = Set<String>.from(state.followingIds);
    final previousPending =
        Map<String, String>.from(state.outgoingPendingRequests);
    final newIds = Set<String>.from(state.followingIds)..remove(userId);
    final newPending = Map<String, String>.from(state.outgoingPendingRequests)
      ..remove(userId);
    state = state.copyWith(followingIds: newIds, outgoingPendingRequests: newPending);

    final result = await _followService.unfollow(userId);
    if (!result.success) {
      state = state.copyWith(
        followingIds: previousIds,
        outgoingPendingRequests: previousPending,
      );
      return false;
    }
    // If it was a real unfollow, update post follow state.
    if (previousIds.contains(userId)) {
      _ref.read(postsProvider.notifier).toggleFollow(userId);
    }
    await refreshFollowings();
    _ref.read(followStateProvider.notifier).setStatus(
          userId,
          FollowRelationshipStatus.none,
        );
    return true;
  }

  /// Toggle follow state: if currently following, unfollow; else follow.
  Future<bool> toggleFollow(String userId) async {
    if (isFollowing(userId)) {
      return unfollow(userId);
    }
    return follow(userId);
  }
}

final followProvider =
    StateNotifierProvider<FollowNotifier, FollowState>((ref) {
  return FollowNotifier(ref);
});

/// True if current user follows [userId]. Uses cached followingIds for instant UI.
final isFollowingProvider = Provider.family<bool, String>((ref, userId) {
  return ref.watch(followProvider).followingIds.contains(userId);
});

/// Current user's following list (cached).
final followingListProvider = Provider<List<UserModel>>((ref) {
  return ref.watch(followProvider).followingList;
});

/// Current user's followers list (cached).
final followersListProvider = Provider<List<UserModel>>((ref) {
  return ref.watch(followProvider).followersList;
});
