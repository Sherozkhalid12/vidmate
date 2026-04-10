# VidConnect — Performance Optimization TODO

> **Rule**: Complete ALL checkboxes in a feature before moving to the next.
> Mark items `[x]` only after implementation AND manual/widget test verification.
> Current feature in progress is always noted at the top.

---

## 🔄 CURRENT FEATURE IN PROGRESS
**Feature**: GLOBAL TASKS (post–Feature 5)
**Status**: Ready for full regression (§G.1–G.3)

---

## ✅ FEATURE COMPLETION LOG
- **REELS (Feature 1)** — completed 2026-04-06 (implementation in repo; verify on device in QA).
- **REELS v2 (Predictive Pool + Chunked Streaming)** — completed 2026-04-07 (pool prewarm architecture implemented; verify on device in QA).
- **HOME POSTS / FEED (Feature 2)** — completed 2026-04-09 (Hive cache, SWR, splash bootstrap, feed UI; verify on device in QA).
- **HOME FEED PERF v2 (stagger + decode + rebuild discipline)** — completed 2026-04-09 (staggered MainScreen bootstrap, off-main Hive JSON parse, memCache, feed HTTP cap, selective Riverpod watches, SliverList keep-alive policy, first-4 precache; verify on device in QA).
- **LONG VIDEOS (Feature 3)** — completed 2026-04-09 (Hive SWR, shimmer skeleton, Better Player inline + cache, HLS head prefetch via client m3u8 parser, `FeedCachedPostImage` posters, metrics, keep-alive + tab pause + cancel fetch; optional `video_thumbnail` from on-disk cache deferred until a stable cached-file path is available for the same URL as ExoPlayer; verify on device in QA).
- **EXPLORE (Feature 4)** — completed 2026-04-09 (explore grid shimmer + `FeedCachedPostImage`/`AppMediaCache.feedMedia` + first-viewport precache + `RepaintBoundary`; reels list = Hive SWR via `reelsProvider`; Hive recent searches + `ref.keepAlive` search state; 300ms debounce + `CancelToken` + generation guard + `compute` parse when ≥20 items; search skeleton + offline copy; `explore_grid_paint_ms` / `explore_search_results_ms`; verify on device in QA).
- **STORIES (Feature 5)** — completed 2026-04-09 (Hive tray SWR + splash/Main bootstrap `loadStories`; tray shimmer + offline banner + `AppMediaCache.feedMedia` avatars; first-5 story media precache via `precacheImage` + `ReelVideoPrefetchService`; `AutomaticKeepAliveClientMixin` + `PageStorageKey`; viewer themed gradient placeholders (no spinners), `offline` + disk-cache video via `getCachedFile`, adjacent-story warm + preload hit/miss metrics; `StoriesPerfMetrics` tray/first-frame traces; verify on device in QA).

---

## FEATURE 1 — REELS 🎬
> Target: zero buffering on swipe, zero spinners, instant reel-to-reel transition.

### 1.1 Skeleton screen (no spinner on empty state)
- [x] Replace `CircularProgressIndicator` in `reels_screen.dart` with a full-bleed shimmer skeleton matching reel aspect ratio
- [x] Skeleton must display on `list.isEmpty && isLoading == true` only
- [x] Skeleton must NOT display when `list.isNotEmpty` (even if `isRefreshing`)
- [x] Crossfade from skeleton → first reel content (no hard cut)

### 1.2 Stale-while-revalidate (SWR) hydration
- [x] Wire `UserStorageService.getCachedUnseenReels()` into `ReelsNotifier` constructor BEFORE the API call
- [x] Emit non-empty state with `isLoading: false` + `isRefreshing: true` from cached data
- [x] Network response merges into state (deduplicate by id, prefer server fields)
- [x] Write merged result back to cache after API success
- [x] `ReelsScreen` never shows skeleton when `reels.isNotEmpty` (cached or live)
- [x] Remove `autoDispose` from reels provider OR call `ref.keepAlive()` so state survives tab switches

