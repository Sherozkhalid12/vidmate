import 'user_model.dart';

/// Story model
class StoryModel {
  final String id;
  final UserModel author;
  final String mediaUrl;
  final bool isVideo;
  final DateTime createdAt;
  final bool isViewed;

  StoryModel({
    required this.id,
    required this.author,
    required this.mediaUrl,
    this.isVideo = false,
    required this.createdAt,
    this.isViewed = false,
  });
}


