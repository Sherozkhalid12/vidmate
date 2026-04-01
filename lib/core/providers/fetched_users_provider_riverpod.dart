import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../services/auth/auth_service.dart';
import '../models/user_model.dart';

class FetchedUsersState {
  final Map<String, UserModel> usersById;
  final Set<String> loadingIds;
  final Map<String, String> errorsById;
  /// Recently fetched user ids (most recent first) for fast reuse in UI.
  final List<String> recentUserIds;

  const FetchedUsersState({
    this.usersById = const {},
    this.loadingIds = const {},
    this.errorsById = const {},
    this.recentUserIds = const [],
  });

  FetchedUsersState copyWith({
    Map<String, UserModel>? usersById,
    Set<String>? loadingIds,
    Map<String, String>? errorsById,
    List<String>? recentUserIds,
  }) {
    return FetchedUsersState(
      usersById: usersById ?? this.usersById,
      loadingIds: loadingIds ?? this.loadingIds,
      errorsById: errorsById ?? this.errorsById,
      recentUserIds: recentUserIds ?? this.recentUserIds,
    );
  }
}

class FetchedUsersNotifier extends StateNotifier<FetchedUsersState> {
  FetchedUsersNotifier() : super(const FetchedUsersState());

  final AuthService _authService = AuthService();

  UserModel? getUser(String id) => state.usersById[id.trim()];
  bool isLoading(String id) => state.loadingIds.contains(id.trim());
  String? error(String id) => state.errorsById[id.trim()];

  /// Fetch user once and keep in-memory until app restart.
  Future<UserModel?> fetchIfNeeded(String id) async {
    final userId = id.trim();
    if (userId.isEmpty) return null;
    final cached = state.usersById[userId];
    if (cached != null) return cached;
    if (state.loadingIds.contains(userId)) return null;
    return fetch(userId);
  }

  Future<UserModel?> fetch(String id) async {
    final userId = id.trim();
    if (userId.isEmpty) return null;
    state = state.copyWith(
      loadingIds: {...state.loadingIds, userId},
      errorsById: {...state.errorsById}..remove(userId),
    );

    if (kDebugMode) debugPrint('[FetchedUsers] fetch start userId=$userId');

    try {
      final result = await _authService
          .getUserById(userId)
          // Prevent infinite spinner if token/storage hangs or request never completes.
          .timeout(const Duration(seconds: 25));

      if (!result.success || result.user == null) {
        state = state.copyWith(
          errorsById: {
            ...state.errorsById,
            userId: result.errorMessage ?? 'Failed to fetch user',
          },
        );
        if (kDebugMode) {
          debugPrint('[FetchedUsers] fetch failed userId=$userId error=${result.errorMessage}');
        }
        return null;
      }

      // Keep a small, recency-ordered list to reuse in UI.
      final nextRecents = <String>[userId, ...state.recentUserIds.where((e) => e != userId)];
      const maxRecents = 200;
      state = state.copyWith(
        usersById: {...state.usersById, userId: result.user!},
        recentUserIds: nextRecents.length > maxRecents ? nextRecents.take(maxRecents).toList() : nextRecents,
      );
      if (kDebugMode) debugPrint('[FetchedUsers] fetch success userId=$userId');
      return result.user;
    } on TimeoutException {
      state = state.copyWith(
        errorsById: {
          ...state.errorsById,
          userId: 'Request timed out',
        },
      );
      if (kDebugMode) debugPrint('[FetchedUsers] fetch timeout userId=$userId');
      return null;
    } catch (e) {
      state = state.copyWith(
        errorsById: {
          ...state.errorsById,
          userId: e.toString(),
        },
      );
      if (kDebugMode) debugPrint('[FetchedUsers] fetch error userId=$userId error=$e');
      return null;
    } finally {
      // CRITICAL: never leave a userId stuck in loadingIds.
      state = state.copyWith(
        loadingIds: {...state.loadingIds}..remove(userId),
      );
      if (kDebugMode) debugPrint('[FetchedUsers] fetch end userId=$userId loadingCleared=true');
    }
  }
}

final fetchedUsersProvider =
    StateNotifierProvider<FetchedUsersNotifier, FetchedUsersState>((ref) {
  return FetchedUsersNotifier();
});

final fetchedUserProvider = Provider.family<UserModel?, String>((ref, id) {
  final key = id.trim();
  return ref.watch(fetchedUsersProvider).usersById[key];
});

final fetchedUserLoadingProvider = Provider.family<bool, String>((ref, id) {
  final key = id.trim();
  return ref.watch(fetchedUsersProvider).loadingIds.contains(key);
});

final fetchedUserErrorProvider = Provider.family<String?, String>((ref, id) {
  final key = id.trim();
  return ref.watch(fetchedUsersProvider).errorsById[key];
});

/// List of recently fetched users (most recent first).
final fetchedUsersRecentListProvider = Provider<List<UserModel>>((ref) {
  final state = ref.watch(fetchedUsersProvider);
  final out = <UserModel>[];
  for (final id in state.recentUserIds) {
    final u = state.usersById[id];
    if (u != null) out.add(u);
  }
  return out;
});

