import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat_theme_preset.dart';
import '../../../core/providers/chat_settings_provider.dart';
import '../../../core/providers/chat_shared_media_provider.dart';
import '../../../core/utils/theme_helper.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/ios_back_button.dart';
import '../group/group_members_screen.dart';
import '../widgets/chat_screen_background.dart';
import 'widgets/chat_shared_media_tabs.dart';

/// Group info, members, permissions, and chat customization.
class GroupProfileScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupAvatar;
  final List<Map<String, dynamic>> members;
  final bool isAdmin;

  const GroupProfileScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatar,
    this.members = const [],
    this.isAdmin = true,
  });

  @override
  ConsumerState<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends ConsumerState<GroupProfileScreen> {
  String get _conversationId => 'group:${widget.groupId}';

  @override
  Widget build(BuildContext context) {
    ref.watch(groupSettingsProvider);
    final groupSettings =
        ref.read(groupSettingsProvider.notifier).settingsFor(widget.groupId);

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: ChatScreenBackground(
        conversationId: _conversationId,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              leading: const IosBackButton(),
              backgroundColor: ThemeHelper.getSurfaceColor(context).withValues(alpha: 0.9),
              iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                title: Text(
                  widget.groupName,
                  style: TextStyle(
                    color: ThemeHelper.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ThemeHelper.getAccentColor(context).withValues(alpha: 0.3),
                            ThemeHelper.getBackgroundColor(context),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.3),
                      child: _GroupAvatar(url: widget.groupAvatar ?? '', size: 92),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (groupSettings.description.isNotEmpty) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(18),
                      child: Text(
                        groupSettings.description,
                        style: TextStyle(
                          color: ThemeHelper.getTextSecondary(context),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _header('Members'),
                  const SizedBox(height: 10),
                  _MemberPreviewCard(
                    members: widget.members,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => GroupMembersScreen(
                            groupId: widget.groupId,
                            members: widget.members,
                            isAdmin: widget.isAdmin,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _header('Group permissions'),
                  const SizedBox(height: 10),
                  if (widget.isAdmin) ...[
                    _permToggle(
                      'Allow nicknames',
                      groupSettings.allowNicknames,
                      (v) => _updateGroup(groupSettings.copyWith(allowNicknames: v)),
                    ),
                    _permToggle(
                      'Allow media sharing',
                      groupSettings.allowMediaSharing,
                      (v) => _updateGroup(groupSettings.copyWith(allowMediaSharing: v)),
                    ),
                    _permToggle(
                      'Admin-only posting',
                      groupSettings.adminOnlyPosting,
                      (v) => _updateGroup(groupSettings.copyWith(adminOnlyPosting: v)),
                    ),
                  ] else
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderRadius: BorderRadius.circular(16),
                      child: Text(
                        'Only admins can change group permissions.',
                        style: TextStyle(color: ThemeHelper.getTextMuted(context), fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 28),
                  _header('Shared media'),
                  const SizedBox(height: 10),
                  ChatSharedMediaTabs(
                    mediaKey: ChatSharedMediaKey(groupId: widget.groupId),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) {
    return Text(
      text,
      style: TextStyle(
        color: ThemeHelper.getTextSecondary(context),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _permToggle(String title, bool value, ValueChanged<bool> onChanged) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      borderRadius: BorderRadius.circular(16),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: TextStyle(color: ThemeHelper.getTextPrimary(context))),
        value: value,
        activeColor: ThemeHelper.getAccentColor(context),
        onChanged: widget.isAdmin ? onChanged : null,
      ),
    );
  }

  void _updateGroup(GroupChatSettings settings) {
    ref.read(groupSettingsProvider.notifier).updateSettings(widget.groupId, settings);
  }
}

/// Compact, premium members preview: overlapping avatars + count, tappable.
class _MemberPreviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final VoidCallback onTap;

  const _MemberPreviewCard({required this.members, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = members.take(5).toList();
    final extra = members.length - preview.length;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            if (preview.isEmpty)
              CircleAvatar(
                radius: 18,
                backgroundColor: ThemeHelper.getSurfaceColor(context),
                child: Icon(Icons.groups_rounded, color: ThemeHelper.getAccentColor(context)),
              )
            else
              SizedBox(
                width: (preview.length * 24).toDouble() + 12,
                height: 40,
                child: Stack(
                  children: [
                    for (var i = 0; i < preview.length; i++)
                      Positioned(
                        left: i * 24.0,
                        child: _stackedAvatar(context, preview[i]),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${members.length} member${members.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    extra > 0 ? 'Tap to view all' : 'Tap to view members',
                    style: TextStyle(
                      color: ThemeHelper.getTextMuted(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ThemeHelper.getTextMuted(context)),
          ],
        ),
      ),
    );
  }

  Widget _stackedAvatar(BuildContext context, Map<String, dynamic> m) {
    final avatar = (m['profilePicture'] ?? m['avatarUrl'] ?? '').toString();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ThemeHelper.getBackgroundColor(context), width: 2),
      ),
      child: CircleAvatar(
        backgroundColor: ThemeHelper.getSurfaceColor(context),
        backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
        child: avatar.isEmpty
            ? Icon(Icons.person, size: 18, color: ThemeHelper.getTextMuted(context))
            : null,
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  final String url;
  final double size;

  const _GroupAvatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: ThemeHelper.getAccentGradient(context),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.getAccentColor(context).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : ColoredBox(
                color: ThemeHelper.getSurfaceColor(context),
                child: Icon(Icons.groups_rounded, size: size * 0.4, color: ThemeHelper.getAccentColor(context)),
              ),
      ),
    );
  }
}
