import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/chat_settings_provider.dart';
import '../../../core/utils/theme_helper.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/ios_back_button.dart';

/// Full members directory for a group, opened from the group profile.
class GroupMembersScreen extends ConsumerWidget {
  final String groupId;
  final List<Map<String, dynamic>> members;
  final bool isAdmin;

  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.members,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(groupSettingsProvider);
    final settings = ref.read(groupSettingsProvider.notifier).settingsFor(groupId);

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        elevation: 0,
        leading: const IosBackButton(),
        title: Text(
          'Members · ${members.length}',
          style: TextStyle(
            color: ThemeHelper.getTextPrimary(context),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: members.isEmpty
          ? Center(
              child: Text(
                'No members yet',
                style: TextStyle(color: ThemeHelper.getTextMuted(context)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final m = members[i];
                final id = (m['id'] ?? m['_id'] ?? '').toString();
                final name =
                    (m['username'] ?? m['name'] ?? m['displayName'] ?? 'Member').toString();
                final avatar = (m['profilePicture'] ?? m['avatarUrl'] ?? '').toString();
                final nick = settings.memberNicknames[id] ?? '';
                final display = nick.isNotEmpty ? nick : name;

                return GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: ThemeHelper.getSurfaceColor(context),
                        backgroundImage:
                            avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                        child: avatar.isEmpty
                            ? Icon(Icons.person, color: ThemeHelper.getTextMuted(context))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              display,
                              style: TextStyle(
                                color: ThemeHelper.getTextPrimary(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            if (nick.isNotEmpty)
                              Text(
                                '@$name',
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
              },
            ),
    );
  }
}
