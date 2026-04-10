/// Single conversation item from getConversations API.
class ChatConversationItem {
  final String conversationId;
  final ChatConversationUser user;
  final ChatConversationGroup? group;
  final bool isGroup;
  final String lastMessage;
  final String lastMessageType; // text|image|video|media|post|deleted
  final DateTime lastMessageAt;

  ChatConversationItem({
    required this.conversationId,
    required this.user,
    this.group,
    this.isGroup = false,
    required this.lastMessage,
    this.lastMessageType = 'text',
    required this.lastMessageAt,
  });

  static String _str(dynamic v) => v?.toString() ?? '';
  static DateTime _date(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    final parsed = DateTime.tryParse(v.toString());
    return parsed ?? DateTime.now();
  }

  factory ChatConversationItem.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final groupJson = json['group'];
    final conversationId = _str(json['conversationId']);
    final lastMessageType = _str(json['lastMessageType'] ?? 'text');
    final group = groupJson is Map<String, dynamic>
        ? ChatConversationGroup.fromJson(groupJson)
        : (groupJson is Map
            ? ChatConversationGroup.fromJson(
                Map<String, dynamic>.from(groupJson),
              )
            : null);
    final isGroup = group != null || conversationId.startsWith('group:');
    final rawLast = _str(json['lastMessage']);
    return ChatConversationItem(
      conversationId: conversationId,
      user: userJson is Map<String, dynamic>
          ? ChatConversationUser.fromJson(userJson)
          : ChatConversationUser(id: '', username: '', profilePicture: ''),
      group: group,
      isGroup: isGroup,
      lastMessage: rawLast.isNotEmpty
          ? rawLast
          : _fallbackLastMessage(lastMessageType),
      lastMessageType: lastMessageType.isNotEmpty ? lastMessageType : 'text',
      lastMessageAt: _date(json['lastMessageAt']),
    );
  }

  static String _fallbackLastMessage(String type) {
    switch (type) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'media':
        return 'Media';
      case 'post':
        return 'Shared a post';
      case 'deleted':
        return 'Message deleted';
      default:
        return '';
    }
  }

  Map<String, dynamic> toJson() => {
        'conversationId': conversationId,
        'user': user.toJson(),
        if (group != null) 'group': group!.toJson(),
        'isGroup': isGroup,
        'lastMessage': lastMessage,
        'lastMessageType': lastMessageType,
        'lastMessageAt': lastMessageAt.toIso8601String(),
      };
}

class ChatConversationUser {
  final String id;
  final String username;
  final String profilePicture;

  ChatConversationUser({
    required this.id,
    required this.username,
    required this.profilePicture,
  });

  static String _str(dynamic v) => v?.toString() ?? '';

  factory ChatConversationUser.fromJson(Map<String, dynamic> json) {
    return ChatConversationUser(
      id: _str(json['id'] ?? json['_id']),
      username: _str(json['username'] ?? json['name']),
      profilePicture: _str(
        json['profilePicture'] ??
            json['profile_picture'] ??
            json['image'] ??
            json['avatarUrl'] ??
            json['avatar'] ??
            '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'profilePicture': profilePicture,
      };
}

class ChatConversationGroup {
  final String id;
  final String name;
  final String avatarUrl;

  ChatConversationGroup({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });

  static String _str(dynamic v) => v?.toString() ?? '';

  factory ChatConversationGroup.fromJson(Map<String, dynamic> json) {
    return ChatConversationGroup(
      id: _str(json['_id'] ?? json['id'] ?? json['groupId']),
      name: _str(json['name'] ?? json['groupName'] ?? json['title']),
      avatarUrl: _str(json['avatar'] ?? json['avatarUrl'] ?? json['image'] ?? json['groupAvatar'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
      };
}
