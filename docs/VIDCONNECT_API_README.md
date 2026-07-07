# VidConnect — Complete API Reference

Master backend documentation for chat, groups, media, calls, blocking, view counts, and reel soundtracks.

| | |
|---|---|
| **Base URL** | `/api/v1` |
| **Auth** | `Authorization: Bearer <JWT>` on all endpoints below |
| **Success** | `{ "success": true, "data": { ... } }` or `{ "success": true, ... }` |
| **Error** | `{ "success": false, "code": "OPTIONAL", "message": "..." }` |
| **Idempotency** | Header `Idempotency-Key` or body `clientMessageId` / `clientRequestId` |

**Route prefixes**

| Module | Prefix |
|--------|--------|
| Auth (block/unblock) | `/api/v1/auth` |
| Posts (reels, stories, views) | `/api/v1/post` |
| Chat & groups | `/api/v1/chat` |
| Media uploads | `/api/v1/media` |
| Calls | `/api/v1/calls` |

> **Agora** is required only for `/calls/*` voice/video and `/calls/live/*`. Chat, groups, and media work without Agora.

---

## Table of contents

1. [Chat messaging](#1-chat-messaging)
2. [Conversations & history](#2-conversations--history)
3. [Group management](#3-group-management)
4. [Media upload sessions](#4-media-upload-sessions)
5. [Calls (v2)](#5-calls-v2)
6. [Legacy & utility](#6-legacy--utility)
7. [Socket events](#7-socket-events)
8. [Background jobs](#8-background-jobs)
9. [Environment variables](#9-environment-variables)
10. [Multi-media collage flow](#10-multi-media-collage-flow)
11. [Block & unblock users](#11-block--unblock-users)
12. [View count](#12-view-count)
13. [Reel soundtrack](#13-reel-soundtrack)
14. [API checklist](#14-api-checklist)

---

## 1. Chat messaging

### POST `/chat/send`

Send text, shared post, multipart files (legacy), or pre-uploaded `mediaAssetIds`.

**Direct text**
```json
{
  "receiverId": "userObjectId",
  "clientMessageId": "device-uuid",
  "message": "Hello",
  "messageType": "text"
}
```

**Group multi-media (collage)**
```json
{
  "groupId": "groupObjectId",
  "clientMessageId": "device-uuid",
  "message": "Trip photos",
  "messageType": "media",
  "mediaAssetIds": ["assetId1", "assetId2"]
}
```

**Response `201`**
```json
{
  "success": true,
  "message": "Message sent successfully",
  "chat": {
    "_id": "messageObjectId",
    "conversationId": "userA_userB",
    "clientMessageId": "device-uuid",
    "senderId": "senderId",
    "receiverId": "",
    "groupId": "groupObjectId",
    "message": "Trip photos",
    "messageType": "media",
    "attachments": [
      {
        "id": "att-assetId1",
        "mediaAssetId": "assetId1",
        "mediaType": "image",
        "url": "https://cdn.example.com/chat/images/...",
        "thumbnailUrl": "https://cdn.example.com/...-thumb.webp",
        "previewUrl": null,
        "width": 1440,
        "height": 1800,
        "durationMs": null,
        "sizeBytes": 420112,
        "mimeType": "image/jpeg",
        "processingState": "ready",
        "sortOrder": 0
      }
    ],
    "readBy": ["senderId"],
    "deletedFor": [],
    "isDeletedForEveryone": false,
    "mediaProcessingState": "ready",
    "createdAt": "2026-06-30T12:00:00.000Z",
    "updatedAt": "2026-06-30T12:00:00.000Z",
    "sender": {
      "id": "senderId",
      "username": "ali",
      "profilePicture": "https://cdn.example.com/avatar.jpg"
    }
  },
  "data": { "chat": { } }
}
```

| Notes | |
|-------|---|
| Idempotent retry | Returns `200` with same message if `clientMessageId` exists |
| `messageType` | Auto: all images → `image`, all videos → `video`, mixed → `media` |
| Multipart fallback | Send files via `multipart/form-data` (any field name) |
| Blocked users | New DMs to/from blocked users return `403` (`USER_BLOCKED`). Existing threads remain readable. |

---

### PATCH `/chat/messages/:messageId/read`

**Body**
```json
{
  "conversationId": "conversationId",
  "lastReadMessageId": "messageObjectId"
}
```

**Response `200`**
```json
{
  "success": true,
  "data": {
    "conversationId": "conversationId",
    "lastReadMessageId": "messageObjectId",
    "lastReadAt": "2026-06-30T12:00:00.000Z"
  }
}
```

---

### POST `/chat/forward`

**Body**
```json
{
  "messageId": "messageObjectId",
  "receiverId": "userObjectId",
  "groupId": null,
  "clientMessageId": "device-uuid"
}
```

**Response `201`:** Same `chat` shape as `/chat/send`.

---

### POST `/chat/delete`

**Body**
```json
{
  "messageId": "messageObjectId",
  "deleteForEveryone": true
}
```

**Response `200`**
```json
{ "success": true, "message": "Message deleted for everyone" }
```

---

### POST `/chat/share-post`

**Body:** `{ "receiverId" | "groupId", "postId" | "postLink", "message": "optional" }`

**Response `201`:** `{ "success": true, "chat": { ... } }`

---

## 2. Conversations & history

### GET `/chat/conversations`

**Query:** `limit` (default 20), `cursor`, `includeMuted=true|false`

**Response `200`**
```json
{
  "success": true,
  "data": {
    "conversations": [
      {
        "conversationId": "group:abc123",
        "type": "group",
        "isGroup": true,
        "user": null,
        "group": {
          "id": "groupObjectId",
          "name": "Design Team",
          "avatarUrl": "https://cdn.example.com/...",
          "memberCount": 12
        },
        "lastMessage": "3 media",
        "lastMessageType": "media",
        "lastMessageAt": "2026-06-30T12:00:00.000Z",
        "unreadCount": 4,
        "muted": false,
        "pinned": false
      }
    ],
    "nextCursor": "base64CursorOrNull"
  }
}
```

---

### GET `/chat/messages/:userId`

Direct chat history.

**Query:** `limit`, `cursor`, `direction=before|after`

**Response `200`**
```json
{
  "success": true,
  "conversationId": "userA_userB",
  "messages": [],
  "data": { "conversationId": "userA_userB", "messages": [], "nextCursor": null },
  "nextCursor": null
}
```

---

### GET `/chat/group/:groupId/messages`

Same query/response shape as direct messages.

---

### GET `/chat/conversations/:conversationId/shared-media`

**Query:** `type=photos_videos|links_files`, `limit`, `cursor`

**Response `200`**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "messageId": "messageObjectId",
        "createdAt": "2026-06-30T12:00:00.000Z",
        "sender": { "id": "userId", "username": "ali", "profilePicture": "" },
        "attachments": [
          {
            "mediaType": "image",
            "url": "https://cdn.example.com/...",
            "thumbnailUrl": "https://cdn.example.com/..."
          }
        ]
      }
    ],
    "nextCursor": null
  }
}
```

---

## 3. Group management

### POST `/chat/group/create`

**Body**
```json
{
  "clientRequestId": "device-uuid",
  "name": "Design Team",
  "description": "Product design",
  "avatarMediaAssetId": "optionalAssetId",
  "participantIds": ["userA", "userB"],
  "settings": {
    "allowNicknames": true,
    "allowMediaSharing": true,
    "adminOnlyPosting": false
  }
}
```

**Response `201`**
```json
{
  "success": true,
  "data": {
    "group": {
      "id": "groupObjectId",
      "conversationId": "group:groupObjectId",
      "name": "Design Team",
      "memberCount": 3,
      "settings": { "allowNicknames": true, "allowMediaSharing": true, "adminOnlyPosting": false },
      "members": [
        { "userId": "creatorId", "role": "owner", "username": "creator", "nickname": null }
      ]
    },
    "conversation": {
      "conversationId": "group:groupObjectId",
      "isGroup": true,
      "lastMessage": "Group created",
      "lastMessageType": "system",
      "lastMessageAt": "2026-06-30T12:00:00.000Z"
    }
  }
}
```

---

### GET `/chat/group/:groupId/profile`

**Response `200`**
```json
{
  "success": true,
  "data": {
    "group": {
      "id": "groupObjectId",
      "conversationId": "group:groupObjectId",
      "name": "Design Team",
      "description": "...",
      "avatarUrl": "",
      "memberCount": 12,
      "settings": {},
      "myRole": "admin",
      "myNickname": "Ali"
    },
    "memberPreview": [],
    "permissions": {
      "canEditGroup": true,
      "canManageMembers": true,
      "canPost": true,
      "canSendMedia": true
    }
  }
}
```

---

### PATCH `/chat/group/:groupId`

**Body:** `{ "name", "description", "avatarMediaAssetId" }`

---

### PATCH `/chat/group/:groupId/settings`

**Body:** `{ "allowNicknames", "allowMediaSharing", "adminOnlyPosting", "whoCanSendMessages", ... }`

---

### GET `/chat/group/:groupId/members`

**Query:** `limit`, `cursor`, `role`, `q`

---

### POST `/chat/group/:groupId/members`

**Body:** `{ "userIds": ["userA", "userB"] }`

---

### DELETE `/chat/group/:groupId/members/:userId`

Remove member (admin) or leave group (self).

---

### PATCH `/chat/group/:groupId/members/:userId/role`

**Body:** `{ "role": "admin" }` — `admin` \| `moderator` \| `member`

---

### PATCH `/chat/group/:groupId/me/nickname`

**Body:** `{ "nickname": "Ali" }`

---

## 4. Media upload sessions

### POST `/media/upload-sessions`

**Body**
```json
{
  "conversationId": "optional",
  "groupId": "groupObjectId",
  "clientMessageId": "device-uuid",
  "files": [
    {
      "clientFileId": "local-1",
      "fileName": "IMG_0001.jpg",
      "mimeType": "image/jpeg",
      "mediaType": "image",
      "sizeBytes": 3010200,
      "width": 3024,
      "height": 4032
    }
  ]
}
```

**Response `201`**
```json
{
  "success": true,
  "data": {
    "uploadBatchId": "batchObjectId",
    "expiresAt": "2026-06-30T12:15:00.000Z",
    "items": [
      {
        "clientFileId": "local-1",
        "mediaAssetId": "assetId1",
        "uploadMethod": "put",
        "uploadUrl": "https://s3-signed-url...",
        "headers": { "Content-Type": "image/jpeg" },
        "objectKey": "chat/images/userId/assetId1.jpg"
      }
    ]
  }
}
```

Large files/videos use `uploadMethod: "multipart"` with signed part URLs.

---

### POST `/media/upload-sessions/:uploadBatchId/complete`

**Body**
```json
{
  "items": [
    { "mediaAssetId": "assetId1", "etag": "etag-value", "parts": [] },
    {
      "mediaAssetId": "assetId2",
      "multipartUploadId": "s3UploadId",
      "parts": [{ "partNumber": 1, "etag": "etag-1" }]
    }
  ]
}
```

**Response `200`**
```json
{
  "success": true,
  "data": {
    "assets": [
      { "id": "assetId1", "status": "processing", "mediaType": "image" }
    ]
  }
}
```

Triggers async processing → socket `media:asset.updated` → linked messages get `chat:message.updated`.

---

### GET `/media/assets/:assetId`

Poll asset processing status.

**Response `200`**
```json
{
  "success": true,
  "data": {
    "asset": {
      "event": "media:asset.updated",
      "mediaAssetId": "assetId1",
      "status": "ready",
      "progress": 100,
      "mediaType": "image",
      "url": "https://cdn.example.com/...",
      "thumbnailUrl": "https://cdn.example.com/...-thumb.webp",
      "processingState": "ready"
    }
  }
}
```

---

## 5. Calls (v2)

Requires `APP_ID` and `APP_CERTIFICATE` in `.env`.

### POST `/calls`

**Direct**
```json
{
  "type": "direct_video",
  "receiverId": "userObjectId",
  "conversationId": "optional",
  "clientRequestId": "device-uuid"
}
```

**Group**
```json
{
  "type": "group_voice",
  "groupId": "groupObjectId",
  "inviteUserIds": ["userA", "userB"],
  "clientRequestId": "device-uuid"
}
```

**Types:** `direct_voice` \| `direct_video` \| `group_voice` \| `group_video`

**Response `201`**
```json
{
  "success": true,
  "data": {
    "call": {
      "id": "callObjectId",
      "type": "direct_video",
      "channelName": "call_abcd1234",
      "status": "ringing",
      "createdBy": "userObjectId",
      "createdAt": "2026-06-30T12:00:00.000Z"
    },
    "agora": {
      "appId": "agoraAppId",
      "uid": 100012,
      "token": "rtcToken",
      "expiresAt": "2026-06-30T13:00:00.000Z",
      "channelProfile": "communication",
      "role": "host",
      "canPublishAudio": true,
      "canPublishVideo": true
    }
  }
}
```

Direct calls to blocked users return `403`.

---

### GET `/calls/:callId`

Get call session (reconnect).

---

### POST `/calls/:callId/token`

Refresh Agora token.

**Body:** `{ "intent": "join", "publishAudio": true, "publishVideo": false }`

---

### PATCH `/calls/:callId/accept`

Receiver accepts. Returns fresh Agora credentials.

---

### PATCH `/calls/:callId/reject`

---

### PATCH `/calls/:callId/end`

End call for everyone.

---

### POST `/calls/:callId/join`

Group participant joins.

---

### POST `/calls/:callId/leave`

Leave without ending group call.

---

### POST `/calls/:callId/heartbeat`

Keep call alive (send every 15–30s during active call).

**Response `200`**
```json
{
  "success": true,
  "data": {
    "callId": "callObjectId",
    "lastHeartbeatAt": "2026-06-30T12:05:00.000Z",
    "status": "active"
  }
}
```

Calls without heartbeat for 120s are auto-ended. Ringing calls auto-miss after 40s.

---

### POST `/calls/:callId/network-quality`

**Body:** `{ "uplinkQuality": 4, "downlinkQuality": 3 }` (0–6 Agora scale)

Broadcasts `calls:network_quality` to call room.

---

### PATCH `/calls/:callId/participants/:userId`

**Body:** `{ "canPublishAudio": true, "canPublishVideo": false, "role": "speaker" }`

Emits `calls:participant.media_updated`.

---

### POST `/calls/:callId/recording/start`

Host starts recording session.

**Response `201`**
```json
{
  "success": true,
  "data": {
    "recording": {
      "state": "recording",
      "storageKey": "recordings/call_abc/123.m3u8",
      "startedAt": "2026-06-30T12:00:00.000Z",
      "note": "Recording session registered. Wire Agora Cloud Recording for production transcoding."
    }
  }
}
```

---

### POST `/calls/:callId/recording/stop`

**Response `200`**
```json
{
  "success": true,
  "data": {
    "recording": {
      "state": "stopped",
      "storageKey": "recordings/...",
      "durationMs": 125000
    }
  }
}
```

---

## 6. Legacy & utility

| Method | Path | Description |
|--------|------|-------------|
| POST | `/calls/agora/token` | Legacy call start (existing Flutter client) |
| PATCH/POST | `/calls/accept`, `/calls/reject`, `/calls/end` | Legacy call lifecycle |
| POST | `/calls/live/*` | Live streaming (separate from chat) |
| GET | `/chat/shareable-users` | Users for share picker |
| POST | `/chat/resolve-post` | Resolve post from link |

---

## 7. Socket events

Connect to the same Socket.IO server used by the app.

### Setup

```javascript
// Chat & calls
socket.emit("chat:register", userId);
socket.emit("chat:join", conversationId);
socket.emit("calls:register", { userId });
socket.emit("calls:join", { callId });

// Posts, block & view count
socket.emit("user:register", userId);
socket.emit("post:join", postId);
socket.emit("post:leave", postId);
```

### Chat

| Client emits | Server broadcasts |
|--------------|-------------------|
| `chat:typing.started` | `chat:typing.started` |
| `chat:typing.stopped` | `chat:typing.stopped` |
| — | `chat:message` (includes `event: chat:message.created`) |
| — | `chat:message.updated` |
| — | `chat:message:deleted` |
| — | `chat:message.read` |
| — | `chat:conversation.updated` |
| — | `media:asset.updated` |
| — | `group:created`, `group:updated`, `group:settings.updated`, `group:member.*` |

### Calls

| Event | When |
|-------|------|
| `calls:incoming` | Call created |
| `calls:accepted` | Receiver accepted |
| `calls:rejected` | Receiver rejected |
| `calls:ended` | Call ended / missed / timeout |
| `calls:participant.joined` | Group join |
| `calls:participant.left` | Group leave |
| `calls:participant.media_updated` | Host changed publish permissions |
| `calls:token.expiring` | Token expires within 5 min |
| `calls:network_quality` | Client reported or REST `/network-quality` |
| `calls:heartbeat:ack` | Socket heartbeat ack |

### Posts, block & view count

| Client emits | Payload | Purpose |
|--------------|---------|---------|
| `user:register` | `userId` (string) | Join room for block/unblock events |
| `post:join` | `postId` (string) | Join room for live view count updates |
| `post:leave` | `postId` (string) | Leave post room |

| Server emits | When | Payload |
|--------------|------|---------|
| `post:view.updated` | After `POST /post/:id/view` increments | `{ event, eventId, postId, viewCount, createdAt }` |
| `user:blocked` | After `PATCH /auth/block/:id` | `{ event, eventId, userId, blockedUserId, blockedUser, createdAt }` |
| `user:unblocked` | After `PATCH /auth/unblock/:id` | `{ event, eventId, userId, unblockedUserId, createdAt }` |

**Example — live view count**
```javascript
socket.emit("user:register", myUserId);
socket.emit("post:join", postId);

socket.on("post:view.updated", (payload) => {
  console.log(payload.viewCount);
});
```

### `media:asset.updated` payload

```json
{
  "event": "media:asset.updated",
  "eventId": "media-assetId-timestamp",
  "mediaAssetId": "assetId",
  "status": "processing",
  "progress": 65,
  "thumbnailUrl": "https://cdn.example.com/...",
  "previewUrl": null,
  "createdAt": "2026-06-30T12:00:00.000Z"
}
```

---

## 8. Background jobs

Started automatically in `server.js`:

| Job | Interval | Action |
|-----|----------|--------|
| Chat/media maintenance | 30s | Miss ringing calls (40s), end stale calls (120s no heartbeat), expire orphan uploads, warn token expiry |
| Story cleanup | 60s | Delete 24h+ stories |

Env overrides: `CHAT_MAINTENANCE_INTERVAL_MS`

---

## 9. Environment variables

| Variable | Required for |
|----------|--------------|
| `JWT_SECRET` | All authenticated APIs |
| `MONGODB_URI` | Database |
| `AWS_S3_IMAGES_BUCKET` | Chat images |
| `AWS_S3_VIDEOS_BUCKET` | Chat videos |
| `CLOUDFRONT_IMAGES` | Image CDN URL |
| `CLOUDFRONT_VIDEOS` | Video CDN URL |
| `APP_ID` | Agora calls |
| `APP_CERTIFICATE` | Agora token minting (server only) |

---

## 10. Multi-media collage flow

```
1. POST /media/upload-sessions          → signed URLs
2. Upload files directly to S3          → track progress locally
3. POST /media/upload-sessions/:id/complete
4. Listen for media:asset.updated      → or poll GET /media/assets/:id
5. POST /chat/send { mediaAssetIds }    → one message, ordered attachments[]
6. Recipients get chat:message.created  → collage renders one bubble
7. If still processing → chat:message.updated when ready
```

Text messages can be sent at step 2+ without waiting for upload completion.

---

## 11. Block & unblock users

Instagram-style blocking. Base path: `/api/v1/auth`

### GET `/auth/blocked`

Returns users **you** blocked (not users who blocked you).

**Response `200`**
```json
{
  "success": true,
  "count": 1,
  "blockedUsers": [
    {
      "id": "userId",
      "username": "jane",
      "profilePicture": "https://..."
    }
  ]
}
```

---

### PATCH `/auth/block/:id`

- Adds user to your `blockedUsers`
- Removes follow relationships both ways
- Emits socket `user:blocked`

**Response `200`**
```json
{
  "success": true,
  "message": "User blocked successfully",
  "blockedUsers": ["userId"],
  "blockedUser": {
    "id": "userId",
    "username": "jane",
    "profilePicture": "https://..."
  }
}
```

---

### PATCH `/auth/unblock/:id`

- Removes user from your `blockedUsers`
- Emits socket `user:unblocked`

**Response `200`**
```json
{
  "success": true,
  "message": "User unblocked successfully",
  "blockedUsers": [],
  "unblockedUserId": "userId"
}
```

---

### Blocking behavior (app-wide)

When **you block someone** OR **they block you**, that user is hidden everywhere:

| Hidden | Exceptions |
|--------|------------|
| Reels, stories, long videos, posts, explore, search users/posts | Existing DM threads still visible in chat list |
| Profile by id (`GET /auth/user/:id`) returns 404 | `GET /auth/blocked` still lists users you blocked |
| Notifications from blocked users | — |
| Followers/following lists | — |
| New DMs / calls / likes / shares / comments (403) | Reading old messages in existing thread |

Bidirectional: if either side blocked the other, content is hidden.

---

## 12. View count

Base path: `/api/v1/post`

### POST `/post/:id/view`

Each authenticated user counts **once** per post (deduped via `PostView`). Response returns the **current** `viewCount` immediately.

**Response `200` (first view)**
```json
{
  "success": true,
  "postId": "postId",
  "viewCount": 42,
  "incremented": true
}
```

**Response `200` (repeat view by same user)**
```json
{
  "success": true,
  "postId": "postId",
  "viewCount": 42,
  "incremented": false
}
```

Blocked owner's posts return `404`. On increment, server emits `post:view.updated` (see [Socket events](#7-socket-events)).

---

## 13. Reel soundtrack

### POST `/post/reel/create` (multipart)

**Files**

| Field | Required | Notes |
|-------|----------|-------|
| `video` | Yes | One reel video |
| `audio` | No | mp3/mp4 audio upload |
| `thumbnail` | No | Image |

**Body fields (soundtrack)**

| Field | Type | Description |
|-------|------|-------------|
| `music` | string | External music URL (alternative to `audio` file) |
| `musicTitle` / `soundtrackTitle` | string | Track title |
| `musicArtist` / `soundtrackArtist` | string | Artist name |
| `isOriginalSound` | boolean | `true` for original audio from the reel |
| `musicSource` | string | e.g. `original`, `upload`, `library` |
| `soundtrackDurationMs` | number | Duration in milliseconds |
| `caption`, `locations`, `feelings`, `taggedUsers`, `thumbnail` | — | Existing reel fields |

When `isOriginalSound=true` and no artist is sent, the uploader's username is used.

**Response `201` — soundtrack fields on reel**
```json
{
  "success": true,
  "message": "Reel created successfully",
  "reel": {
    "music": "https://...",
    "musicUrl": "https://...",
    "musicTitle": "My sound",
    "musicArtist": "creator_name",
    "musicName": "creator_name",
    "isOriginalSound": true,
    "musicSource": "original",
    "soundtrack": {
      "url": "https://...",
      "title": "My sound",
      "artistName": "creator_name",
      "isOriginal": true,
      "source": "original",
      "durationMs": 15000
    },
    "viewCount": 0
  }
}
```

Legacy field `music` remains for backward compatibility.

---

## 14. API checklist

| Category | Endpoints | Status |
|----------|-----------|--------|
| Chat | 7 | Complete |
| Conversations | 4 | Complete |
| Group | 9 | Complete |
| Media | 3 | Complete |
| Calls v2 | 13 | Complete |
| Block / unblock | 3 | Complete |
| View count | 1 | Complete |
| Reel soundtrack | 1 (create) | Complete |
| Sockets | Chat, calls, media, block, view | Complete |
| Workers | Processing + cleanup + call TTL | Complete |
| Agora Cloud Recording | REST stubs | Registered; wire Agora REST for production files |

### Quick reference — new social APIs

| Action | Method | Endpoint |
|--------|--------|----------|
| List blocked users | GET | `/api/v1/auth/blocked` |
| Block user | PATCH | `/api/v1/auth/block/:id` |
| Unblock user | PATCH | `/api/v1/auth/unblock/:id` |
| Increment view | POST | `/api/v1/post/:id/view` |
| Create reel + soundtrack | POST | `/api/v1/post/reel/create` |

---

*VidConnect backend — merged reference for chat/group proposal + block, view count & reel soundtrack APIs.*