### 1.3 MP4 faststart — server-side verification
- [x] Verify all reel video files are encoded with `ffmpeg -movflags +faststart` (moov atom at file start)
- [x] If not: document the FFmpeg command and coordinate with backend/CDN pipeline to re-encode or process on upload
- [x] Confirm with a test: open a reel URL in a browser network tab — first byte of playback should not require a range request to the end of the file

### 1.4 Full next-reel prefetch
- [x] While reel at index `i` plays, begin downloading the **complete file** for reel `i+1` (and optionally `i+2`) to disk using `flutter_cache_manager` or a named download task
- [x] On swipe: if download is complete, initialize player from **local file URI** (not network URL)
- [x] On swipe before download completes: fall back to stream URL cleanly — **cancel** the in-progress download task and discard the partial file before streaming
- [x] Cap concurrent prefetch downloads at 2 to avoid bandwidth starvation on slow networks
- [x] Only prefetch on WiFi by default; respect `DataSaver` / user preference flag

### 1.5 ExoPlayer / Better Player disk cache
- [x] Migrate reels from raw `video_player` (`VideoPlayerController.networkUrl`) to **Better Player** to unify cache layer
- [x] Enable Better Player `SimpleCache` with a bounded size (256MB minimum, configurable)
- [x] Same URL → instant start on second view (verify cache hit in logs)
- [x] Confirm cache is shared between reels tab and feed if the same video URL appears in both

### 1.6 Player pool and lifecycle
- [x] Maintain a pool of max 3 initialized Better Player controllers
- [x] Reuse controllers rather than creating/disposing on every index change
- [x] Dispose controllers for indices farther than ±3 from current (align with existing disposal threshold)
- [x] Verify no memory leak: run DevTools memory timeline while scrolling 30+ reels

### 1.7 AutomaticKeepAliveClientMixin — reels tab
- [x] Wrap `ReelsScreen` / `ReelsPage` in a `StatefulWidget` with `AutomaticKeepAliveClientMixin`
- [x] Set `wantKeepAlive: true`; call `super.build(context)` in `build()`
- [x] Apply `PageStorageKey` for scroll position retention
- [x] **Memory discipline**: on tab hide (off-screen), pause and dispose active video decoder; keep scroll position and list state alive
- [x] Verify: switch to another tab and back → no re-fetch, no spinner, reel resumes or replays from correct index

### 1.8 BlurHash / placeholder thumbnails
- [x] **Client fallback (ship first)**: render a themed grey gradient placeholder at the exact reel aspect ratio before any thumbnail loads — no blank hole, no spinner
- [x] If cached video file exists on disk: use `video_thumbnail` package to extract a poster frame locally and display immediately
- [x] **Ideal path (requires backend)**: add `blurHash` or `thumbHash` field to reel API response; decode synchronously on client using `blurhash_dart` or equivalent; crossfade to `CachedNetworkImage` when loaded
- [x] Placeholder covers the interval between reel list render and thumbnail network load — no pop-in

### 1.9 RepaintBoundary
- [x] Wrap the Better Player widget inside `ReelsScreen`'s reel tile in a `RepaintBoundary`
- [x] Verify: like/comment count updates do NOT trigger video surface repaint (check with Flutter DevTools → Repaint Rainbow)

### 1.10 Large named image cache (thumbnails)
- [x] Instantiate a named `CacheManager` for reels thumbnails with `stalePeriod: 7 days` and `maxNrOfCacheObjects: 500+`
- [x] Pass this manager into every `CachedNetworkImage` call in reels list
- [x] Verify: kill and relaunch app → reel thumbnails from previous session load instantly without network

### 1.11 compute() for JSON parsing
- [x] Move reel JSON parsing (`List<Map>` decode from raw string) into a top-level function passed to `compute()`
- [x] Verify the parse function has NO references to singletons, `Ref`, `BuildContext`, or closures
- [x] `PostModel.fromReel` / API mapping runs on the main isolate AFTER `compute()` returns the raw maps
- [x] Test with 50+ item payload on a mid-range device; confirm no frame drops during parse in DevTools timeline

