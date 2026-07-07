import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/blocked_user_model.dart';
import '../../core/providers/blocked_users_provider.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';

class BlockedAccountsScreen extends ConsumerStatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  ConsumerState<BlockedAccountsScreen> createState() =>
      _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends ConsumerState<BlockedAccountsScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await ref.read(blockedUserIdsProvider.notifier).syncFromServer();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  Future<void> _unblock(BlockedUserModel user) async {
    final err =
        await ref.read(blockedUserIdsProvider.notifier).unblockUser(user.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unblocked ${user.username}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(blockedUsersListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.getBackgroundGradient(context),
        ),
        child: Column(
          children: [
            AppBar(
              title: Text(
                'Blocked Accounts',
                style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme:
                  IconThemeData(color: ThemeHelper.getTextPrimary(context)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && users.isEmpty
                      ? _buildError()
                      : users.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  return _BlockedUserTile(
                                    user: user,
                                    onUnblock: () => _unblock(user),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        'You have not blocked anyone.',
        style: TextStyle(color: ThemeHelper.getTextSecondary(context)),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error ?? 'Failed to load blocked users',
            textAlign: TextAlign.center,
            style: TextStyle(color: ThemeHelper.getTextSecondary(context)),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.onUnblock,
  });

  final BlockedUserModel user;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: ThemeHelper.getAccentColor(context).withValues(alpha: 0.2),
            backgroundImage: user.profilePicture != null
                ? NetworkImage(user.profilePicture!)
                : null,
            child: user.profilePicture == null
                ? Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.username,
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onUnblock,
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }
}
