import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/theme_helper.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider_riverpod.dart';

/// Edit profile screen – app design, theme-aware, uses updateUser PATCH API.
class EditProfileScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  File? _profilePicture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.user.username.isNotEmpty
        ? widget.user.username
        : widget.user.displayName;
    _bioController.text = widget.user.bio ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePicture() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
          decoration: BoxDecoration(
            color: ThemeHelper.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ThemeHelper.getBorderColor(context),
              width: 1,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.photo_library,
                      color: ThemeHelper.getAccentColor(context),
                    ),
                    title: Text(
                      'Choose from Gallery',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.camera_alt,
                      color: ThemeHelper.getAccentColor(context),
                    ),
                    title: Text(
                      'Take Photo',
                      style: TextStyle(
                        color: ThemeHelper.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (source == null || !mounted) return;

      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _profilePicture = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: TextStyle(
                color: ThemeHelper.getOnAccentColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: ThemeHelper.getAccentColor(context),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final username = _usernameController.text.trim();
    final value = username.isEmpty
        ? (widget.user.username.isNotEmpty ? widget.user.username : widget.user.displayName)
        : username;
    final bio = _bioController.text.trim();

    final success = await ref.read(authProvider.notifier).updateUser(
          userId: widget.user.id,
          name: value,
          username: value,
          bio: bio,
          profilePicture: _profilePicture,
        );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated successfully!',
            style: TextStyle(
              color: ThemeHelper.getOnAccentColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: ThemeHelper.getAccentColor(context),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      final err = ref.read(authProvider).error ?? 'Update failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err,
            style: TextStyle(
              color: ThemeHelper.getOnAccentColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: ThemeHelper.getAccentColor(context),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfilePicture(),
                      const SizedBox(height: 32),
                      _buildField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _bioController,
                        label: 'Bio',
                        icon: Icons.edit_note,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 32),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: ThemeHelper.getTextPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Edit profile',
              style: TextStyle(
                color: ThemeHelper.getTextPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Center(
      child: GestureDetector(
        onTap: _pickProfilePicture,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ThemeHelper.getBorderColor(context),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ThemeHelper.getAccentColor(context).withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: _profilePicture != null
                    ? Image.file(
                        _profilePicture!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Image.network(
                        widget.user.avatarUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: ThemeHelper.getSurfaceColor(context),
                            child: Icon(
                              Icons.person,
                              size: 56,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          );
                        },
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThemeHelper.getAccentColor(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ThemeHelper.getBackgroundColor(context),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: ThemeHelper.getOnAccentColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: ThemeHelper.getTextPrimary(context),
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: ThemeHelper.getTextSecondary(context),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            icon,
            color: ThemeHelper.getTextSecondary(context),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeHelper.getAccentColor(context),
          foregroundColor: ThemeHelper.getOnAccentColor(context),
          disabledBackgroundColor: ThemeHelper.getAccentColor(context).withOpacity(0.5),
          disabledForegroundColor: ThemeHelper.getOnAccentColor(context).withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ThemeHelper.getOnAccentColor(context),
                ),
              )
            : Text(
                'Save changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
