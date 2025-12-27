import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/theme_helper.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/models/user_model.dart';

/// Edit profile screen
class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  File? _profilePicture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.displayName;
    _usernameController.text = widget.user.username;
    _bioController.text = widget.user.bio ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePicture() async {
    try {
      // Show source selection dialog
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: context.secondaryBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(color: context.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
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
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: ThemeHelper.getAccentColor(context).withOpacity(0.9), // Theme-aware accent color
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'OK',
              textColor: context.textPrimary,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    // Simulate profile update (frontend only - no backend)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          backgroundColor: ThemeHelper.getAccentColor(context), // Theme-aware accent color
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text('Edit Profile'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile picture
            Center(
              child: GestureDetector(
                onTap: _pickProfilePicture,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ThemeHelper.getAccentGradient(context), // Theme-aware accent gradient
                        boxShadow: [
                          BoxShadow(
                            color: ThemeHelper.getAccentColor(context).withOpacity(0.3), // Theme-aware accent with opacity
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: _profilePicture != null
                            ? Image.file(
                                _profilePicture!,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                widget.user.avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: context.surfaceColor,
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: context.textSecondary,
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getAccentColor(context), // Theme-aware accent color
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Name field
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: context.textSecondary),
                  prefixIcon: Icon(Icons.person, color: context.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Username field
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _usernameController,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: context.textSecondary),
                  prefixIcon: Icon(Icons.alternate_email, color: context.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Bio field
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _bioController,
                maxLines: 4,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(color: context.textSecondary),
                  prefixIcon: Icon(Icons.edit, color: context.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Save button
            GlassButton(
              text: _isSaving ? 'Saving...' : 'Save Changes',
              onPressed: _isSaving ? null : _saveProfile,
              isLoading: _isSaving,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

