# Chat, Group, Media, and Agora Backend Proposal

## Purpose

This proposal defines the backend system needed for a scalable chat experience across:

- 1:1 chat messages, media, shared posts, read receipts, delete/forward actions.
- Group creation, editing, roles, permissions, members, nicknames, and profile data.
- Multiple-media messages returned as a single message with an ordered `attachments[]` list so the Flutter collage widget can render one premium collage.
- Fast media upload with compression, thumbnails, background processing, per-file progress, and the ability to keep sending other messages while media is uploading.
- Optimized 1:1 and group Agora voice/video calls.

The most important backend principle: **binary media must not flow through realtime sockets**. Sockets should carry only lightweight state events. Media should upload through HTTPS direct-to-storage or resumable upload sessions, then the message should reference uploaded media records.

## Current Frontend Assumptions

The current Flutter client already expects these broad concepts:

- `POST /chat/send` returns `{ success: true, chat: { ... } }`.
- A chat message has `_id`, `conversationId`, `senderId`, `receiverId`, `groupId`, `message`, `messageType`, `attachments`, `readBy`, `deletedFor`, `isDeletedForEveryone`, `createdAt`, `updatedAt`.
- Attachments currently parse as:

```json
{
  "mediaType": "image",
  "url": "https://cdn.example.com/chat/original.webp"
}
```

- The new collage system works best if each message returns an ordered `attachments[]` list, including videos and thumbnails.
- Group settings currently exist only locally in Flutter and should move server-side.
- Calls currently use `POST /calls/agora/token`, plus socket events: `calls:incoming`, `calls:accepted`, `calls:rejected`, `calls:ended`.

## Recommended Architecture

### Services

1. **Chat API Service**
   - Owns conversations, messages, read receipts, deletes, forwards, and shared post messages.
   - Publishes realtime socket events after durable database writes.

2. **Group API Service**
   - Owns group records, members, roles, permissions, profile settings, invite controls, nicknames, and group audit actions.

3. **Media Service**
   - Owns upload sessions, media asset records, thumbnail/transcode jobs, CDN URLs, and orphan cleanup.
   - Generates signed upload/download URLs when assets are private.

4. **Realtime Gateway**
   - Socket.IO or WebSocket tier for chat, group, media processing, and call signaling events.
   - Stateless where possible. Use Redis adapter, Kafka, NATS, or another broker when horizontally scaling.

5. **Agora Call Service**
   - Owns call sessions, RTC/RTM token minting, call lifecycle, group call membership, call presence, and optional cloud recording.

6. **Worker Queue**
   - Background jobs for thumbnail generation, video transcode/compression validation, image optimization, malware scanning, metadata extraction, orphan cleanup, and call recording callbacks.

### Storage

- **PostgreSQL** recommended for relational chat/group/call records.
- **Redis** for socket presence, typing state, ephemeral upload progress, call ringing TTLs, rate limits, idempotency keys.
- **S3/GCS/R2-compatible object storage** for original media, optimized images, video transcodes, and thumbnails.
- **CDN** in front of media storage for fast delivery.
- **Queue** such as SQS, BullMQ, RabbitMQ, Kafka, or NATS JetStream for async processing.

## Data Model Proposal

### conversations

```sql
id uuid primary key
type text not null check (type in ('direct', 'group'))
direct_key text unique null
group_id uuid null references groups(id)
last_message_id uuid null
last_message_at timestamptz null
created_at timestamptz not null
updated_at timestamptz not null
```

For direct chat, use a stable `direct_key`, for example `minUserId:maxUserId`, to prevent duplicates.

### conversation_participants

```sql
conversation_id uuid not null references conversations(id)
user_id uuid not null
role text not null default 'member'
status text not null default 'active'
last_read_message_id uuid null
last_read_at timestamptz null
muted_until timestamptz null
pinned_at timestamptz null
archived_at timestamptz null
joined_at timestamptz not null
left_at timestamptz null
primary key (conversation_id, user_id)
```

### messages