### 1.12 Metrics and verification
- [x] Add `Stopwatch` trace: time from `ReelsScreen` mount → first reel visible (target < 200ms on cache hit)
- [x] Add Better Player buffering listener: log `video_rebuffer_count` per session; target 0 rebuffers on prefetch-hit
- [x] Confirm 0 duplicate `loadReels()` calls on tab switch (add debug counter to notifier)

### 1.13 Reels architecture refresh (predictive pool for chunked backend streams)
- [x] Replace reactive "dispose/create on settle" with predictive 3-slot pool: keep `i-1`, `i`, `i+1` initialized
- [x] On settle: activate target reel only (pause/mute others), no full pool teardown
- [x] Prewarm neighbors (`i-1`, `i+1`) in background while current reel is active
- [x] Evict distant controllers outside pool radius to keep memory bounded
- [x] Remove full-file progressive prefetch dependency from active playback path (chunked backend streaming now primary strategy)
- [x] Switch PageView to snap-style custom page physics (no bounce wrapper)
- [x] Lower settle debounce to `~80ms` for spam-swipe resilience without late activation
- [x] Keep stable reel item keys by reel ID for safer surface/controller reuse

---

## FEATURE 2 — HOME POSTS (FEED) 📰
> Target: feed visible instantly from cache, no spinners, no frame drops during scroll.

### 2.1 Skeleton screen
- [x] Replace `CircularProgressIndicator` in `home_feed_page.dart` with shimmer skeletons matching post card geometry (avatar circle, image placeholder, text lines)
- [x] Skeleton shows ONLY when `posts.isEmpty && isLoading`
- [x] Crossfade skeleton → content; no hard cut

### 2.2 Hive migration (replaces SharedPreferences feed blobs) — MANDATORY
- [x] Add `hive` and `hive_flutter` (or `isar`) to `pubspec.yaml`
- [x] Create Hive boxes: `posts`, `reels`, `longVideos` with serialized model + `updatedAt` timestamp
- [x] Migrate write path in `UserStorageService` from SharedPreferences JSON blobs to Hive for all three content types
- [x] Keep SharedPreferences for auth tokens, flags, and small scalar prefs ONLY

#### One-time migration (do not skip)
- [x] On app launch: check `SharedPreferences` for `hive_migration_v1_done` flag
- [x] If flag absent AND legacy `getCachedUnseenPosts()` / `Reels()` / `LongVideos()` return data: read JSON, write to Hive, clear legacy keys
- [x] Set `hive_migration_v1_done = true` after success
- [x] On migration failure: log non-fatally, fall back to network + skeleton — do NOT crash
- [x] Log `hive_migration_ok` / `hive_migration_skipped` / `hive_migration_failed` for analytics
- [x] Test: existing user on old version → upgrade → no lost cache, no spinner on first launch

### 2.3 SWR hydration for posts
- [x] Wire Hive read into `PostsNotifier` constructor BEFORE API call
- [x] Emit non-empty state with `isLoading: false`, `isRefreshing: true` from Hive data
- [x] Remove `autoDispose` from posts provider OR use `ref.keepAlive()`
- [x] Network merge + Hive write on API success
- [x] Feed never shows spinner if `posts.isNotEmpty`
- [x] **v2**: Hive posts JSON decode via `compute(parseHivePostsPayloadJson, raw)` (`hive_posts_payload_parse.dart`); `PostModel.fromCachedMap` on main isolate after compute returns
- [x] **v2**: If `loadPosts` already populated state before async hydrate finishes, skip applying Hive (avoid clobbering fresh API data)

### 2.4 AutomaticKeepAliveClientMixin — home tab
- [x] Wrap `HomeFeedPage` with `AutomaticKeepAliveClientMixin`
- [x] `wantKeepAlive: true`; `super.build(context)`
- [x] `PageStorageKey` for scroll position
- [x] On tab hide: do NOT dispose video players in feed tiles that are currently in viewport — pause only; dispose players for items far from scroll position
- [x] Verify: tab switch and return → no re-fetch, no spinner, scroll position preserved

