import '../../../core/models/message_model.dart';

/// Categorizes chat messages for shared-media profile tabs.
class ChatMessageFilters {
  ChatMessageFilters._();

  static bool isPhotoOrVideo(MessageModel message) {
    if (message.isSharedPost) return false;
    if (message.type == MessageType.image || message.type == MessageType.video) {
      return true;
    }
    return message.effectiveAttachments.isNotEmpty;
  }

  static bool isReelOrLongVideo(MessageModel message) {
    if (!message.isSharedPost) return false;
    final type = (message.sharedPostPreview?.type ?? '').toLowerCase();
    return type == 'reel' || type == 'longvideo' || type == 'long_video';
  }

  static bool isLinkOrFile(MessageModel message) {
    if (isPhotoOrVideo(message) || isReelOrLongVideo(message)) return false;
    if (message.type == MessageType.audio) return true;
    final text = message.text.trim();
    if (RegExp(r'https?://', caseSensitive: false).hasMatch(text)) return true;
    if (message.isSharedPost) return true;
    return false;
  }

  static String? thumbnailUrl(MessageModel message) {
    if (message.mediaUrl != null && message.mediaUrl!.trim().isNotEmpty) {
      return message.mediaUrl;
    }
    final att = message.effectiveAttachments;
    if (att.isNotEmpty && att.first.url.trim().isNotEmpty) {
      return att.first.url;
    }
    return message.sharedPostPreview?.effectiveThumbnailUrl;
  }

  static String linkLabel(MessageModel message) {
    final text = message.text.trim();
    if (text.isNotEmpty) return text;
    if (message.isSharedPost) {
      return message.sharedPostPreview?.caption.trim().isNotEmpty == true
          ? message.sharedPostPreview!.caption.trim()
          : 'Shared post';
    }
    return 'Attachment';
  }
}