```sql
id uuid primary key
client_message_id text null
conversation_id uuid not null references conversations(id)
sender_id uuid not null
receiver_id uuid null
group_id uuid null
type text not null check (type in ('text', 'image', 'video', 'media', 'audio', 'file', 'post', 'system', 'deleted'))
text text not null default ''
shared_post_id uuid null
reply_to_message_id uuid null
forwarded_from_message_id uuid null
status text not null default 'sent'
media_processing_state text not null default 'ready'
created_at timestamptz not null
updated_at timestamptz not null
deleted_for_everyone_at timestamptz null
version int not null default 1
unique (conversation_id, client_message_id)
```

`client_message_id` is required for idempotent retries. If the client retries due to network failure, the backend returns the existing message instead of creating duplicates.

### message_attachments

```sql
id uuid primary key
message_id uuid not null references messages(id)
media_asset_id uuid not null references media_assets(id)
sort_order int not null
media_type text not null check (media_type in ('image', 'video', 'audio', 'file'))
url text not null
thumbnail_url text null
preview_url text null
width int null
height int null
duration_ms int null
size_bytes bigint null
mime_type text null
processing_state text not null default 'ready'
created_at timestamptz not null
```

The ordered `sort_order` is essential for the collage UI.

### media_assets

```sql
id uuid primary key
owner_id uuid not null
upload_session_id uuid null
bucket text not null
original_key text not null
optimized_key text null
thumbnail_key text null
preview_key text null
media_type text not null
mime_type text not null
original_size_bytes bigint not null
optimized_size_bytes bigint null
width int null
height int null
duration_ms int null
checksum_sha256 text null
status text not null check (status in ('reserved', 'uploading', 'uploaded', 'processing', 'ready', 'failed', 'expired'))
error_code text null
created_at timestamptz not null
updated_at timestamptz not null
expires_at timestamptz null
```

### groups

```sql
id uuid primary key
conversation_id uuid not null references conversations(id)
name text not null
description text not null default ''
avatar_asset_id uuid null references media_assets(id)
created_by uuid not null
settings jsonb not null default '{}'
created_at timestamptz not null
updated_at timestamptz not null
deleted_at timestamptz null
```

Recommended `settings` shape:

```json
{
  "allowNicknames": true,
  "allowMediaSharing": true,
  "adminOnlyPosting": false,
  "messageRetentionDays": null,
  "joinApprovalRequired": false,
  "whoCanEditInfo": "admins",
  "whoCanSendMessages": "all"
}
```

### group_members

```sql
group_id uuid not null references groups(id)
user_id uuid not null
role text not null check (role in ('owner', 'admin', 'moderator', 'member'))
nickname text null
status text not null default 'active'
added_by uuid null
joined_at timestamptz not null
removed_at timestamptz null
primary key (group_id, user_id)
```

### calls

```sql
id uuid primary key
type text not null check (type in ('direct_voice', 'direct_video', 'group_voice', 'group_video'))
conversation_id uuid null references conversations(id)
group_id uuid null references groups(id)
channel_name text not null unique
created_by uuid not null
status text not null check (status in ('ringing', 'accepted', 'active', 'ended', 'missed', 'rejected', 'failed'))
started_at timestamptz null
ended_at timestamptz null
ended_by uuid null
end_reason text null
recording_state text null
created_at timestamptz not null
updated_at timestamptz not null
```

### call_participants

```sql
call_id uuid not null references calls(id)
user_id uuid not null
agora_uid int not null
role text not null check (role in ('host', 'speaker', 'audience'))
state text not null check (state in ('invited', 'ringing', 'joined', 'left', 'declined', 'missed'))
can_publish_audio boolean not null default true
can_publish_video boolean not null default false
joined_at timestamptz null
left_at timestamptz null
primary key (call_id, user_id)
unique (call_id, agora_uid)
```

## API Response Rules

All successful API responses should use:

```json
{
  "success": true,
  "data": {}
}
```

For current frontend compatibility, chat send can also include top-level `chat`:

```json
{
  "success": true,
  "chat": {},
  "data": { "chat": {} }
}
```

Errors:

```json
{
  "success": false,
  "code": "GROUP_PERMISSION_DENIED",
  "message": "Only admins can edit this group"
}
```

Every write endpoint should support:

- `Idempotency-Key` header, or `clientMessageId` in body.
- Authenticated user from JWT.
- Server-side permission validation.
- Consistent timestamps in ISO 8601 UTC.

## Chat APIs

### GET /chat/conversations

Returns direct and group threads.

Query:

