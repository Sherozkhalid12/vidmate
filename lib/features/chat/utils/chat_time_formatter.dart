/// Shared timestamp formatting for chat list, bubbles, and read receipts.
class ChatTimeFormatter {
  ChatTimeFormatter._();

  /// Conversation list row — compact, calendar-aware.
  static String listTimestamp(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(messageDay).inDays;

    if (diff == 0) {
      return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    }
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[local.weekday - 1];
    }
    if (local.year == now.year) {
      return '${local.day}/${local.month}';
    }
    return '${local.day}/${local.month}/${local.year % 100}';
  }

  /// In-bubble relative time.
  static String bubbleTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return listTimestamp(time);
  }

  /// Read / seen footer under the input bar (DM).
  static String seenStatus({
    required bool isRead,
    DateTime? readAt,
    bool peerIsActive = false,
  }) {
    if (peerIsActive) return 'Active now';
    if (isRead) {
      if (readAt == null) return 'Seen';
      final diff = DateTime.now().difference(readAt);
      if (diff.inSeconds < 60) return 'Seen just now';
      if (diff.inMinutes < 60) return 'Seen ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Seen ${diff.inHours}h ago';
      return 'Seen ${listTimestamp(readAt)}';
    }
    return 'Delivered';
  }

  /// Group read summary for outgoing messages.
  static String groupReadSummary({
    required int readCount,
    required int memberCount,
  }) {
    if (memberCount <= 1) return 'Sent';
    if (readCount <= 0) return 'Delivered';
    if (readCount >= memberCount - 1) return 'Seen by everyone';
    return 'Seen by $readCount';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
