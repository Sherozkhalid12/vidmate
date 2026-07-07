import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_theme_preset.dart';

const _chatSettingsPrefix = 'chat.settings.';
const _groupSettingsPrefix = 'chat.group.settings.';

class ChatSettingsNotifier extends StateNotifier<Map<String, ChatConversationSettings>> {
  ChatSettingsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_chatSettingsPrefix));
    final map = <String, ChatConversationSettings>{};
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final convId = key.substring(_chatSettingsPrefix.length);
        map[convId] = ChatConversationSettings.fromJson(json);
      } catch (_) {}
    }
    state = map;
  }

  ChatConversationSettings settingsFor(String conversationId) {
    return state[conversationId] ?? const ChatConversationSettings();
  }

  Future<void> updateSettings(
    String conversationId,
    ChatConversationSettings settings,
  ) async {
    state = {...state, conversationId: settings};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_chatSettingsPrefix$conversationId',
      jsonEncode(settings.toJson()),
    );
  }
}

final chatSettingsProvider =
    StateNotifierProvider<ChatSettingsNotifier, Map<String, ChatConversationSettings>>(
  (ref) => ChatSettingsNotifier(),
);

class GroupSettingsNotifier extends StateNotifier<Map<String, GroupChatSettings>> {
  GroupSettingsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_groupSettingsPrefix));
    final map = <String, GroupChatSettings>{};
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final groupId = key.substring(_groupSettingsPrefix.length);
        map[groupId] = GroupChatSettings.fromJson(json);
      } catch (_) {}
    }
    state = map;
  }

  GroupChatSettings settingsFor(String groupId) {
    return state[groupId] ?? const GroupChatSettings();
  }

  Future<void> updateSettings(String groupId, GroupChatSettings settings) async {
    state = {...state, groupId: settings};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_groupSettingsPrefix$groupId',
      jsonEncode(settings.toJson()),
    );
  }

  String displayNameFor({
    required String groupId,
    required String userId,
    required String fallbackName,
  }) {
    final settings = settingsFor(groupId);
    if (!settings.allowNicknames) return fallbackName;
    return settings.memberNicknames[userId]?.trim().isNotEmpty == true
        ? settings.memberNicknames[userId]!.trim()
        : fallbackName;
  }
}

final groupSettingsProvider =
    StateNotifierProvider<GroupSettingsNotifier, Map<String, GroupChatSettings>>(
  (ref) => GroupSettingsNotifier(),
);
