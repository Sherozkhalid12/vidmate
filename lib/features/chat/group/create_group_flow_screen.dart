import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/chat_theme_preset.dart';
import '../../../core/providers/chat_provider_riverpod.dart';
import '../../../core/providers/chat_settings_provider.dart';
import '../../../core/providers/group_creation_provider.dart';
import '../../../core/utils/theme_helper.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../services/chat/chat_service.dart';
import '../group_chat_screen.dart';

/// Multi-step group creation: members → configure → review → create.
class CreateGroupFlowScreen extends ConsumerStatefulWidget {
  const CreateGroupFlowScreen({super.key});

  @override
  ConsumerState<CreateGroupFlowScreen> createState() => _CreateGroupFlowScreenState();
}

class _CreateGroupFlowScreenState extends ConsumerState<CreateGroupFlowScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCandidates());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    ref.read(createGroupProvider.notifier).setLoadingCandidates(true);
    final res = await ChatService().getShareableUsers();
    if (!mounted) return;
    if (!res.success) {
      ref.read(createGroupProvider.notifier).setError(res.errorMessage ?? 'Failed to load users');
      return;
    }
    ref.read(createGroupProvider.notifier).setCandidates(res.data ?? const []);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      ref.read(createGroupProvider.notifier).setImagePath(picked.path);
    }
  }

  Future<void> _createGroup() async {
    final draft = ref.read(createGroupProvider);
    final name = draft.groupName.trim().isNotEmpty ? draft.groupName.trim() : _nameCtrl.text.trim();
    if (name.isEmpty || draft.selectedMemberIds.isEmpty) return;

    final res = await ChatService().createGroup(
      name: name,
      description: draft.description.trim().isNotEmpty ? draft.description.trim() : _descCtrl.text.trim(),
      participantIds: draft.selectedMemberIds.toList(),
    );
    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Failed to create group')),
      );
      return;
    }

    final data = res.data ?? const <String, dynamic>{};
    final group = data['group'] is Map<String, dynamic>
        ? data['group'] as Map<String, dynamic>
        : (data['group'] is Map ? Map<String, dynamic>.from(data['group'] as Map) : <String, dynamic>{});
    final groupId = (group['_id'] ?? group['id'] ?? data['groupId'] ?? '').toString();
    final groupName = (group['name'] ?? name).toString();
    if (groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created but id missing')),
      );
      return;
    }

    await ref.read(groupSettingsProvider.notifier).updateSettings(
          groupId,
          GroupChatSettings(
            description: draft.description.trim().isNotEmpty ? draft.description.trim() : _descCtrl.text.trim(),
            allowNicknames: draft.allowNicknames,
            allowMediaSharing: draft.allowMediaSharing,
            adminOnlyPosting: draft.adminOnlyPosting,
          ),
        );

    ref.read(conversationsProvider.notifier).upsertGroupConversation(
          groupId: groupId,
          groupName: groupName,
          lastMessage: 'Group created',
        );

    ref.read(createGroupProvider.notifier).reset();

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(groupId: groupId, groupName: groupName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(createGroupProvider);
    final bg = ThemeHelper.getBackgroundColor(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: ThemeHelper.getSurfaceColor(context).withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          _stepTitle(draft.step),
          style: TextStyle(color: ThemeHelper.getTextPrimary(context), fontWeight: FontWeight.w700),
        ),
        iconTheme: IconThemeData(color: ThemeHelper.getTextPrimary(context)),
      ),
      body: Column(
        children: [
          _StepIndicator(step: draft.step),
          Expanded(child: _buildStepBody(draft)),
          _buildBottomBar(draft),
        ],
      ),
    );
  }

  String _stepTitle(CreateGroupStep step) {
    switch (step) {
      case CreateGroupStep.pickMembers:
        return 'Add members';
      case CreateGroupStep.configure:
        return 'Group details';
      case CreateGroupStep.review:
        return 'Review';
    }
  }

  Widget _buildStepBody(CreateGroupDraft draft) {
    switch (draft.step) {
      case CreateGroupStep.pickMembers:
        return _membersStep(draft);
      case CreateGroupStep.configure:
        return _configureStep(draft);
      case CreateGroupStep.review:
        return _reviewStep(draft);
    }
  }

  Widget _membersStep(CreateGroupDraft draft) {
    if (draft.loadingCandidates) {
      return const Center(child: CircularProgressIndicator());
    }
    if (draft.error != null) {
      return Center(child: Text(draft.error!, style: TextStyle(color: ThemeHelper.getTextMuted(context))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: draft.candidates.length,
      itemBuilder: (ctx, i) {
        final u = draft.candidates[i];
        final id = (u['id'] ?? u['_id'] ?? '').toString();
        final name = (u['username'] ?? u['name'] ?? 'User').toString();
        final avatar = (u['profilePicture'] ?? u['avatarUrl'] ?? '').toString();
        final selected = draft.selectedMemberIds.contains(id);
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          borderRadius: BorderRadius.circular(16),
          onTap: id.isEmpty ? null : () => ref.read(createGroupProvider.notifier).toggleMember(id),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
              child: avatar.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(name, style: TextStyle(color: ThemeHelper.getTextPrimary(context))),
            trailing: Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? ThemeHelper.getAccentColor(context) : ThemeHelper.getTextMuted(context),
            ),
          ),
        );
      },
    );
  }

  Widget _configureStep(CreateGroupDraft draft) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: ThemeHelper.getAccentGradient(context),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: draft.imagePath != null
                    ? Image.file(File(draft.imagePath!), fit: BoxFit.cover)
                    : ColoredBox(
                        color: ThemeHelper.getSurfaceColor(context),
                        child: Icon(Icons.add_a_photo_outlined, color: ThemeHelper.getAccentColor(context)),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _field('Group name', _nameCtrl, 'e.g. Weekend crew', onChanged: ref.read(createGroupProvider.notifier).setGroupName),
        const SizedBox(height: 12),
        _field('Description', _descCtrl, 'What is this group about?', maxLines: 3,
            onChanged: ref.read(createGroupProvider.notifier).setDescription),
        const SizedBox(height: 20),
        Text('Features', style: TextStyle(color: ThemeHelper.getTextSecondary(context), fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _switchTile('Allow nicknames', draft.allowNicknames, ref.read(createGroupProvider.notifier).toggleAllowNicknames),
        _switchTile('Media sharing', draft.allowMediaSharing, ref.read(createGroupProvider.notifier).toggleAllowMedia),
        _switchTile('Admin-only posting', draft.adminOnlyPosting, ref.read(createGroupProvider.notifier).toggleAdminOnlyPosting),
      ],
    );
  }

  Widget _reviewStep(CreateGroupDraft draft) {
    final name = draft.groupName.trim().isNotEmpty ? draft.groupName.trim() : _nameCtrl.text.trim();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(color: ThemeHelper.getTextPrimary(context), fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${draft.selectedMemberIds.length} members',
                  style: TextStyle(color: ThemeHelper.getTextMuted(context))),
              if (draft.description.trim().isNotEmpty || _descCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(draft.description.trim().isNotEmpty ? draft.description.trim() : _descCtrl.text.trim(),
                    style: TextStyle(color: ThemeHelper.getTextSecondary(context))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1, required ValueChanged<String> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ThemeHelper.getTextSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(color: ThemeHelper.getTextPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: ThemeHelper.getTextMuted(context)),
            filled: true,
            fillColor: ThemeHelper.getSurfaceColor(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      borderRadius: BorderRadius.circular(14),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: TextStyle(color: ThemeHelper.getTextPrimary(context), fontSize: 14)),
        value: value,
        activeColor: ThemeHelper.getAccentColor(context),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildBottomBar(CreateGroupDraft draft) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (draft.step != CreateGroupStep.pickMembers)
              TextButton(
                onPressed: () {
                  final prev = draft.step == CreateGroupStep.review
                      ? CreateGroupStep.configure
                      : CreateGroupStep.pickMembers;
                  ref.read(createGroupProvider.notifier).setStep(prev);
                },
                child: Text('Back', style: TextStyle(color: ThemeHelper.getTextSecondary(context))),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _primaryEnabled(draft) ? () => _onPrimary(draft) : null,
              style: FilledButton.styleFrom(
                backgroundColor: ThemeHelper.getAccentColor(context),
                foregroundColor: ThemeHelper.getOnAccentColor(context),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(draft.step == CreateGroupStep.review ? 'Create group' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }

  bool _primaryEnabled(CreateGroupDraft draft) {
    switch (draft.step) {
      case CreateGroupStep.pickMembers:
        return draft.canProceedFromMembers;
      case CreateGroupStep.configure:
        return draft.canProceedFromConfigure ||
            _nameCtrl.text.trim().isNotEmpty ||
            draft.groupName.trim().isNotEmpty;
      case CreateGroupStep.review:
        return true;
    }
  }

  void _onPrimary(CreateGroupDraft draft) {
    switch (draft.step) {
      case CreateGroupStep.pickMembers:
        ref.read(createGroupProvider.notifier).setStep(CreateGroupStep.configure);
        break;
      case CreateGroupStep.configure:
        final name = _nameCtrl.text.trim();
        if (name.isNotEmpty) ref.read(createGroupProvider.notifier).setGroupName(name);
        ref.read(createGroupProvider.notifier).setStep(CreateGroupStep.review);
        break;
      case CreateGroupStep.review:
        _createGroup();
        break;
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final CreateGroupStep step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = CreateGroupStep.values;
    final idx = steps.indexOf(step);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: (i ~/ 2) < idx
                    ? ThemeHelper.getAccentColor(context)
                    : ThemeHelper.getBorderColor(context).withValues(alpha: 0.4),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final done = stepIdx <= idx;
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? ThemeHelper.getAccentColor(context) : ThemeHelper.getBorderColor(context),
            ),
          );
        }),
      ),
    );
  }
}

/// Opaque floating sheet entry point for member pick — opens full flow.
void showCreateGroupMemberSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bg = ThemeHelper.getBackgroundColor(ctx);
      final border = ThemeHelper.getBorderColor(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border.withValues(alpha: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New group',
                    style: TextStyle(
                      color: ThemeHelper.getTextPrimary(ctx),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up a space for your people with custom themes and permissions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ThemeHelper.getTextSecondary(ctx), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateGroupFlowScreen()),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: ThemeHelper.getAccentColor(ctx),
                      foregroundColor: ThemeHelper.getOnAccentColor(ctx),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Get started'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
