# Posts Feature — Removal Context & Restoration Guide

This document records what was removed when the **photo/carousel posts** feature (`postType: 'post'`) was disabled from the app UI. Reels, stories, and long videos are unchanged.

## What “posts” means in this codebase

| Concept | `postType` | API / model |
|--------|------------|-------------|
| Photo/carousel posts | `'post'` | `ApiPost` via posts API → `PostModel.fromApiPost()` |
| Reels | `'reel'` | Reels API → `PostModel.fromReel()` |
| Long videos | `'longVideo'` | Long videos API |
| Stories | `'story'` | Stories API |

`PostModel` is a **unified UI model** for all content types. Removing the posts *feature* does not delete `PostModel`, `postsProvider`, or posts API code — only user-facing surfaces for `postType == 'post'`.

---

## Changes made (UI removal)

### Reels tab (`lib/features/reels/reels_screen.dart`)
- **Removed:** Merged feed (`_mergeFeedWithReels`), `_buildPostItem`, post music via `AttachedMusicPreview`, `loadMoreFeedPosts` pagination on reels pager.
- **Restored:** Reels-only vertical `PageView`; warm pool for **previous / current / next** reel indices (`_ensureWarmSlot`, `_activateReelWithPool`, `GlobalVideoEngine`).
- **Deleted:** `lib/features/reels/reels_feed_post_media.dart`

### Profile (`lib/features/profile/profile_screen.dart`)
- Tab count: 3 → 2 (`Post.` tab removed).
- `TabBarView`: Reels + Long Videos only.
- `_buildPostsGrid` still exists but is **unwired** (kept for restoration).

### Create content (`lib/features/feed/create_content_screen.dart`)
- Default type: `ContentType.reel` (was `post`).
- **Removed** “Post” type chip from picker UI.
- `ContentType.post` enum value and `_buildPostMediaSection` / `_pickPostImages` **retained** in file for API compatibility.

### Create sheet (`lib/core/widgets/create_content_sheet.dart`)
- **Removed** “Post” option from bottom sheet grid.

### Search (`lib/features/search/search_screen.dart`)
- **Removed** “Posts” results section and post thumb precache.
- Reels + long videos + users unchanged.

### Saved (`lib/features/settings/saved_screen.dart`)
- Tab count: 3 → 2; **Post.** tab removed.
- Saved reels/long videos still use `savedPostsProvider` (name is historical).

### Main shell (`lib/features/main/main_screen.dart`)
- **Removed** eager `postsProvider.loadPosts()` on app start (home feed no longer exists).

### Explore (`lib/features/search/explore_screen.dart`)
- **No change** — already reels + long videos only.

---

## Code intentionally kept (shared infrastructure)

| Area | Path | Why kept |
|------|------|----------|
| Posts API & provider | `lib/core/providers/posts_provider_riverpod.dart`, `lib/services/posts/posts_service.dart` | Reels/long-video flows, notifications, chat share-post |
| `PostModel` / `ApiPost` | `lib/core/models/post_model.dart`, `post_response_model.dart` | All content types |
| `InstagramPostCard` | `lib/core/widgets/instagram_post_card.dart` | Saved viewer, profile post viewer, home feed file (dormant) |
| Home feed page | `lib/features/home/home_feed_page.dart` | Not in bottom nav; full feed implementation preserved |
| Chat share post | `ChatService.sharePost`, `messageType: 'post'` | DM link sharing |
| Saved provider | `saved_posts_provider_riverpod.dart` | Reels + long video saves |
| `ContentType.post` enum | `create_content_screen.dart` | Publish pipeline for carousel posts |

---

## How to restore posts in each surface

### 1. Reels tab mixed feed (posts + reels in vertical pager)
1. Re-add `reels_feed_post_media.dart` (full-bleed images, horizontal carousel, `BoxFit.contain`).
2. In `reels_screen.dart`:
   - `_mergeFeedWithReels(posts, reels)` — insert 1 reel every 4 posts.
   - `_effectiveReelsList()` — merge `postsProvider` feed posts with `reelsListProvider`.
   - `_buildFeedItem` → reel vs `_buildPostItem`.
   - Post music: `AttachedMusicPreview` on settled post index; pause `GlobalVideoEngine` on non-reel indices.
   - `_nearestReelIndex` for warm slots when posts sit between reels.
   - `loadMoreFeedPosts()` near end of pager.
3. Re-enable `postsProvider.loadPosts()` in `initState` and pull-to-refresh.

### 2. Profile posts tab
- `TabController(length: 3)`.
- Add `Tab(text: 'Post.')` and `_buildPostsGrid(posts.where((p) => p.postType == 'post'))` as first `TabBarView` child.

### 3. Create post flow
- Default `initialType` / `_selectedType` → `ContentType.post`.
- Re-add type chip and create sheet option.
- Wire `_buildPostMediaSection`, `_pickPostImages` (max 10), optional music tile.

### 4. Search posts section
- In `search_screen.dart`: restore `if (state.posts.isNotEmpty)` block with `_buildSectionHeader('Posts')` + `_buildPostGrid(state.posts)`.
- Restore precache loop over `state.posts`.

### 5. Saved posts tab
- `TabController(length: 3)`; first tab `_buildSavedTab('post')`.

### 6. App startup
- In `main_screen.dart` `initState`: `postsProvider.notifier.loadPosts(forceRefresh: false)`.

---

## Related providers & APIs

```
postsProvider          → GET paginated feed posts
reelsListProvider      → reels only
postType discriminator → PostModel.postType
postLikeCountProvider  → likes on posts (not reels)
reelLikeCountProvider  → likes on reels
feedActiveMusicPreviewUrlProvider → home feed post audio (home_feed_page.dart)
```

Posts API endpoints: see `lib/services/posts/posts_service.dart` and `lib/core/api/`.

---

## Chat optimizations (same release)

Not posts-related, but added in this pass:
- **1:1 chat:** `ChatMessagesNotifier.load()` hydrates from `UserStorageService.getCachedMessagesForChat` before network (WhatsApp-style instant history).
- **Group chat:** Page size 20, `loadOlder()` pagination, shimmer skeleton instead of `CircularProgressIndicator`.
- Pagination API: `GET /chat/messages/{userId}?limit=&skip=` and `GET /chat/group/{groupId}/messages?limit=&skip=`.

---

## Testing checklist after restoration

- [ ] Create carousel post (1–10 images) + optional music
- [ ] Post appears in profile Post tab and saved Post tab
- [ ] Post in search results opens `ProfilePostViewerScreen`
- [ ] Mixed reels feed: reel engine only on reel indices; post audio on post indices
- [ ] Pull-to-refresh loads posts + reels on reels tab

*Last updated: when posts UI was removed from reels tab, profile, create, search, and saved.*
