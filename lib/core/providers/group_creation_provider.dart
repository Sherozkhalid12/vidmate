import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_theme_preset.dart';

enum CreateGroupStep {
  pickMembers,
  configure,
  review,
}

class CreateGroupDraft {
  final CreateGroupStep step;
  final Set<String> selectedMemberIds;
  final List<Map<String, dynamic>> candidates;
  final String groupName;
  final String description;
  final String? imagePath;
  final bool allowNicknames;
  final bool allowMemberInvites;
  final bool allowMediaSharing;
  final bool allowPolls;
  final bool adminOnlyPosting;
  final ChatThemePreset chatTheme;
  final bool loadingCandidates;
  final String? error;

  const CreateGroupDraft({
    this.step = CreateGroupStep.pickMembers,
    this.selectedMemberIds = const {},
    this.candidates = const [],
    this.groupName = '',
    this.description = '',
    this.imagePath,
    this.allowNicknames = true,
    this.allowMemberInvites = true,
    this.allowMediaSharing = true,
    this.allowPolls = false,
    this.adminOnlyPosting = false,
    this.chatTheme = ChatThemePreset.defaultGradient,
    this.loadingCandidates = false,
    this.error,
  });

  bool get canProceedFromMembers =>
      selectedMemberIds.isNotEmpty && !loadingCandidates;

  bool get canProceedFromConfigure => groupName.trim().isNotEmpty;

  CreateGroupDraft copyWith({
    CreateGroupStep? step,
    Set<String>? selectedMemberIds,
    List<Map<String, dynamic>>? candidates,
    String? groupName,
    String? description,
    String? imagePath,
    bool clearImage = false,
    bool? allowNicknames,
    bool? allowMemberInvites,
    bool? allowMediaSharing,
    bool? allowPolls,
    bool? adminOnlyPosting,
    ChatThemePreset? chatTheme,
    bool? loadingCandidates,
    String? error,
    bool clearError = false,
  }) {
    return CreateGroupDraft(
      step: step ?? this.step,
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      candidates: candidates ?? this.candidates,
      groupName: groupName ?? this.groupName,
      description: description ?? this.description,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      allowNicknames: allowNicknames ?? this.allowNicknames,
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      allowMediaSharing: allowMediaSharing ?? this.allowMediaSharing,
      allowPolls: allowPolls ?? this.allowPolls,
      adminOnlyPosting: adminOnlyPosting ?? this.adminOnlyPosting,
      chatTheme: chatTheme ?? this.chatTheme,
      loadingCandidates: loadingCandidates ?? this.loadingCandidates,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CreateGroupNotifier extends StateNotifier<CreateGroupDraft> {
  CreateGroupNotifier() : super(const CreateGroupDraft());

  void reset() => state = const CreateGroupDraft();

  void setStep(CreateGroupStep step) => state = state.copyWith(step: step, clearError: true);

  void setCandidates(List<Map<String, dynamic>> users) {
    state = state.copyWith(
      candidates: users,
      loadingCandidates: false,
      clearError: true,
    );
  }

  void setLoadingCandidates(bool loading) {
    state = state.copyWith(loadingCandidates: loading);
  }

  void setError(String message) {
    state = state.copyWith(error: message, loadingCandidates: false);
  }

  void toggleMember(String id) {
    if (id.isEmpty) return;
    final next = Set<String>.from(state.selectedMemberIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(selectedMemberIds: next);
  }

  void setGroupName(String name) => state = state.copyWith(groupName: name);
  void setDescription(String desc) => state = state.copyWith(description: desc);
  void setImagePath(String? path) {
    if (path == null) {
      state = state.copyWith(clearImage: true);
    } else {
      state = state.copyWith(imagePath: path);
    }
  }

  void toggleAllowNicknames(bool v) => state = state.copyWith(allowNicknames: v);
  void toggleAllowInvites(bool v) => state = state.copyWith(allowMemberInvites: v);
  void toggleAllowMedia(bool v) => state = state.copyWith(allowMediaSharing: v);
  void toggleAllowPolls(bool v) => state = state.copyWith(allowPolls: v);
  void toggleAdminOnlyPosting(bool v) => state = state.copyWith(adminOnlyPosting: v);
  void setChatTheme(ChatThemePreset theme) => state = state.copyWith(chatTheme: theme);
}

final createGroupProvider =
    StateNotifierProvider.autoDispose<CreateGroupNotifier, CreateGroupDraft>(
  (ref) => CreateGroupNotifier(),
);