- `limit`
- `cursor`
- `includeMuted=true`

Response:

```json
{
  "success": true,
  "data": {
    "conversations": [
      {
        "conversationId": "uuid",
        "type": "group",
        "isGroup": true,
        "user": null,
        "group": {
          "id": "groupUuid",
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
    "nextCursor": "opaqueCursor"
  }
}
```

### GET /chat/messages/:userId

Direct chat history.

Query:

- `limit`
- `cursor`
- `direction=before|after`

Response:

```json
{
  "success": true,
  "conversationId": "uuid",
  "messages": []
}
```

### GET /chat/group/:groupId/messages

Group chat history. Same message shape as direct chat.

### POST /chat/send

Recommended for text messages, shared posts, and messages referencing already uploaded media assets.

Body for text:

```json
{
  "receiverId": "userUuid",
  "clientMessageId": "device-generated-uuid",
  "message": "Hello",
  "messageType": "text"
}
```

Body for group:

```json
{
  "groupId": "groupUuid",
  "clientMessageId": "device-generated-uuid",
  "message": "Hello group",
  "messageType": "text"
}
```

Body for multiple media:

```json
{
  "groupId": "groupUuid",
  "clientMessageId": "device-generated-uuid",
  "message": "Trip photos",
  "messageType": "media",
  "mediaAssetIds": [
    "assetUuid1",
    "assetUuid2",
    "assetUuid3"
  ]
}
```

Response for multiple media, consumed by the collage widget:

```json
{
  "success": true,
  "chat": {
    "_id": "messageUuid",
    "conversationId": "conversationUuid",
    "senderId": "userUuid",
    "receiverId": "",
    "groupId": "groupUuid",
    "message": "Trip photos",
    "messageType": "media",
    "attachments": [
      {
        "id": "attachmentUuid1",
        "mediaAssetId": "assetUuid1",
        "mediaType": "image",
        "url": "https://cdn.example.com/chat/images/optimized-1.webp",
        "thumbnailUrl": "https://cdn.example.com/chat/thumbs/1.webp",
        "width": 1440,
        "height": 1800,
        "sizeBytes": 420112,
        "processingState": "ready",
        "sortOrder": 0
      },
      {
        "id": "attachmentUuid2",
        "mediaAssetId": "assetUuid2",
        "mediaType": "video",
        "url": "https://cdn.example.com/chat/videos/2/master.m3u8",
        "thumbnailUrl": "https://cdn.example.com/chat/thumbs/2.jpg",
        "previewUrl": "https://cdn.example.com/chat/videos/2/preview.mp4",
        "width": 1080,
        "height": 1920,
        "durationMs": 15420,
        "sizeBytes": 3101120,
        "processingState": "ready",
        "sortOrder": 1
      }
    ],
    "readBy": ["senderUuid"],
    "createdAt": "2026-06-30T12:00:00.000Z",
    "updatedAt": "2026-06-30T12:00:00.000Z",
    "sender": {
      "id": "userUuid",
      "username": "ali",
      "profilePicture": "https://cdn.example.com/avatar.jpg"
    }
  }
}
```

Important:

- The backend must preserve `attachments[]` order.
- `messageType` should be `media` if mixed image/video, `image` if all images, `video` if all videos.
- The message should be delivered once, with all attachments in one list, not as separate messages.
- If some assets are still processing, return `processingState: "processing"` and update over socket later.

### PATCH /chat/messages/:messageId/read

Marks a message or conversation read.

Body:

```json
{
  "conversationId": "uuid",
  "lastReadMessageId": "messageUuid"
}
```

### POST /chat/forward

Body:

```json
{
  "messageId": "messageUuid",
  "receiverId": "userUuid",
  "groupId": null,
  "clientMessageId": "device-generated-uuid"
}
```

### POST /chat/delete

Body:

```json
{
  "messageId": "messageUuid",
  "deleteForEveryone": true
}
```

## Optimized Multi-Media Upload Flow

### Why Upload Sessions

Multipart `POST /chat/send` is acceptable for small prototypes, but it blocks the message request until all bytes reach the API server. That hurts scale and makes it hard to send other messages while upload is in progress.

Recommended production flow:

