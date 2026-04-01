class LivestreamHostModel {
  final String id;
  final String username;
  final String profilePicture;

  const LivestreamHostModel({
    required this.id,
    required this.username,
    required this.profilePicture,
  });

  factory LivestreamHostModel.fromJson(Map<String, dynamic> json) {
    return LivestreamHostModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      profilePicture:
          json['profilePicture']?.toString() ?? json['profile_picture']?.toString() ?? '',
    );
  }
}

class LivestreamModel {
  final String streamId;
  final String channelName;
  final String title;
  final String description;
  final String thumbnail;
  final String hostId;
  final int hostUid;
  final String status; // live|ended
  final int viewerCount;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final LivestreamHostModel? host;

  const LivestreamModel({
    required this.streamId,
    required this.channelName,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.hostId,
    required this.hostUid,
    required this.status,
    required this.viewerCount,
    this.startedAt,
    this.endedAt,
    this.host,
  });

  factory LivestreamModel.fromJson(Map<String, dynamic> json) {
    final hostJson = json['host'];
    return LivestreamModel(
      streamId: json['streamId']?.toString() ?? json['_id']?.toString() ?? '',
      channelName: json['channelName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      hostId: json['hostId']?.toString() ?? '',
      hostUid: json['hostUid'] is int
          ? (json['hostUid'] as int)
          : int.tryParse(json['hostUid']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? '',
      viewerCount: json['viewerCount'] is int
          ? (json['viewerCount'] as int)
          : int.tryParse(json['viewerCount']?.toString() ?? '') ?? 0,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'].toString())
          : null,
      host: hostJson is Map<String, dynamic> ? LivestreamHostModel.fromJson(hostJson) : null,
    );
  }
}

class LivestreamAgoraAuth {
  final String appId;
  final String channelName;
  final String token;
  final int uid;
  final String role; // publisher|subscriber
  final LivestreamModel stream;

  const LivestreamAgoraAuth({
    required this.appId,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.role,
    required this.stream,
  });
}

