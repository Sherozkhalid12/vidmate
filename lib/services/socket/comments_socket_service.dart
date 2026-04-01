import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/models/comment_model.dart';

/// Handles realtime comment events. Attach to main socket and set callback for new comments.
class CommentsSocketService {
  dynamic _socket;
  void Function(PostComment)? _onNewComment;

  void attach(dynamic socket) {
    _socket = socket;
    if (_socket == null) {
      if (kDebugMode) debugPrint('[CommentsSocket] attach: socket is null');
      return;
    }
    _socket.on('comments:new', _handleNewComment);
    if (kDebugMode) debugPrint('[CommentsSocket] attach: listening for comments:new');
  }

  void detach() {
    if (_socket != null) {
      _socket.off('comments:new');
      _socket = null;
    }
    _onNewComment = null;
  }

  void setOnNewComment(void Function(PostComment) callback) {
    _onNewComment = callback;
  }

  void _handleNewComment(dynamic data) {
    if (_onNewComment == null) return;
    try {
      final map = data is Map<String, dynamic>
          ? data
          : (data is String
              ? (jsonDecode(data) as Map<String, dynamic>? ?? {})
              : null);
      if (map == null || map.isEmpty) return;
      final comment = PostComment.fromJson(Map<String, dynamic>.from(map));
      _onNewComment!(comment);
    } catch (_) {
      // Ignore parse errors
    }
  }
}