1. Client picks media.
2. Client locally creates an optimistic pending message with `clientMessageId`.
3. Client compresses videos/images where possible and generates local thumbnails for instant UI.
4. Client requests upload sessions for every media item.
5. Client uploads files directly to object storage using signed URLs or resumable multipart/tus.
6. Backend receives completion signal and starts async processing.
7. Client calls `POST /chat/send` with `mediaAssetIds[]`.
8. Backend returns one message containing ordered `attachments[]`.
9. Socket delivers `chat:message.created` to participants.
10. Workers emit `media:asset.updated` and `chat:message.updated` when thumbnails/transcodes are ready.

### POST /media/upload-sessions

Creates one upload session for many files.

Body:

```json
{
  "conversationId": "uuid",
  "groupId": "groupUuid",
  "clientMessageId": "device-generated-uuid",
  "files": [
    {
      "clientFileId": "local-file-1",
      "fileName": "IMG_0001.jpg",
      "mimeType": "image/jpeg",
      "mediaType": "image",
      "sizeBytes": 3010200,
      "checksumSha256": "optional",
      "width": 3024,
      "height": 4032,
      "durationMs": null
    },
    {
      "clientFileId": "local-file-2",
      "fileName": "VID_0002.mp4",
      "mimeType": "video/mp4",
      "mediaType": "video",
      "sizeBytes": 23201120,
      "checksumSha256": "optional",
      "width": 1080,
      "height": 1920,
      "durationMs": 15420
    }
  ]
}
```

Response:

```json
{
  "success": true,
  "data": {
    "uploadBatchId": "batchUuid",
    "expiresAt": "2026-06-30T12:15:00.000Z",
    "items": [
      {
        "clientFileId": "local-file-1",
        "mediaAssetId": "assetUuid1",
        "uploadMethod": "put",
        "uploadUrl": "https://storage-upload.example.com/signed-put",
        "headers": {
          "Content-Type": "image/jpeg"
        },
        "objectKey": "chat/originals/userUuid/assetUuid1.jpg"
      },
      {
        "clientFileId": "local-file-2",
        "mediaAssetId": "assetUuid2",
        "uploadMethod": "multipart",
        "multipart": {
          "uploadId": "s3UploadId",
          "partSizeBytes": 5242880,
          "parts": [
            {
              "partNumber": 1,
              "uploadUrl": "https://storage-upload.example.com/signed-part-1"
            }
          ]
        }
      }
    ]
  }
}
```

Rules:

- Images under a threshold can use one signed PUT.
- Videos and large files should use multipart or tus-style resumable uploads.
- Upload URLs should expire quickly, usually 10 to 15 minutes.
- `media_assets.status` starts as `reserved`.
- Old reserved/uploading records expire and are cleaned up.

### Client Progress

The client should track progress locally while uploading to storage:

```text
overallProgress = sum(uploadedBytes for all files) / sum(totalBytes for all files)
fileProgress[fileId] = uploadedBytes / totalBytes
```

The collage widget should render:

- Each tile's local thumbnail.
- Per-tile progress ring/bar.
- Overall progress label, for example `Uploading 2 / 5`.
- Failed tile retry state.

This progress should not require socket traffic because the client knows how many bytes it has uploaded.

### POST /media/upload-sessions/:uploadBatchId/complete

Called after all upload parts are committed.

Body:

```json
{
  "items": [
    {
      "mediaAssetId": "assetUuid1",
      "etag": "storage-etag",
      "parts": []
    },
    {
      "mediaAssetId": "assetUuid2",
      "multipartUploadId": "s3UploadId",
      "parts": [
        { "partNumber": 1, "etag": "etag-1" },
        { "partNumber": 2, "etag": "etag-2" }
      ]
    }
  ]
}
```

Response:

```json
{
  "success": true,
  "data": {
    "assets": [
      {
        "id": "assetUuid1",
        "status": "processing",
        "mediaType": "image"
      },
      {
        "id": "assetUuid2",
        "status": "processing",
        "mediaType": "video"
      }
    ]
  }
}
```

### Processing Pipeline

Images:

1. Validate content type using magic bytes, not just file extension.
2. Strip EXIF and GPS metadata.
3. Generate optimized WebP/AVIF/JPEG variants.
4. Generate thumbnails: `160`, `320`, `720` widths.
5. Store width/height, checksum, size.
6. Mark `ready`.

