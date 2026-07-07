import 'package:flutter/foundation.dart';

@immutable
class BlockedUserModel {
  const BlockedUserModel({
    required this.id,
    required this.username,
    this.profilePicture,
  });

  final String id;
  final String username;
  final String? profilePicture;

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? '').toString();
    final username = (json['username'] ?? json['name'] ?? '').toString();
    final pic = (json['profilePicture'] ?? json['avatar'] ?? '').toString();
    return BlockedUserModel(
      id: id,
      username: username,
      profilePicture: pic.isEmpty ? null : pic,
    );
  }
}
