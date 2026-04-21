/// Centralized API base URL and endpoints.
/// Change base URL or endpoints here to reflect everywhere automatically.
/// No hardcoded URLs inside services.
class ApiConstants {
  ApiConstants._();

  /// Main API base URL
  static const String baseUrl = 'http://52.205.129.217:3001/api/v1';

  /// Socket.IO server URL (same host as API). Used for realtime comments, likes, chat.
  static String get socketUrl => 'http://52.205.129.217:3001';

  // Auth
  static const String authSignup = '/auth/signup';
  static const String authLogin = '/auth/login';
  /// PATCH update user – path: /auth/update/:userId; body: multipart form data.
  static String authUpdateUser(String userId) => '/auth/update/$userId';
  static const String authSendEmailOTP = '/auth/sendEmailOTP';
  static const String authVerifyEmailOtp = '/auth/verifyEmailOtp';
  static const String authUpdatePreferences = '/auth/updatePreferences';
  static String authGetUserById(String id) => '/auth/getUserByID/$id';
  static String authUserById(String id) => '/auth/user/$id';

  // Forget password
  static const String forgetPasswordSendOtp =
      '/forgetPassword/sendForgetPasswordOTP';
  static const String forgetPasswordVerifyOtp =
      '/forgetPassword/verifyForgetPasswordOTP';
  static const String forgetPasswordReset =
      '/forgetPassword/resetPassword';

  // Posts
  /// Create post (photo post OR video post). Backend endpoint: POST /create
  static const String postCreate = '/post/create';
  /// All users' posts (home feed).
  static const String postList = '/post';
  /// Posts for a specific user (profile). Replace :id with userId.
  static String postByUser(String userId) => '/post/$userId';
  /// User posts endpoint. Replace :id with userId.
  static String userPosts(String userId) => '/post/userPosts/$userId';

  // Stories
  static const String storyCreate = '/post/story/create';
  static const String storyList = '/post/stories';
  static String storyByUser(String userId) => '/post/stories/user/$userId';

  // Reels
  /// Create reel. Backend endpoint: POST /post/reel/create
  static const String reelCreate = '/post/reel/create';
  static const String reelList = '/post/reels';
  static String reelByUser(String userId) => '/post/reels/user/$userId';

  // Long videos
  /// Create long video. Backend endpoint: POST /post/long-video/create
  static const String longVideoCreate = '/post/long-video/create';
  static const String longVideoList = '/post/long-videos';
  static String longVideoByUser(String userId) => '/post/long-videos/user/$userId';

  // Post interactions
  static String postLike(String postId) => '/post/like/$postId';
  static const String postComment = '/post/comment';
  static String postComments(String postId) => '/post/comments/$postId';
  static String postSave(String postId) => '/post/save/$postId';
  static const String postGetSavedPosts = '/post/get/savedPosts';

  // Post actions
  /// DELETE post by id — full URL: `{baseUrl}/post/:id` (i.e. /api/v1/post/:id).
  static String postDelete(String postId) => '/post/$postId';
  static String postReport(String postId) => '/post/report/$postId';
  static String postShare(String postId) => '/post/share/$postId';

  // FCM Device tokens
  static const String authSetDeviceToken = '/auth/setDeviceToken';
  static const String authRemoveDeviceToken = '/auth/removeDeviceToken';

  // Chat
  /// Base path: /api/v1/chat (ApiConstants.baseUrl already includes /api/v1)
  static const String chatSend = '/chat/send';
  static const String chatSharePost = '/chat/share-post';
  static const String chatResolvePost = '/chat/resolve-post';
  static const String chatForward = '/chat/forward';
  static const String chatDelete = '/chat/delete';
  static const String chatGroupCreate = '/chat/group/create';
  static String chatGroupMessages(String groupId) => '/chat/group/$groupId/messages';
  static String chatMessages(String userId) => '/chat/messages/$userId';
  static const String chatConversations = '/chat/conversations';
  static const String chatShareableUsers = '/chat/shareable-users';

  // Music
  /// Music library – paginated list of tracks.
  static const String musicList = '/music';

  /// Deezer curated playlists + songs (optional query: limit, playlistLimit).
  static const String musicDeezerPlaylists = '/music/deezer/playlists';

  /// Deezer playlist by id (optional query: limit).
  static String musicDeezerPlaylist(String playlistId) =>
      '/music/deezer/playlists/$playlistId';

  // Notifications
  /// GET – current user's notifications list.
  static const String notificationsList = '/notifications';
  /// PATCH – mark a single notification as read by id.
  static String notificationMarkRead(String id) =>
      '/notifications/read/$id';
  /// PATCH – mark all notifications as read.
  static const String notificationsMarkAllRead = '/notifications/read-all';

  // Follow
  /// PATCH – follow a user by id.
  static String followUser(String id) => '/follow/$id';
  /// PATCH – unfollow a user by id.
  static String unfollowUser(String id) => '/follow/unfollow/$id';
  /// GET – current user's following list.
  static const String getFollowings = '/follow/following';
  /// GET – current user's followers list.
  static const String getFollowers = '/follow/followers';
  static const String getIncomingFollowRequests = '/follow/requests/incoming';
  static const String getOutgoingFollowRequests = '/follow/requests/outgoing';
  static String acceptFollowRequest(String requestId) =>
      '/follow/requests/$requestId/accept';
  static String rejectFollowRequest(String requestId) =>
      '/follow/requests/$requestId/reject';

  // Calls (Agora)
  static const String callsAgoraToken = '/calls/agora/token';
  static const String callsAccept = '/calls/accept';
  static String callsAcceptById(String id) => '/calls/accept/$id';
  static const String callsReject = '/calls/reject';
  static String callsRejectById(String id) => '/calls/reject/$id';
  static const String callsEnd = '/calls/end';
  static String callsEndById(String id) => '/calls/end/$id';

  // Livestream (Agora)
  static const String liveStart = '/calls/live/start';
  static const String liveToken = '/calls/live/token';
  static const String liveActive = '/calls/live/active';
  static String liveById(String id) => '/calls/live/$id';
  static const String liveJoin = '/calls/live/join';
  static String liveJoinById(String id) => '/calls/live/join/$id';
  static const String liveLeave = '/calls/live/leave';
  static String liveLeaveById(String id) => '/calls/live/leave/$id';
  static const String liveEnd = '/calls/live/end';
  static String liveEndById(String id) => '/calls/live/end/$id';
  static const String liveEndAll = '/calls/live/end-all';

  // Livestream social (chat/likes)
  static String liveMessageById(String id) => '/calls/live/message/$id';
  static const String liveMessage = '/calls/live/message';
  static String liveMessagesById(String id) => '/calls/live/$id/messages';
  static String liveLikeById(String id) => '/calls/live/like/$id';
  static const String liveLike = '/calls/live/like';
  static String liveLikesById(String id) => '/calls/live/$id/likes';

  // Search
  /// Search base path: /api/v1/search
  static const String search = '/search';
}