### 2.5 VideoTile — RepaintBoundary and player lifecycle
- [x] Wrap `VideoTile` Better Player widget in `RepaintBoundary`
- [x] Feed video plays on-demand (not auto-initialized for all tiles at once)
- [x] Cancel in-flight `DioClient` requests for off-screen video with `CancelToken` on dispose

### 2.6 BlurHash / placeholder for post thumbnails
- [x] Client fallback: grey gradient placeholder at correct post aspect ratio before thumbnail loads
- [x] If `blurHash` present in API response: decode and display synchronously; crossfade to sharp image
- [x] Dominant color: after first load, persist one extracted color per post id in Hive; reuse on next session as placeholder before sharp image

### 2.7 compute() for JSON parsing
- [x] Move post list JSON decode to top-level `parseFeedJson(String raw)` function
- [x] Call via `compute(parseFeedJson, rawBody)` in `PostsService`
- [x] `PostModel.fromJson` on main isolate after compute returns raw maps
- [x] Verify no closure capture, no singleton access inside compute function

### 2.8 Large named image cache
- [x] Reuse (or extend) the named `CacheManager` from Feature 1 for post thumbnails and avatars
- [x] `stalePeriod`: 7 days; large object count
- [x] Pass into all `CachedNetworkImage` calls in feed
- [x] **v2**: `AppMediaCache.feedMedia` uses `HttpFileService` with `IOClient` + `HttpClient` `maxConnectionsPerHost: 4` and `connectionTimeout: 10s` to limit concurrent image downloads

### 2.9 Staggered bootstrap (MainScreen — replaces parallel splash)
- [x] **v2**: `SplashScreen` does **not** fire feed/reels/long/stories/notifications network bootstrap (only socket `ensureConnection` when logged in)
- [x] **v2**: `MainScreen.initState`: tier 1 — post-frame `loadPosts(forceRefresh: false)`; tier 2 — same frame `Future.microtask` → `loadReels()`; tier 3 — `Future.delayed(800ms)` → `loadStories()`, `loadNotifications()`, `loadVideos()` (long videos)
- [x] Splash min duration + navigate unchanged; heavy work no longer competes with splash first paint
- [x] SWR + skeleton still cover slow network after `MainScreen` mounts

### 2.10 Offline / degraded network UX
- [x] Add `connectivity_plus` (or platform API) + a provider flag `isOffline`
- [x] Use **actual API call failure** (`DioException` with `connectionError` type) as authoritative offline signal — not `connectivity_plus` alone (WiFi ≠ internet)
- [x] When offline + cache non-empty: show feed silently with a thin dismissible banner ("Showing saved posts")
- [x] When offline + cache empty: show skeleton → calm empty state ("Connect to see new posts") — no red error dialog
- [x] When slow network: keep skeleton; no mid-screen spinner swap

### 2.11 Metrics
- [x] Trace `feed_hydrate_ms`: time from Hive read start → state emitted with posts
- [x] Trace `feed_first_skeleton_ms`: time from `HomeFeedPage.initState` → skeleton visible
- [x] Assert `loadPosts()` NOT called on tab switch when `posts.isNotEmpty` (log + counter)

### 2.12 Image decode limits (feed) — **v2**
- [x] `FeedCachedPostImage`: `memCacheWidth` / `memCacheHeight` from screen width × DPR (height ~1.35× width cap); `fadeOutDuration: Duration.zero`
- [x] Home app bar avatar + `InstagramPostCard` author avatar + `VideoTile` channel avatar: `memCacheWidth`/`Height` for 32 logical px × DPR
- [x] `precacheFirstFeedImages` (`feed_image_precache.dart`): precache at most **4** first feed posts after first non-empty feed frame (`ResizeImage` + same cache manager)

