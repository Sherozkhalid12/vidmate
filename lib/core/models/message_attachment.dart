/// A single media attachment on a chat message.
class MessageAttachment {
  final String url;
  final String mediaType; // image | video

  const MessageAttachment({
    required this.url,
    this.mediaType = 'image',
  });

  bool get isVideo {
    final t = mediaType.trim().toLowerCase();
    return t == 'video' || t.contains('video');
  }

  bool get isImage => !isVideo;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      url: (json['url'] ?? json['link'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? json['type'] ?? 'image').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'mediaType': mediaType,
      };
}
