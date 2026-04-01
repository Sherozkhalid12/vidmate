class UserPreferencesModel {
  final bool autoplayvideos;
  final bool notificationsEnabled;
  final bool downloadOverWifi;
  final bool privateAccount;
  final bool showActivityStatus;
  final bool allowComments;
  final bool allowLikes;
  final bool allowShares;
  final bool allowStoryReplies;

  const UserPreferencesModel({
    this.autoplayvideos = true,
    this.notificationsEnabled = true,
    this.downloadOverWifi = true,
    this.privateAccount = false,
    this.showActivityStatus = true,
    this.allowComments = true,
    this.allowLikes = true,
    this.allowShares = true,
    this.allowStoryReplies = true,
  });

  UserPreferencesModel copyWith({
    bool? autoplayvideos,
    bool? notificationsEnabled,
    bool? downloadOverWifi,
    bool? privateAccount,
    bool? showActivityStatus,
    bool? allowComments,
    bool? allowLikes,
    bool? allowShares,
    bool? allowStoryReplies,
  }) {
    return UserPreferencesModel(
      autoplayvideos: autoplayvideos ?? this.autoplayvideos,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      downloadOverWifi: downloadOverWifi ?? this.downloadOverWifi,
      privateAccount: privateAccount ?? this.privateAccount,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      allowComments: allowComments ?? this.allowComments,
      allowLikes: allowLikes ?? this.allowLikes,
      allowShares: allowShares ?? this.allowShares,
      allowStoryReplies: allowStoryReplies ?? this.allowStoryReplies,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoplayvideos': autoplayvideos,
      'notificationsEnabled': notificationsEnabled,
      'downloadOverWifi': downloadOverWifi,
      'privateAccount': privateAccount,
      'showActivityStatus': showActivityStatus,
      'allowComments': allowComments,
      'allowLikes': allowLikes,
      'allowShares': allowShares,
      'allowStoryReplies': allowStoryReplies,
    };
  }

  factory UserPreferencesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserPreferencesModel();
    return UserPreferencesModel(
      autoplayvideos: json['autoplayvideos'] == true,
      notificationsEnabled: json['notificationsEnabled'] != false,
      downloadOverWifi: json['downloadOverWifi'] != false,
      privateAccount: json['privateAccount'] == true,
      showActivityStatus: json['showActivityStatus'] != false,
      allowComments: json['allowComments'] != false,
      allowLikes: json['allowLikes'] != false,
      allowShares: json['allowShares'] != false,
      allowStoryReplies: json['allowStoryReplies'] != false,
    );
  }
}
