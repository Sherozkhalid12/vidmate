import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/blocked_user_model.dart';
import '../../services/users/blocked_users_service.dart';

final blockedUsersServiceProvider = Provider<BlockedUsersService>((ref) {
  return BlockedUsersService();
});

final blockedUserIdsProvider =
    StateNotifierProvider<BlockedUserIdsNotifier, Set<String>>((ref) {
  return BlockedUserIdsNotifier(ref);
});

final blockedUsersListProvider =
    StateNotifierProvider<BlockedUsersListNotifier, List<BlockedUserModel>>(
        (ref) {
  return BlockedUsersListNotifier(ref);
});

class BlockedUserIdsNotifier extends StateNotifier<Set<String>> {
  BlockedUserIdsNotifier(this._ref) : super({});

  final Ref _ref;

  BlockedUsersService get _service => _ref.read(blockedUsersServiceProvider);

  void setFromServer(Iterable<String> ids) {
    state = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<String?> syncFromServer() async {
    final result = await _service.fetchBlockedUsers();
    if (!result.success) return result.errorMessage;
    setFromServer(result.users.map((u) => u.id));
    _ref
        .read(blockedUsersListProvider.notifier)
        .setFromServer(result.users);
    return null;
  }

  Future<String?> blockUser(String userId) async {
    final result = await _service.blockUser(userId);
    if (!result.success) return result.errorMessage ?? 'Failed to block user';
    if (result.blockedUserIds.isNotEmpty) {
      setFromServer(result.blockedUserIds);
    } else {
      state = {...state, userId.trim()};
    }
    await syncFromServer();
    return null;
  }

  Future<String?> unblockUser(String userId) async {
    final result = await _service.unblockUser(userId);
    if (!result.success) {
      return result.errorMessage ?? 'Failed to unblock user';
    }
    if (result.blockedUserIds.isNotEmpty) {
      setFromServer(result.blockedUserIds);
    } else {
      final next = Set<String>.from(state)..remove(userId.trim());
      state = next;
    }
    await syncFromServer();
    return null;
  }

  void clear() {
    state = {};
    _ref.read(blockedUsersListProvider.notifier).clear();
  }

  void applySocketBlocked(String blockedUserId) {
    final id = blockedUserId.trim();
    if (id.isEmpty) return;
    state = {...state, id};
  }

  void applySocketUnblocked(String unblockedUserId) {
    final id = unblockedUserId.trim();
    if (id.isEmpty) return;
    final next = Set<String>.from(state)..remove(id);
    state = next;
  }
}

class BlockedUsersListNotifier extends StateNotifier<List<BlockedUserModel>> {
  BlockedUsersListNotifier(Ref ref) : super(const []);

  void setFromServer(List<BlockedUserModel> users) {
    state = List<BlockedUserModel>.from(users);
  }

  void clear() {
    state = const [];
  }
}