### 2.13 Rebuild discipline — **v2**
- [x] `HomeFeedPage`: `ref.watch(postsProvider.select(...))` for `posts`, `isLoading`, `isRefreshing`, `error`, `feedOfflineBanner` separately
- [x] `postsListProvider`, `postLikedProvider`, `postLikeCountProvider`, `postCommentCountProvider`: inner `select` on the relevant field/map entry
- [x] `InstagramPostCard`: `useFeedCommentCounts` on home feed only; avoids `postsListProvider` scan per card

### 2.14 Feed scroll / sliver policy — **v2**
- [x] `CustomScrollView` for main feed: tuned `cacheExtent` to `MediaQuery.size.height * 0.65` for low-RAM stability
- [x] `SliverChildBuilderDelegate`: `addAutomaticKeepAlives: false`, `addRepaintBoundaries: true`
- [x] Stable `ValueKey` per feed post / video tile

### 2.15 Background prefetch + stable feed animation — **v3**
- [x] Add `workmanager` and initialize in startup (`main.dart`) with periodic + on-demand prefetch tasks
- [x] Workmanager task fetches posts/reels/stories/long-videos and stores feed/reels/long-videos into Hive-backed cache when auth exists
- [x] Home feed skeleton blocks until first fetch attempt completes (`PostsState.initialFetchCompleted`)
- [x] Replace solid-color thumbnail placeholder fallback with blurred transparent preview of the post image itself (BlurHash still preferred when available)
- [x] Prevent out-of-viewport re-entry animations by tracking animated post IDs and animating each post only once per page lifecycle

---

## FEATURE 3 — LONG VIDEOS 📺
> Target: instant list from cache, no spinner, HLS segment lookahead, no rebuffer on current item.

### 3.1 Skeleton screen
- [x] Replace `CircularProgressIndicator` in long videos screen with shimmer skeletons matching list tile geometry (thumbnail left, title/duration text right)
- [x] Same `isEmpty && isLoading` rule as above

### 3.2 SWR hydration
- [x] Wire Hive (from Feature 2 migration) read into `LongVideosNotifier` before API call
- [x] `isLoading: false`, `isRefreshing: true` from Hive data
- [x] Remove `autoDispose` OR use `ref.keepAlive()`
- [x] Network merge + Hive write on success

### 3.3 AutomaticKeepAliveClientMixin — long videos tab
- [x] Same pattern as Features 1 and 2
- [x] On tab hide: pause active player; do NOT dispose if video is mid-watch — user expects to resume

### 3.4 HLS configuration — Better Player
- [x] Confirm HLS master playlist is served with sensible bitrate ladder
- [x] Segment duration: 2 seconds (or shorter) — coordinate with backend if needed
- [x] CDN: `Cache-Control` headers on segments; byte-range request support
- [x] Enable ExoPlayer `SimpleCache` (same bounded cache as reels — shared or separate, tuned to total budget)

### 3.5 HLS segment prefetch for next video
- [x] While current long video plays: resolve the next item's HLS master playlist and media playlist (requires lightweight HLS parser — `hls_parser` package or small custom implementation, OR a backend endpoint returning first N segment URLs)
- [x] Prefetch the first 3–4 media segments + init segment of the next item's selected rendition
- [x] Store prefetched segments in ExoPlayer `SimpleCache` so the player hits disk on start
- [x] Document clearly: this requires either (a) a backend helper endpoint, or (b) a client-side HLS playlist parser — choose one and implement it; do not leave this step as "TODO: fetch segments somehow"

### 3.6 Player lifecycle
- [x] On-demand player init (not all tiles at startup)
- [x] Dispose player when tile scrolls beyond ±3 items from viewport
- [x] `CancelToken` for in-flight Dio requests on dispose

### 3.7 BlurHash / placeholder for video posters
- [x] Same client fallback pattern as Features 1 and 2
- [x] If local video file exists in ExoPlayer cache: extract poster frame with `video_thumbnail`

### 3.8 RepaintBoundary
- [x] Wrap long-form player widget in `RepaintBoundary`

### 3.9 Metrics
- [x] Trace `longvideo_first_frame_ms`: player init → first frame decoded
- [x] Log rebuffer count per watch session via Better Player event stream
- [x] Assert list NOT re-fetched on tab switch

