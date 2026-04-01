/// Models for call signaling events coming from socket.
class CallUserModel {
  final String id;
  final String username;
  final String profilePicture;

  const CallUserModel({
    required this.id,
    required this.username,
    required this.profilePicture,
  });

  factory CallUserModel.fromJson(Map<String, dynamic> json) {
    return CallUserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      profilePicture:
          json['profilePicture']?.toString() ?? json['profile_picture']?.toString() ?? '',
    );
  }
}

class CallModel {
  final String callId;
  final String channelName;
  final String? token;
  final String callerId;
  final String receiverId;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final CallUserModel? caller;
  final CallUserModel? receiver;

  const CallModel({
    required this.callId,
    required this.channelName,
    this.token,
    required this.callerId,
    required this.receiverId,
    required this.status,
    this.startTime,
    this.endTime,
    this.caller,
    this.receiver,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    final callerJson = json['caller'];
    final receiverJson = json['receiver'];
    return CallModel(
      callId: json['callId']?.toString() ?? json['id']?.toString() ?? '',
      channelName: json['channelName']?.toString() ?? '',
      token: json['token']?.toString(),
      callerId: json['callerId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'].toString())
          : null,
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'].toString())
          : null,
      caller: callerJson is Map<String, dynamic>
          ? CallUserModel.fromJson(callerJson)
          : null,
      receiver: receiverJson is Map<String, dynamic>
          ? CallUserModel.fromJson(receiverJson)
          : null,
    );
  }
}

class IncomingCallPayload {
  final String receiverId;
  final String callerId;
  final String? token;
  final String? appId;
  final int? uid;
  final CallModel call;

  const IncomingCallPayload({
    required this.receiverId,
    required this.callerId,
    this.token,
    this.appId,
    this.uid,
    required this.call,
  });

  factory IncomingCallPayload.fromJson(Map<String, dynamic> json) {
    final callJson = json['call'] as Map<String, dynamic>? ?? const {};
    return IncomingCallPayload(
      receiverId: json['receiverId']?.toString() ?? callJson['receiverId']?.toString() ?? '',
      callerId: json['callerId']?.toString() ?? callJson['callerId']?.toString() ?? '',
      token: json['token']?.toString() ?? callJson['token']?.toString(),
      appId: json['appId']?.toString() ?? callJson['appId']?.toString(),
      uid: json['uid'] is int
          ? (json['uid'] as int)
          : int.tryParse(json['uid']?.toString() ?? ''),
      call: CallModel.fromJson(callJson),
    );
  }
}

class CallEndedPayload {
  final String callerId;
  final String receiverId;
  final String endedBy;
  final CallModel call;

  const CallEndedPayload({
    required this.callerId,
    required this.receiverId,
    required this.endedBy,
    required this.call,
  });

  factory CallEndedPayload.fromJson(Map<String, dynamic> json) {
    final callJson = json['call'] as Map<String, dynamic>? ?? const {};
    return CallEndedPayload(
      callerId: json['callerId']?.toString() ?? callJson['callerId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? callJson['receiverId']?.toString() ?? '',
      endedBy: json['endedBy']?.toString() ?? '',
      call: CallModel.fromJson(callJson),
    );
  }
}

/// Socket payload: calls:accepted
class CallAcceptedPayload {
  final String callerId;
  final String receiverId;
  final String acceptedBy;
  final String? token;
  final CallModel call;

  const CallAcceptedPayload({
    required this.callerId,
    required this.receiverId,
    required this.acceptedBy,
    this.token,
    required this.call,
  });

  factory CallAcceptedPayload.fromJson(Map<String, dynamic> json) {
    final callJson = json['call'] as Map<String, dynamic>? ?? const {};
    return CallAcceptedPayload(
      callerId: json['callerId']?.toString() ?? callJson['callerId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? callJson['receiverId']?.toString() ?? '',
      acceptedBy: json['acceptedBy']?.toString() ?? '',
      token: json['token']?.toString() ?? callJson['token']?.toString(),
      call: CallModel.fromJson(callJson),
    );
  }
}

/// Socket payload: calls:rejected
class CallRejectedPayload {
  final String callerId;
  final String receiverId;
  final String rejectedBy;
  final String? token;
  final CallModel call;

  const CallRejectedPayload({
    required this.callerId,
    required this.receiverId,
    required this.rejectedBy,
    this.token,
    required this.call,
  });

  factory CallRejectedPayload.fromJson(Map<String, dynamic> json) {
    final callJson = json['call'] as Map<String, dynamic>? ?? const {};
    return CallRejectedPayload(
      callerId: json['callerId']?.toString() ?? callJson['callerId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? callJson['receiverId']?.toString() ?? '',
      rejectedBy: json['rejectedBy']?.toString() ?? '',
      token: json['token']?.toString() ?? callJson['token']?.toString(),
      call: CallModel.fromJson(callJson),
    );
  }
}