Videos:

1. Validate container and codecs.
2. If the client already compressed the video, accept it if it meets constraints.
3. Generate thumbnail from the first representative frame, or use a client-provided thumbnail while server thumbnail is pending.
4. Generate lightweight preview MP4 for grid/collage if needed.
5. Generate adaptive streams for larger videos, preferably HLS with 360p/720p/1080p depending on source.
6. Mark `ready`.

For speed, the frontend should generate and show local thumbnails instantly. The backend thumbnail is authoritative for remote users and future loads.

### Server Processing Progress Events

The backend should emit:

```json
{
  "event": "media:asset.updated",
  "mediaAssetId": "assetUuid2",
  "status": "processing",
  "progress": 65,
  "thumbnailUrl": "https://cdn.example.com/chat/thumbs/2.jpg",
  "previewUrl": null
}
```

When a message references that media:

```json
{
  "event": "chat:message.updated",
  "conversationId": "uuid",
  "messageId": "messageUuid",
  "attachments": [
    {
      "mediaAssetId": "assetUuid2",
      "mediaType": "video",
      "url": "https://cdn.example.com/chat/videos/2/master.m3u8",
      "thumbnailUrl": "https://cdn.example.com/chat/thumbs/2.jpg",
      "processingState": "ready"
    }
  ]
}
```

### Sending Other Messages While Media Uploads

This is a frontend plus backend contract:

- Media upload is a separate background job keyed by `clientMessageId`.
- Text messages continue using `POST /chat/send` immediately.
- The server should not lock the conversation while upload is in progress.
- The client can keep an optimistic pending media message locally until assets are uploaded and `POST /chat/send` succeeds.
- If upload succeeds but send fails, media assets become orphan candidates and are cleaned up after TTL unless referenced.
- If send succeeds but processing is still running, recipients receive a pending/processing collage and later get `message.updated`.

## Realtime Events

### Chat Events

- `chat:message.created`
- `chat:message.updated`
- `chat:message.deleted`
- `chat:message.read`
- `chat:typing.started`
- `chat:typing.stopped`
- `chat:conversation.updated`

### Group Events

- `group:created`
- `group:updated`
- `group:member.added`
- `group:member.removed`
- `group:member.role_updated`
- `group:member.nickname_updated`
- `group:settings.updated`

### Delivery Rules

- Emit only after database commit.
- Include `eventId` and `createdAt` for dedupe and ordering.
- Include `conversationId` on every message event.
- Clients should ignore duplicate `eventId`s.
- Use Redis adapter or broker for horizontal socket scaling.

## Group APIs

### POST /chat/group/create

Body:

```json
{
  "clientRequestId": "device-generated-uuid",
  "name": "Design Team",
  "description": "Product design and launch planning",
  "avatarMediaAssetId": "optionalAssetUuid",
  "participantIds": ["userA", "userB"],
  "settings": {
    "allowNicknames": true,
    "allowMediaSharing": true,
    "adminOnlyPosting": false
  }
}
```

Response:

```json
{
  "success": true,
  "data": {
    "group": {
      "id": "groupUuid",
      "conversationId": "conversationUuid",
      "name": "Design Team",
      "description": "Product design and launch planning",
      "avatarUrl": "https://cdn.example.com/group-avatar.webp",
      "memberCount": 3,
      "settings": {
        "allowNicknames": true,
        "allowMediaSharing": true,
        "adminOnlyPosting": false
      },
      "members": [
        {
          "userId": "creatorUuid",
          "role": "owner",
          "username": "creator",
          "profilePicture": "https://cdn.example.com/avatar.webp",
          "nickname": null
        }
      ]
    },
    "conversation": {
      "conversationId": "conversationUuid",
      "isGroup": true,
      "lastMessage": "Group created",
      "lastMessageType": "system",
      "lastMessageAt": "2026-06-30T12:00:00.000Z"
    }
  }
}
```

Important:

- Include creator as owner automatically.
- Use idempotency to prevent duplicate groups on retries.
- Emit `group:created` and `chat:conversation.updated`.

### GET /chat/group/:groupId/profile

Returns profile screen data.