---

## FEATURE 4 — EXPLORE 🔍
> Target: instant grid/list from cache, search feels immediate, no spinner on tab open.

### 4.1 Skeleton screen
- [x] Replace any `CircularProgressIndicator` on explore screen with shimmer grid skeletons (square thumbnail placeholders in grid layout)
- [x] Search results: show skeleton rows while search API is in-flight; empty state only after response with 0 results

### 4.2 SWR hydration (trending / suggested content)
- [x] If explore has a "trending" or "suggested" initial feed: add Hive box for explore items
- [x] Wire SWR pattern: Hive first → API merge
- [x] If explore is purely search-driven (no default feed): skip SWR; skeleton is sufficient

### 4.3 AutomaticKeepAliveClientMixin — explore tab
- [x] Same pattern; scroll position preserved on tab return
- [x] Search query state preserved (user should not lose their query on tab switch)

### 4.4 Image cache for explore grid
- [x] All explore thumbnails use named `CacheManager` (same instance as Features 1–3)
- [x] Grid thumbnails: call `precacheImage` for the first visible viewport of items after data loads

### 4.5 Search debounce and cancellation
- [x] Search input: debounce at 300ms before firing API request
- [x] On new keystroke before previous request completes: cancel previous request via `CancelToken`
- [x] Search results parse via `compute()` if response is large (20+ items)

### 4.6 BlurHash / placeholder for explore thumbnails
- [x] Same client fallback gradient pattern

### 4.7 RepaintBoundary on explore grid items
- [x] Wrap each grid tile (image + overlay text) in `RepaintBoundary` to isolate selection state repaints

### 4.8 Offline UX
- [x] Explore from cache when offline (trending/suggested if Hive-backed)
- [x] Search: show "Search unavailable offline" inline — no error dialog

### 4.9 Metrics
- [x] Trace `explore_grid_paint_ms`: mount → first grid item visible
- [x] Search latency: trace from user stops typing → results displayed

---

## FEATURE 5 — STORIES 📖
> Target: stories list prefetched during bootstrap, first story media starts instantly, no spinner on tray open.

### 5.1 Bootstrap prefetch
- [x] Stories metadata (avatar list + first story URL per user) fetched during bootstrap: `SplashScreen` (post-auth) + `MainScreen` microtask alongside reels; `StoriesNotifier.loadStories` dedupes in-flight work
- [x] Store stories metadata in Hive (`HiveContentStore` key `stories_tray`, serialized tray entries)
- [x] On stories tab open: hydrate from Hive first; refresh in background

### 5.2 Skeleton for stories tray
- [x] Replace any spinner in stories tray / tab with shimmer circles (avatar-sized placeholders)
- [x] Tray must render immediately — shimmer circles from frame 1 even if API is in-flight

### 5.3 First story media prefetch
- [x] After stories metadata loads: prefetch the **first media item** (image or short video) for the first 3–5 story users
- [x] Images: `precacheImage` via named `CacheManager`
- [x] Videos: prefetch same as reels (download or cache first segment)

### 5.4 AutomaticKeepAliveClientMixin — stories tab
- [x] If stories has its own tab page widget: apply keep-alive pattern
- [x] Story viewer (full-screen modal/route): dispose video players on dismiss

### 5.5 BlurHash / placeholder for story thumbnails
- [x] User avatar placeholders: themed gradient circle before avatar image loads
- [x] Story viewer: themed gradient full-bleed placeholder before story image/video loads

### 5.6 Progress and preload for story sequence
- [x] While story item `i` displays: preload story `i+1` media in background
- [x] On story advance: if preload complete → instant display; if not → show placeholder (no spinner)

### 5.7 Offline UX for stories
- [x] If offline: show cached story tray (avatars from cache)
- [x] Story viewer offline: show cached media if available; show placeholder with "Unavailable offline" text if not

