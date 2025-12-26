# Backend Integration Guide

This document outlines all the backend integration points and API services that have been set up in the Flutter app.

## 📋 Table of Contents

1. [API Services](#api-services)
2. [Authentication System](#authentication-system)
3. [User Profile System](#user-profile-system)
4. [Feed System](#feed-system)
5. [Video Upload System](#video-upload-system)
6. [Story System](#story-system)
7. [Chat/Messaging System](#chatmessaging-system)
8. [Search System](#search-system)
9. [Notification System](#notification-system)
10. [Copyright Detection](#copyright-detection)
11. [Ads System](#ads-system)
12. [Analytics System](#analytics-system)

---

## API Services

All API services are located in `lib/core/api/`:

- `api_base.dart` - Base API class with HTTP methods
- `auth_api.dart` - Authentication endpoints
- `user_api.dart` - User profile management
- `feed_api.dart` - Feed posts CRUD operations
- `video_api.dart` - Video upload and management
- `story_api.dart` - Story upload and management
- `chat_api.dart` - Messaging endpoints
- `search_api.dart` - Search functionality
- `notification_api.dart` - Notification management
- `copyright_api.dart` - Copyright detection
- `ads_api.dart` - Ads integration (Magnite/SpotX)
- `analytics_api.dart` - Analytics data

### Base URL Configuration

Update the base URL in `lib/core/api/api_base.dart`:

```dart
static const String baseUrl = 'https://your-api-url.com/v1';
```

---

## 1. Authentication System

### Endpoints Required

- `POST /auth/login` - User login
- `POST /auth/signup` - User registration
- `POST /auth/verify-email` - Email verification
- `POST /auth/forgot-password` - Password reset request
- `POST /auth/reset-password` - Password reset
- `POST /auth/social-login` - Social authentication

### Response Format

```json
{
  "success": true,
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "username": "username",
    "name": "Display Name",
    "email": "email@example.com",
    "avatarUrl": "https://...",
    "bio": "Bio text"
  }
}
```

### Implementation

- Login/Signup screens: `lib/features/auth/login_screen.dart`, `signup_screen.dart`
- Provider: `lib/core/providers/auth_provider.dart`

---

## 2. User Profile System

### Endpoints Required

- `GET /users/:userId` - Get user profile
- `PUT /users/profile` - Update profile
- `POST /users/upload-profile-picture` - Upload profile picture
- `GET /users/:userId/followers` - Get followers list
- `GET /users/:userId/following` - Get following list
- `POST /users/:userId/follow` - Follow user
- `DELETE /users/:userId/follow` - Unfollow user
- `GET /users/settings` - Get user settings
- `PUT /users/settings` - Update settings

### Features

- ✅ Profile edit screen with image upload
- ✅ Name, username, bio update
- ✅ Profile picture upload
- ✅ Followers/Following lists
- ✅ Settings management

### Implementation

- Edit Profile: `lib/features/profile/edit/edit_profile_screen.dart`
- Profile Screen: `lib/features/profile/profile_screen.dart`

---

## 3. Feed System

### Endpoints Required

- `GET /feed` - Get feed posts (with pagination, sorting)
- `POST /feed/posts` - Create new post
- `DELETE /feed/posts/:postId` - Delete post
- `POST /feed/posts/:postId/like` - Like post
- `DELETE /feed/posts/:postId/like` - Unlike post
- `POST /feed/posts/:postId/comments` - Add comment
- `GET /feed/posts/:postId/comments` - Get comments
- `POST /feed/posts/:postId/share` - Share post

### Query Parameters

- `page` - Page number for pagination
- `sortBy` - 'latest' or 'popular'
- `limit` - Number of posts per page

### Features

- ✅ Create post (image/video)
- ✅ Delete post
- ✅ Like/Unlike
- ✅ Comment system
- ✅ Share functionality
- ✅ Feed sorting (latest/popular)

---

## 4. Video Upload System

### Endpoints Required

- `POST /videos/upload` - Upload video file (multipart)
- `POST /videos/upload-thumbnail` - Upload thumbnail
- `GET /videos/:videoId` - Get video details
- `POST /videos/:videoId/views` - Increment view count
- `GET /videos/trending` - Get trending videos
- `GET /videos/:videoId/playback` - Get playback URL
- `DELETE /videos/:videoId` - Delete video
- `GET /videos/:videoId/analytics` - Get video analytics

### Video Types

- `long` - Long-form videos (YouTube style)
- `reel` - Short videos (60 seconds max)
- `post` - Video posts

### Features

- ✅ Video compression (client-side)
- ✅ Thumbnail generation
- ✅ Copyright check before upload
- ✅ Progress tracking
- ✅ S3 upload ready
- ✅ View count tracking
- ✅ Trending algorithm support

### Implementation

- Upload Screen: `lib/features/upload/video_upload_screen.dart`

---

## 5. Story System

### Endpoints Required

- `POST /stories/upload` - Upload story (multipart)
- `GET /stories` - Get all stories
- `GET /stories/user/:userId` - Get user stories
- `GET /stories/:storyId/viewers` - Get story viewers
- `DELETE /stories/:storyId` - Delete story
- `POST /stories/:storyId/view` - Mark as viewed

### Features

- ✅ Story upload (image/video)
- ✅ Privacy settings
- ✅ Auto-delete after 24 hours (backend)
- ✅ Viewer list
- ✅ View tracking

### Implementation

- Upload Screen: `lib/features/upload/story_upload_screen.dart`

---

## 6. Chat/Messaging System

### Endpoints Required

- `GET /chats` - Get chat list
- `POST /chats` - Create new chat
- `GET /chats/:chatId/messages` - Get messages
- `POST /chats/:chatId/messages` - Send text message
- `POST /chats/:chatId/messages/media` - Send media message
- `POST /chats/:chatId/messages/:messageId/read` - Mark as read
- `GET /users/:userId/online-status` - Get online status
- `GET /users/:userId/last-seen` - Get last seen

### Features

- ✅ One-to-one chat
- ✅ Media messages (image/video)
- ✅ Online status
- ✅ Last seen
- ✅ Typing indicator (WebSocket)
- ✅ Message read receipts
- ✅ Chat history

### WebSocket Integration

For real-time features, implement WebSocket connection:

```dart
// Example WebSocket setup
final channel = WebSocketChannel.connect(
  Uri.parse('wss://your-api-url.com/ws'),
);
```

---

## 7. Search System

### Endpoints Required

- `GET /search/users` - Search users
- `GET /search/hashtags` - Search hashtags
- `GET /search/trending/hashtags` - Get trending hashtags
- `GET /search/trending` - Get trending content
- `GET /search/recommendations` - Get recommendations

### Query Parameters

- `q` - Search query
- `page` - Page number
- `type` - Content type filter

### Features

- ✅ User search
- ✅ Hashtag search
- ✅ Trending hashtags
- ✅ Trending content
- ✅ Recommendations

---

## 8. Notification System

### Endpoints Required

- `GET /notifications` - Get notifications
- `POST /notifications/:notificationId/read` - Mark as read
- `POST /notifications/read-all` - Mark all as read
- `DELETE /notifications/:notificationId` - Delete notification
- `GET /notifications/settings` - Get notification settings
- `PUT /notifications/settings` - Update settings

### Notification Types

- `like` - Post/video liked
- `comment` - New comment
- `follow` - New follower
- `message` - New message

### Firebase Cloud Messaging (FCM)

For push notifications:

1. Add Firebase configuration files
2. Initialize Firebase in `main.dart`
3. Handle FCM tokens and notifications

---

## 9. Copyright Detection

### Endpoints Required

- `POST /copyright/check-video` - Check video for copyright
- `POST /copyright/check-audio` - Check audio for copyright
- `POST /copyright/report` - Report violation

### Response Format

```json
{
  "success": true,
  "hasCopyright": false,
  "matches": [],
  "confidence": 0.95
}
```

### Features

- ✅ Automatic video check
- ✅ Duplicate content detection
- ✅ Audio/video matching
- ✅ Copyright violation reporting

---

## 10. Ads System (Magnite/SpotX)

### Endpoints Required

- `GET /ads/request` - Request ad
- `POST /ads/:adId/impression` - Track impression
- `POST /ads/:adId/click` - Track click
- `GET /ads/cpm` - Get CPM data
- `GET /ads/revenue` - Get revenue data

### Ad Types

- `banner` - Banner ads
- `video` - Video ads
- `interstitial` - Interstitial ads

### Features

- ✅ Ad request API
- ✅ CPM tracking
- ✅ Video ads integration
- ✅ Revenue calculation

---

## 11. Analytics System

### Endpoints Required

- `GET /analytics/dau` - Daily active users
- `GET /analytics/views` - Views count (1M views calculation)
- `GET /analytics/watch-time` - Watch time
- `GET /analytics/retention` - Retention data
- `GET /analytics/server-load` - Server load
- `GET /analytics/users/:userId` - User analytics
- `GET /analytics/content/:contentId` - Content analytics

### Features

- ✅ Daily active users tracking
- ✅ 1M views calculation
- ✅ Watch time analytics
- ✅ Retention metrics
- ✅ Server load monitoring
- ✅ User analytics
- ✅ Content analytics

---

## State Management

Provider is used for state management. Set up providers in `main.dart`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    // Add other providers
  ],
  child: MyApp(),
)
```

---

## File Uploads

All file uploads use multipart/form-data:

- Profile pictures: Max 512x512, JPEG/PNG
- Videos: Compressed client-side before upload
- Thumbnails: Auto-generated or manually uploaded
- Stories: Image or video (max 15 seconds)

---

## Error Handling

All API calls return:

```json
{
  "success": true/false,
  "error": "Error message if failed",
  "data": { ... }
}
```

---

## Authentication

JWT tokens are stored in SharedPreferences and sent in headers:

```
Authorization: Bearer <token>
```

---

## Next Steps

1. **Backend Development**: Implement all endpoints listed above
2. **Database Setup**: MongoDB/PostgreSQL for data storage
3. **File Storage**: AWS S3 for media files
4. **Real-time**: WebSocket server for chat
5. **Push Notifications**: Firebase Cloud Messaging setup
6. **Copyright Detection**: Integrate with content ID service
7. **Ads Integration**: Connect with Magnite/SpotX
8. **Analytics**: Set up analytics collection and processing

---

## Testing

Replace mock data services with real API calls:

1. Update `MockDataService` to use API services
2. Test all endpoints
3. Handle loading states
4. Implement error handling UI
5. Add retry mechanisms

---

**Note**: All API services are ready for backend integration. Simply update the base URL and implement the backend endpoints according to the specifications above.


