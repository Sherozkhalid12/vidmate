import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_bubble.dart';
import '../../services/chat/chat_service.dart';

/// Resolves missing shared-post preview data (thumbnail, type) for chat bubbles.
final sharedPostPreviewResolverProvider =
    FutureProvider.autoDispose.family<PostPreview?, String>((ref, postId) async {
  if (postId.isEmpty) return null;
  final result = await ChatService().resolvePostPreview(postId: postId);
  if (!result.success || result.data == null) return null;
  return PostPreview.fromJson(result.data!);
});