```json
{
  "success": true,
  "data": {
    "group": {
      "id": "groupUuid",
      "conversationId": "conversationUuid",
      "name": "Design Team",
      "description": "Product design and launch planning",
      "avatarUrl": "https://cdn.example.com/avatar.webp",
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

### PATCH /chat/group/:groupId

Edits name, description, avatar.

Body:

```json
{
  "name": "New Name",
  "description": "Updated description",
  "avatarMediaAssetId": "assetUuid"
}
```

### PATCH /chat/group/:groupId/settings

Body:

```json
{
  "allowNicknames": true,
  "allowMediaSharing": true,
  "adminOnlyPosting": false
}
```

### GET /chat/group/:groupId/members

Query:

- `limit`
- `cursor`
- `role`
- `q`

Response includes paginated members and current user permissions.

### POST /chat/group/:groupId/members

Admin adds members.

Body:

```json
{
  "userIds": ["userA", "userB"]
}
```

### DELETE /chat/group/:groupId/members/:userId

Admin removes a member, or the current user leaves.

### PATCH /chat/group/:groupId/members/:userId/role

Owner/admin updates roles.

Body:

```json
{
  "role": "admin"
}
```

### PATCH /chat/group/:groupId/me/nickname

Body:

```json
{
  "nickname": "Ali"
}
```

Rules:

- Only allowed if `settings.allowNicknames` is true.
- Store nicknames on `group_members`, not on user profile.
- Emit `group:member.nickname_updated`.

## Shared Media and Profile APIs

### GET /chat/conversations/:conversationId/shared-media

Query:

- `type=photos_videos|reels_long_videos|links_files`
- `limit`
- `cursor`

Response:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "messageId": "messageUuid",
        "createdAt": "2026-06-30T12:00:00.000Z",
        "sender": {
          "id": "userUuid",
          "username": "ali"
        },
        "attachments": [
          {
            "mediaType": "image",
            "url": "https://cdn.example.com/...",
            "thumbnailUrl": "https://cdn.example.com/..."
          }
        ]
      }
    ],
    "nextCursor": "opaqueCursor"
  }
}
```

This prevents profile screens from loading the latest 100 messages just to build shared media tabs.

## Agora Calls Proposal

### Current Client Observations

Current code has:

- `CallsService` for lifecycle APIs: token, accept, reject, end.
- `CallsNotifier` for call state and dedupe.
- `CallsSocketService` for incoming/accepted/rejected/ended socket events.
- `AgoraCallService` initializes `RtcEngine` per call, uses `channelProfileCommunication`, broadcaster role, speaker/camera toggles, and guarded startup.
- `CallScreen` handles 1:1 call UI, RTC join retry, ringing timeout, local PiP, remote video, and controls.

Current limitations to improve:

- Agora App ID is hardcoded as fallback in the client. Backend should always return appId/token/uid and token expiry.
- Token endpoint name mixes "start call" and "mint Agora token"; split call session creation from token refresh.
- Receiver token handling is mixed across incoming payload and accept response. It should be deterministic.
- No group call API/session model yet.
- No network quality, reconnect, token expiry renewal, or call analytics events exposed in the backend contract.
- Video defaults initialize video support even for voice. Voice should initialize audio-only where possible, then upgrade to video if user toggles.
- Channel/media options can be optimized more for direct voice, direct video, and group call modes.

### Agora API Design

#### POST /calls

Creates a call session.

Body for direct call:

```json
{
  "type": "direct_video",
  "receiverId": "userUuid",
  "conversationId": "conversationUuid",
  "clientRequestId": "device-generated-uuid"
}
```

Body for group call:

```json
{
  "type": "group_voice",
  "groupId": "groupUuid",
  "conversationId": "conversationUuid",
  "inviteUserIds": ["userA", "userB"],
  "clientRequestId": "device-generated-uuid"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "call": {
      "id": "callUuid",
      "type": "group_voice",
      "conversationId": "conversationUuid",
      "groupId": "groupUuid",
      "channelName": "call_abcd1234",
      "status": "ringing",
      "createdBy": "userUuid",
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

#### POST /calls/:callId/token

Refreshes an Agora token.

Body:

```json
{
  "intent": "join",
  "publishAudio": true,
  "publishVideo": false
}
```

Use this for:

- Initial receiver join after accept.
- Token renewal before expiry.
- Upgrading from voice to video.
- Rejoining after network interruption.

#### PATCH /calls/:callId/accept

Receiver accepts. Response must include fresh Agora token for receiver.

#### PATCH /calls/:callId/reject

Receiver rejects.

#### PATCH /calls/:callId/end

Ends for everyone if direct call. For group calls, host may end for everyone, or participant can leave with `POST /calls/:callId/leave`.

#### POST /calls/:callId/join

Group participant joins.

#### POST /calls/:callId/leave

Participant leaves without ending group call.

#### PATCH /calls/:callId/participants/:userId

Moderation controls.

Body:

```json
{
  "canPublishAudio": true,
  "canPublishVideo": false,
  "role": "speaker"
}
```

### Call Socket Events

- `calls:incoming`
- `calls:accepted`
- `calls:rejected`
- `calls:ended`
- `calls:participant.joined`
- `calls:participant.left`
- `calls:participant.media_updated`
- `calls:token.expiring`
- `calls:network_quality`

### Agora Optimization Recommendations

#### Token and Session

- Token generation must live only on backend.
- Tokens should be short-lived, for example 30 to 60 minutes.
- Include `expiresAt` so the client refreshes before expiry.
- Use stable numeric Agora UIDs mapped to user IDs per call.
- Add rate limits per user for create/token endpoints.
- Use idempotency keys to prevent duplicate calls on double tap.

#### Direct Voice Calls

- Initialize audio-only if the call starts as voice.
- Do not call `enableVideo()` until the user upgrades to video.
- Join with:
  - `publishMicrophoneTrack: true`
  - `publishCameraTrack: false`
  - `autoSubscribeAudio: true`
  - `autoSubscribeVideo: false`
- Start with earpiece route if product wants phone-call behavior, speaker route if product wants hands-free behavior. Store preference per user.
- Enable noise suppression, echo cancellation, and automatic gain where supported by the SDK.

#### Direct Video Calls

- Join with camera publishing only when user explicitly starts video.
- Use low initial resolution, then adapt upward after network quality stabilizes.
- Recommended starting profile:
  - 360p or 540p for mobile.
  - 15 fps default, 24 fps only for strong network.
  - Degradation preference: maintain framerate for calls where motion matters, maintain quality for static talking-head calls.
- Subscribe to remote video only when the call screen is visible.
- Pause local preview when app backgrounded or PiP hidden.

#### Group Voice Calls

- Use Agora channel with application-level speaker limits.
- Agora recommends keeping active publishers bounded. For group voice, allow many listeners but limit active speakers.
- Store participant role:
  - `host`
  - `speaker`
  - `audience`
- Audience joins with `publishMicrophoneTrack: false`.
- User requests to speak, admin/host grants speaker permission.
- Backend sends `calls:participant.media_updated`, client updates media options.

#### Group Video Calls

- Limit simultaneous video publishers at the application layer.
- Use active speaker layout:
  - Subscribe high quality to active speaker.
  - Subscribe low quality or no video for off-screen participants.
  - Unsubscribe video for participants not visible in the grid.
- Backend should provide participant capabilities; client should enforce by requesting token/options with `canPublishVideo`.
- Use role-based token privileges where available.

#### Reliability

- Track call states on backend with TTL cleanup:
  - `ringing` calls auto-miss after 35 to 45 seconds.
  - `active` calls without heartbeat auto-end after 90 to 120 seconds.
- Client sends heartbeat via socket or REST every 15 to 30 seconds during call.
- On reconnect, client calls `GET /calls/:callId` and `POST /calls/:callId/token`.
- Backend emits final state once, with event dedupe IDs.

#### Recording and Moderation

Optional:

- `POST /calls/:callId/recording/start`
- `POST /calls/:callId/recording/stop`
- Store recording status, storage key, duration, and retention policy.
- For high reliability, use Agora Cloud Recording query polling and recreate failed tasks with unique recording UID.

## Security and Privacy

- Never expose Agora App Certificate to clients.
- Never trust MIME type from client alone.
- Validate media by magic bytes.
- Strip EXIF/GPS metadata from images.
- Scan uploads for malware if files/docs are supported.
- Authorize every media download. If CDN is public, use unguessable keys and avoid exposing private conversations if URLs leak. Prefer signed CDN URLs for private chats.
- Enforce group permissions server-side, not only in Flutter.
- Apply per-user and per-conversation rate limits for messages, media sessions, and call starts.
- Add block/report checks before direct messages and calls.
- Support delete-for-me and delete-for-everyone with clear retention rules.

## Indexes

Recommended indexes:

```sql
create index idx_messages_conversation_created on messages(conversation_id, created_at desc);
create unique index idx_messages_client_id on messages(conversation_id, client_message_id) where client_message_id is not null;
create index idx_attachments_message_order on message_attachments(message_id, sort_order);
create index idx_media_assets_owner_status on media_assets(owner_id, status, created_at desc);
create index idx_group_members_user on group_members(user_id, status);
create index idx_calls_user_status on call_participants(user_id, state);
create index idx_conversations_last_message on conversations(last_message_at desc);
```

## Observability

Track these metrics:

- Message send latency P50/P95/P99.
- Socket delivery latency.
- Duplicate message retry rate.
- Upload session creation latency.
- Upload completion rate.
- Upload resume rate.
- Orphan media count.
- Media processing queue lag.
- Thumbnail generation failure rate.
- Video transcode duration.
- CDN cache hit rate.
- Call setup time.
- Call join failure rate.
- Agora token refresh failures.
- Call drop rate.
- Network quality distribution.
- Active publishers per group call.

## Migration Plan

### Phase 1: Stabilize Current Contract

- Keep current `POST /chat/send`.
- Ensure it returns `attachments[]` as an ordered list for all media messages.
- Add `clientMessageId` idempotency.
- Fix group settings to persist backend-side.
- Add profile/shared-media endpoints.

### Phase 2: Introduce Media Upload Sessions

- Add `/media/upload-sessions`.
- Add `/media/upload-sessions/:id/complete`.
- Client uploads directly to storage.
- `POST /chat/send` references `mediaAssetIds[]`.
- Keep multipart as fallback only for small files or old clients.

### Phase 3: Async Media Processing

- Add worker queue.
- Add thumbnails and video previews/transcodes.
- Add `media:asset.updated` and `chat:message.updated` events.
- Add orphan cleanup.

### Phase 4: Group Backend Completion

- Add group profile/settings/member APIs.
- Move nicknames and permissions from local storage to backend.
- Add group audit/system messages.

### Phase 5: Calls v2

- Split call creation, token refresh, join/leave, accept/reject/end.
- Add group voice/video calls.
- Add participant roles and publisher limits.
- Add token renewal and call heartbeats.
- Add network quality analytics.

## Recommended Final Backend Contract for Collage Media

The key response shape the Flutter collage widget needs is this:

```json
{
  "_id": "messageUuid",
  "conversationId": "conversationUuid",
  "senderId": "userUuid",
  "receiverId": "userUuid-or-empty",
  "groupId": "groupUuid-or-empty",
  "message": "",
  "messageType": "media",
  "attachments": [
    {
      "id": "attachmentUuid",
      "mediaAssetId": "assetUuid",
      "mediaType": "image",
      "url": "https://cdn.example.com/optimized.webp",
      "thumbnailUrl": "https://cdn.example.com/thumb.webp",
      "previewUrl": null,
      "width": 1440,
      "height": 1800,
      "durationMs": null,
      "sizeBytes": 420112,
      "processingState": "ready",
      "sortOrder": 0
    }
  ],
  "createdAt": "2026-06-30T12:00:00.000Z",
  "updatedAt": "2026-06-30T12:00:00.000Z"
}
```

If the backend consistently returns this shape for multi-media messages, the frontend can:

- Show one message bubble.
- Use one collage widget.
- Show upload/processing progress per tile.
- Open one grid screen.
- Swipe through every item in the same ordered media list.

## External Research Notes

The proposal follows these current best-practice patterns:

- Upload media outside realtime sockets and outside the core message path.
- Use direct-to-object-storage upload URLs where possible.
- Use resumable multipart or tus-style uploads for large files.
- Store media references in messages instead of raw bytes.
- Use async workers for thumbnails, transcodes, scans, and metadata.
- Use socket events for message and processing state changes only.
- Keep Agora token generation backend-only, short-lived, and refreshable.
- Bound simultaneous publishers in group calls at the application layer.
- Use token/session state and heartbeats to recover cleanly from reconnects.