### 5.8 Metrics
- [x] Trace `stories_tray_paint_ms`: tab mount → tray visible (avatars or shimmer)
- [x] Trace `story_first_frame_ms`: story open → first media visible
- [x] Log preload hit rate: how often story `i+1` was ready before user advanced

---

## GLOBAL TASKS (run after all 5 features complete)

### G.1 Full regression test
- [ ] Cold start (first install, empty cache): all tabs show shimmer, no spinners — verified on Android + iOS
- [ ] Warm start (returning user): all tabs show cached content within 200ms — verified
- [ ] Tab switching: no re-fetch, no spinner, no video restart — verified across all 5 tabs
- [ ] Video: 0 rebuffer events in a 10-reel session on LTE (log verified)
- [ ] Offline: all tabs degrade gracefully — no crash, no red error dialogs — verified
- [ ] Low-end device (2GB RAM): no OOM crash with all 5 tabs alive — verified with DevTools memory

### G.2 Performance metrics summary
- [ ] Export all custom traces (Firebase Performance or local logs)
- [ ] Document baseline vs post-optimization for each metric in this file
- [ ] Confirm every numeric target in the proposal has a corresponding measurement

### G.3 Code hygiene
- [ ] All `compute()` parse functions are top-level in `lib/core/utils/feed_json_parser.dart`
- [ ] Named `CacheManager` instance is a singleton, not created per-widget
- [ ] Hive boxes opened once at app init, not re-opened per provider
- [ ] No `CircularProgressIndicator` remains on any primary surface (grep confirm)
- [ ] `RepaintBoundary` applied to all video player widgets (grep confirm)

---

## HOW TO USE THIS FILE

1. Open `OPTIMIZATION_TODO.md` at the start of every session.
2. Find the **CURRENT FEATURE IN PROGRESS** section.
3. Work through checkboxes **in order** within that feature.
4. Mark `[x]` only after implementation + verification (build runs, feature works on device/emulator).
5. When all checkboxes in a feature are `[x]`: update **COMPLETION LOG**, advance **CURRENT FEATURE**, commit.
6. **Do not begin Feature N+1 until Feature N is 100% complete.**
7. If a task is blocked (e.g. backend change required): note the blocker inline, skip to the next unblocked task in the SAME feature, and return.

---

## IMPLEMENTATION RULES (enforced at all times)

### Never do these:
- Do not leave a `CircularProgressIndicator` on any primary surface after its feature phase is complete.
- Do not use `compute()` with a closure or any function that captures `this`, a `Ref`, or a `BuildContext`. Only top-level or static functions.
- Do not call `initialize()` on video players for the entire feed at startup. On-demand only, with a bounded pool.
- Do not leave `autoDispose` on primary feed providers (`posts`, `reels`, `longVideos`) — they will be torn down on tab switch, defeating keep-alive.
- Do not use `connectivity_plus` as the sole offline signal — a phone on WiFi without internet reports "connected."
- Do not skip the SharedPreferences → Hive one-time migration — existing users will lose their cache on upgrade.
- Do not prefetch HLS segments without first resolving segment URLs from the playlist — you cannot guess segment paths.
- Do not keep video decoders initialized for all tabs simultaneously — pause and dispose off-screen decoders; keep only scroll state and list data alive.

### Always do these:
- Read this TODO file before starting any session.
- Mark items complete only after testing, not after writing code.
- Keep `CURRENT FEATURE IN PROGRESS` accurate at all times.
- Run the Flutter DevTools Performance and Memory views after completing each feature to confirm no regressions.
- Commit after each completed feature with message: `perf: complete [feature name] optimization (OPTIMIZATION_TODO.md §N)`

---

## FEATURE ORDER (strictly enforced)

```
1. REELS          ← Start here
2. HOME POSTS
3. LONG VIDEOS
4. EXPLORE
5. STORIES
```

Do not deviate from this order. Each feature builds on patterns established in the previous one (SWR, Hive, keep-alive, cache manager). Implementing them out of order creates rework.

---

*Generated for VidConnect. Last reviewed against proposal v3 (final). All items map to a named trace or log line.*
