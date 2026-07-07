import 'package:flutter/material.dart';

/// Visual preset for a chat conversation background.
enum ChatThemePreset {
  defaultGradient,
  midnight,
  aurora,
  sand,
  ember,
  custom,
}

extension ChatThemePresetX on ChatThemePreset {
  String get storageKey => name;

  static ChatThemePreset fromKey(String? key) {
    if (key == null || key.isEmpty) return ChatThemePreset.defaultGradient;
    return ChatThemePreset.values.firstWhere(
      (e) => e.name == key,
      orElse: () => ChatThemePreset.defaultGradient,
    );
  }

  String get label {
    switch (this) {
      case ChatThemePreset.defaultGradient:
        return 'Classic';
      case ChatThemePreset.midnight:
        return 'Midnight';
      case ChatThemePreset.aurora:
        return 'Aurora';
      case ChatThemePreset.sand:
        return 'Sand';
      case ChatThemePreset.ember:
        return 'Ember';
      case ChatThemePreset.custom:
        return 'Custom';
    }
  }

  List<Color> gradientColors(bool isDark) {
    switch (this) {
      case ChatThemePreset.defaultGradient:
        return isDark
            ? [const Color(0xFF0D0D12), const Color(0xFF151520)]
            : [const Color(0xFFF8F9FC), const Color(0xFFEEF1F8)];
      case ChatThemePreset.midnight:
        return [const Color(0xFF05060A), const Color(0xFF12182B)];
      case ChatThemePreset.aurora:
        return isDark
            ? [const Color(0xFF0A1628), const Color(0xFF1A2F4A)]
            : [const Color(0xFFE8F4FF), const Color(0xFFF0E8FF)];
      case ChatThemePreset.sand:
        return isDark
            ? [const Color(0xFF1A1510), const Color(0xFF2A2218)]
            : [const Color(0xFFFFF8F0), const Color(0xFFF5EDE0)];
      case ChatThemePreset.ember:
        return isDark
            ? [const Color(0xFF1A0E0E), const Color(0xFF2A1414)]
            : [const Color(0xFFFFF5F0), const Color(0xFFFFE8E0)];
      case ChatThemePreset.custom:
        return isDark
            ? [const Color(0xFF0D0D12), const Color(0xFF151520)]
            : [const Color(0xFFF8F9FC), const Color(0xFFEEF1F8)];
    }
  }
}

/// Per-conversation chat customization stored locally.
class ChatConversationSettings {
  final ChatThemePreset theme;
  final String? customBackgroundUrl;
  final bool muteNotifications;
  final bool pinConversation;

  const ChatConversationSettings({
    this.theme = ChatThemePreset.defaultGradient,
    this.customBackgroundUrl,
    this.muteNotifications = false,
    this.pinConversation = false,
  });

  ChatConversationSettings copyWith({
    ChatThemePreset? theme,
    String? customBackgroundUrl,
    bool? muteNotifications,
    bool? pinConversation,
  }) {
    return ChatConversationSettings(
      theme: theme ?? this.theme,
      customBackgroundUrl: customBackgroundUrl ?? this.customBackgroundUrl,
      muteNotifications: muteNotifications ?? this.muteNotifications,
      pinConversation: pinConversation ?? this.pinConversation,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.storageKey,
        if (customBackgroundUrl != null) 'customBackgroundUrl': customBackgroundUrl,
        'muteNotifications': muteNotifications,
        'pinConversation': pinConversation,
      };

  factory ChatConversationSettings.fromJson(Map<String, dynamic> json) {
    return ChatConversationSettings(
      theme: ChatThemePresetX.fromKey(json['theme']?.toString()),
      customBackgroundUrl: json['customBackgroundUrl']?.toString(),
      muteNotifications: json['muteNotifications'] == true,
      pinConversation: json['pinConversation'] == true,
    );
  }
}

/// Group-specific settings created at setup and editable in group profile.
class GroupChatSettings {
  final String description;
  final bool allowNicknames;
  final bool allowMemberInvites;
  final bool allowMediaSharing;
  final bool allowPolls;
  final bool adminOnlyPosting;
  final Map<String, String> memberNicknames;

  const GroupChatSettings({
    this.description = '',
    this.allowNicknames = true,
    this.allowMemberInvites = true,
    this.allowMediaSharing = true,
    this.allowPolls = false,
    this.adminOnlyPosting = false,
    this.memberNicknames = const {},
  });

  GroupChatSettings copyWith({
    String? description,
    bool? allowNicknames,
    bool? allowMemberInvites,
    bool? allowMediaSharing,
    bool? allowPolls,
    bool? adminOnlyPosting,
    Map<String, String>? memberNicknames,
  }) {
    return GroupChatSettings(
      description: description ?? this.description,
      allowNicknames: allowNicknames ?? this.allowNicknames,
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      allowMediaSharing: allowMediaSharing ?? this.allowMediaSharing,
      allowPolls: allowPolls ?? this.allowPolls,
      adminOnlyPosting: adminOnlyPosting ?? this.adminOnlyPosting,
      memberNicknames: memberNicknames ?? this.memberNicknames,
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'allowNicknames': allowNicknames,
        'allowMemberInvites': allowMemberInvites,
        'allowMediaSharing': allowMediaSharing,
        'allowPolls': allowPolls,
        'adminOnlyPosting': adminOnlyPosting,
        'memberNicknames': memberNicknames,
      };

  factory GroupChatSettings.fromJson(Map<String, dynamic> json) {
    final nickRaw = json['memberNicknames'];
    final nicks = <String, String>{};
    if (nickRaw is Map) {
      nickRaw.forEach((k, v) {
        final key = k?.toString() ?? '';
        final val = v?.toString() ?? '';
        if (key.isNotEmpty && val.isNotEmpty) nicks[key] = val;
      });
    }
    return GroupChatSettings(
      description: (json['description'] ?? '').toString(),
      allowNicknames: json['allowNicknames'] != false,
      allowMemberInvites: json['allowMemberInvites'] != false,
      allowMediaSharing: json['allowMediaSharing'] != false,
      allowPolls: json['allowPolls'] == true,
      adminOnlyPosting: json['adminOnlyPosting'] == true,
      memberNicknames: nicks,
    );
  }
}
