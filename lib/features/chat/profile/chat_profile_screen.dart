import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_model.dart';
import '../../../core/providers/chat_settings_provider.dart';
import '../../../core/providers/chat_shared_media_provider.dart';
import '../../../core/utils/theme_helper.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/ios_back_button.dart';
import '../widgets/chat_screen_background.dart';
import 'widgets/chat_shared_media_tabs.dart';

/// Premium direct-message profile & settings.
class ChatProfileScreen extends ConsumerWidget {
  final UserModel user;
  final String conversationId;

  const ChatProfileScreen({
    super.key,
    required this.user,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatSettingsProvider);
    final settings = ref.read(chatSettingsProvider.notifier).settingsFor(conversationId);

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: ChatScreenBackground(
        conversationId: conversationId,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              leading: const IosBackButton(),
              backgroundColor: ThemeHelper.getSurfaceColor(context).withValues(alpha: 0.85),
              iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                title: Text(
                  user.displayName.isNotEmpty ? user.displayName : user.username,
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
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ThemeHelper.getAccentColor(context).withValues(alpha: 0.25),
                            ThemeHelper.getBackgroundColor(context),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.35),
                      child: _AvatarRing(url: user.avatarUrl, size: 88),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Preferences'),
                  const SizedBox(height: 10),
                  _ToggleTile(
                    icon: Icons.notifications_off_outlined,
                    title: 'Mute notifications',
                    value: settings.muteNotifications,
                    onChanged: (v) {
                      ref.read(chatSettingsProvider.notifier).updateSettings(
                            conversationId,
                            settings.copyWith(muteNotifications: v),
                          );
                    },
                  ),
                  _ToggleTile(
                    icon: Icons.push_pin_outlined,
                    title: 'Pin conversation',
                    value: settings.pinConversation,
                    onChanged: (v) {
                      ref.read(chatSettingsProvider.notifier).updateSettings(
                            conversationId,
                            settings.copyWith(pinConversation: v),
                          );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(title: 'Shared media'),
                  const SizedBox(height: 10),
                  ChatSharedMediaTabs(
                    mediaKey: ChatSharedMediaKey(peerUserId: user.id),
                  ),
                  const SizedBox(height: 28),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String url;
  final double size;

  const _AvatarRing({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ThemeHelper.getAccentGradient(context),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.getAccentColor(context).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : ColoredBox(
                color: ThemeHelper.getSurfaceColor(context),
                child: Icon(Icons.person, size: size * 0.45, color: ThemeHelper.getTextMuted(context)),
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: ThemeHelper.getTextSecondary(context),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      borderRadius: BorderRadius.circular(16),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: ThemeHelper.getAccentColor(context)),
        title: Text(title, style: TextStyle(color: ThemeHelper.getTextPrimary(context))),
        value: value,
        activeColor: ThemeHelper.getAccentColor(context),
        onChanged: onChanged,
      ),
    );
  }
}
