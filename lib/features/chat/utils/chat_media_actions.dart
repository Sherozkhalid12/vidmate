import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/message_model.dart';
import '../widgets/chat_attachment_sheet.dart';

/// Shared media pick / capture helpers for chat screens.
class ChatMediaActions {
  ChatMediaActions._();

  static void showAttachmentPicker(
    BuildContext context, {
    required VoidCallback onGallery,
    required VoidCallback onCamera,
  }) {
    showChatAttachmentSheet(
      context,
      options: [
        ChatAttachmentOption(
          icon: Icons.photo_library_outlined,
          semanticLabel: 'Gallery',
          onTap: onGallery,
        ),
        ChatAttachmentOption(
          icon: Icons.camera_alt_outlined,
          semanticLabel: 'Camera',
          onTap: onCamera,
        ),
      ],
    );
  }

  static Future<void> showCameraSheet(
    BuildContext context, {
    required Future<void> Function() onPhoto,
    required Future<void> Function() onVideo,
  }) async {
    showChatAttachmentSheet(
      context,
      title: 'Camera',
      options: [
        ChatAttachmentOption(
          icon: Icons.photo_camera_outlined,
          semanticLabel: 'Take photo',
          onTap: () => onPhoto(),
        ),
        ChatAttachmentOption(
          icon: Icons.videocam_outlined,
          semanticLabel: 'Record video',
          onTap: () => onVideo(),
        ),
      ],
    );
  }

  static Future<List<({String path, MessageType type})>> pickFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'mkv'],
      allowMultiple: true,
    );
    if (result == null) return [];
    return result.paths
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .map((p) => (path: p, type: inferTypeFromPath(p)))
        .toList();
  }

  static Future<({String path, MessageType type})?> capturePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return null;
    return (path: picked.path, type: MessageType.image);
  }

  static Future<({String path, MessageType type})?> captureVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (picked == null) return null;
    return (path: picked.path, type: MessageType.video);
  }

  static MessageType inferTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.mkv')) {
      return MessageType.video;
    }
    return MessageType.image;
  }

  static bool isLocalPath(String url) {
    if (url.startsWith('http')) return false;
    return File(url).existsSync();
  }
}
