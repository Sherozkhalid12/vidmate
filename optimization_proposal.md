# VidConnect — Performance & Preload Optimization Proposal

This document describes how to meet **strict client requirements**—**no loaders** (no blocking spinners; perceived instant UI) and **no perceptible buffering** (video starts smoothly; next items prepared)—while moving toward Instagram-class behavior. It is grounded in the **current codebase** (Riverpod, `UserStorageService`, `MainScreen` + `PageView`, `ReelsScreen` / `VideoTile` / Better Player, splash → main).

---

## 0. Client contract (non-negotiable UX)

| Requirement | Meaning in product |
|-------------|-------------------|
| **No loaders** | Users must **never** see a full-screen or blocking **`CircularProgressIndicator`** for primary surfaces (home, reels, long videos). **First-ever install** with empty cache: show **shimmer skeleton screens** that match layout—not spinners. Returning users: **instant content** from cache while network refreshes silently. |
| **No buffering** | Playback should not stall mid-watch for **prepared** content. Achieved by **server-encoded fast-start media**, **full preload of the next short-form clip(s)** where feasible, **HLS segment lookahead** for long form, and **ExoPlayer disk cache**—not by pretending the network is infinite. |

**Honest boundary**: Infinite catalogs cannot be fully pre-downloaded. The contract is satisfied when **everything the user is about to see** (current + next 1–2 items, first screen of feed) is **buffer-complete or fast-start**, and any rare stall is **invisible** behind blur thumbnails and skeletons—not spinners.

---

## 1. Strict implementation order (maps complaints → fixes)

Execute in this order so each step removes loaders, jank, or buffering before moving on. Items framed elsewhere as “Phase 3 polish” are **core** here if they directly cause a loader or frame drop.

| Priority | Item | Why it’s first |
|----------|------|----------------|
| **1** | **Skeleton / shimmer screens** everywhere lists can be empty | Pure UI; **instant perceived load** on first install; Instagram / TikTok / YouTube pattern. No dependency on backend. |
| **2** | **SWR hydration** — wire `getCachedUnseenPosts` / `getCachedUnseenReels` / `getCachedUnseenLongVideos` into providers **before** network | Fixes a **bug in disguise**: cache exists but is unread → eliminates most spinners for **returning** users immediately. |
| **3** | **MP4 faststart (moov atom front)** on CDN / upload pipeline — **server-side** | **Zero client work**; removes the most common cause of “buffering” on progressive MP4 (player must fetch end of file for index). Use FFmpeg `-movflags +faststart`. |
| **4** | **`AutomaticKeepAliveClientMixin`** on each main tab (`wantKeepAlive: true`) | **~5 lines per tab**; stops Flutter from **disposing and rebuilding** tab trees on `PageView` switches → no **re-fetch / re-spinner** when switching Home ↔ Reels ↔ Long Videos. Today `_buildPage` returns raw widgets with no keep-alive. |
| **5** | **BlurHash or ThumbHash** in API + client decode — **ship §5.2 placeholders first** if backend lags | **Zero network** for first paint when API has hash; **§5.2** (gradient / dominant color / local frame) unblocks you without server. |
| **6** | **Hive** (or Isar) for feed persistence — **replace SharedPreferences JSON blobs for feeds** | Large JSON in SharedPreferences **deserializes on the main isolate** → **jank spike** at cold start when feed has 20+ posts. Hive is Flutter-native, fast, minimal setup. **Not optional “Phase 3”** for this client. |
| **7** | **Parallel bootstrap** — `Future.wait` during splash animation | The **~2.5s splash is dead time** today; overlap **all** critical GETs with the animation after auth. |
| **8** | **ExoPlayer `SimpleCache`** + **bounded video prefetch** | Disk hits for repeats; for **reels (15–30s)**: **download entire next (and next+1) file** to disk/memory **while current plays**—not “first X MB” only. For **long form HLS**: **2s segments** + preload **first 3–4 segments** of the **next** item while current plays. |
| **9** | **`compute()`** (or isolate) for **large JSON parse** | 50+ posts: parsing **`Map` → models on the UI thread** drops frames; offload decode. |
| **`10`** | **`flutter_cache_manager`** — **named** `CacheManager` for images | Defaults are **small and aggressive**; configure **large max size (e.g. 500MB+)** and **long staleness (7+ days)** so thumbnails from yesterday are **instant** today. Pass into `CachedNetworkImage` / custom `ImageProvider`. |

After this list: incremental sync APIs, `WorkManager` / iOS background refresh, tab **metadata** warming when adjacent tab is idle—these are **extensions**, not prerequisites for the client contract.

---

## 2. Current architecture (baseline)

### Cold start

- `main.dart` → `SplashScreen` (~2.5s), auth from storage → `MainScreen`.
- **No parallel API work** during splash; feeds start when providers/tabs run.

### Data loading

- **`PostsNotifier`**, **`ReelsNotifier`**, **`LongVideosNotifier`**: constructor triggers API → **`isLoading: true`** → **`CircularProgressIndicator`** when list empty (`home_feed_page.dart`, `reels_screen.dart`, long videos screen).
- **Stories**: `refresh()` on tab open (`MainScreen._onPageChanged`).

### Caching today

- **`UserStorageService`**: writes unseen posts/reels/long videos to **SharedPreferences** (JSON in user map); **`getCachedUnseen*` never hydrates providers**.

### Tabs

- **`PageView.builder`** builds each tab; without **`AutomaticKeepAliveClientMixin`**, off-screen tabs can be **discarded** → returning to a tab can **re-run heavy init** and feel like a reload.

### Video

- **Reels**: `VideoPlayerController.networkUrl` — stream; neighbor init only; **no full next-file preload**, no shared ExoPlayer cache with feed.
- **Feed / long**: Better Player; on-demand init.

### Images

- **`cached_network_image`** without a documented **large named cache** → eviction can cause repeat **pop-in**.

---

## 3. UI requirement: skeleton screens (not “remove spinner” only)

**Rule**: Any screen that today shows **`CircularProgressIndicator`** while `list.isEmpty && isLoading` must show a **shimmer skeleton** whose **geometry matches the real layout** (post card rows, reel full-bleed placeholder, long-video list tiles).

- Use a package such as **`shimmer`** or custom **`AnimatedOpacity` + grey boxes**.
- **Skeleton ≠ empty state**: skeleton = “content is on the way”; empty state = “no posts” after load.
- **SWR**: when cache hydrates, **crossfade** skeleton → content in one frame if possible.

This satisfies **“no loaders”** for first-time users: the app feels **instant** even before the first byte of JSON returns.

---

## 4. Video and buffering — concrete strategy (by format)

Client expectation **“no buffering”** is met with **stacked** fixes; no single line item is enough.

### 4.1 Server / encoding (mandatory if you control files)

| Format | Action |
|--------|--------|
| **Progressive MP4** (reels, short clips) | **Faststart**: `ffmpeg -movflags +faststart` so **moov** is at the **start** of the file. Without this, the player often **seeks to the end** before playback → **visible stall**. **Cost: zero on client.** |
| **HLS** (long form) | **2-second (or shorter) segments**; CDN **byte-range** + **cache headers**; **master playlist** with sensible ladder. |

### 4.2 Short-form (reels, ~15–30s)

- **Preload the entire next video** (and optionally **next+1**) to **disk** via `HttpClient` / download task / cache manager **while the current reel plays**.
- Initialize the player from **file URI** once download completes (or hybrid: start stream if user swipes early, but **default path** is full file ready).
- For 15–30s clips at mobile bitrates, **full-file prefetch** is **feasible** and matches **“no buffering on swipe”** better than “first N MB only.”

### 4.3 Long-form (HLS)

- **ExoPlayer `SimpleCache`** (via Better Player) with a **bounded size** (e.g. 256MB–1GB).
- While current item plays, **prefetch the first 3–4 media segments** of the **next** HLS asset (init + segments), in addition to player buffer for current.
- Unify reels onto **Better Player** if needed so **one cache** and **one prefetch** story applies app-wide.

### 4.4 Player lifecycle

- **Small pool** (2–3 controllers); **reuse**; do not `initialize()` the whole feed at startup.
- Dispose indices farther than **±3** from current (align with existing reel disposal threshold).

---

## 5. BlurHash / ThumbHash (thumbnails before video)

**Problem**: If the thumbnail **arrives late**, the UI feels slow even when video is fast.

### 5.1 Ideal path (requires backend cooperation)

BlurHash/ThumbHash is **not** a switch you flip: the server must **encode every uploaded image/poster** (encoder job), **persist** the string, and **expose** it on every relevant API. If backend is slow or resistant, **do not block** client shipping on this alone—use **§5.2** from day one.

1. **Backend**: Run uploads through a **BlurHash** or **ThumbHash** encoder; store on the media record.
2. **API**: Include `blurHash` / `thumbHash` on post, reel, and story objects.
3. **Client**: Decode to a small bitmap or shader-backed placeholder **synchronously**, then **crossfade** to `CachedNetworkImage` when the URL loads.

**Packages**: `blurhash_dart` / `flutter_blurhash`, or ThumbHash equivalents.

### 5.2 Client-only fallbacks (ship without backend)

Implement **in priority order** so placeholder work is never gated on server:

| Fallback | When to use |
|----------|-------------|
| **Themed grey → subtle gradient** | Always available; matches card aspect ratio; zero I/O. |
| **Dominant / accent color** | If you extract **one color** from a **cached** full image (after first load), persist it with the post id in Hive and reuse on next open—**second visit** improves without API changes. |
| **Low-res cached thumbnail** | `CachedNetworkImage` / disk cache hit paints before network round-trip for remote URL. |
| **Local video frame** (see **§5.3**) | When the **video file** already exists on disk from prefetch or prior watch. |

**Rule**: First paint must **never** be a blank hole or a spinner—**gradient or blur** always.

### 5.3 Local video frame as thumbnail (before network thumbnail)

For reels/feed items where **`thumbnailUrl` is still loading** but a **cached video file** exists (prefetch, ExoPlayer cache, or prior session), generate a **poster frame** locally:

- Use a package such as **`video_thumbnail`** (`VideoThumbnail.thumbnailFile`) or platform channel equivalent to read **one frame** from the local path.
- Show that **bitmap immediately**; replace with network thumbnail when it arrives if sharper.

This is a **small, visible win** and is **not** a substitute for BlurHash when no local file exists—combine with **§5.2** for full coverage.

This is **independent** of `precacheImage`; use **all layers**—placeholder at **t=0**, BlurHash when API has it, local frame when file exists, network for **sharp** final image.

---

## 6. Stale-while-revalidate (SWR) — still the data-layer backbone

On provider init (or before navigation from splash):

1. **Read** Hive (or interim: `UserStorageService.getCachedUnseen*`) → map to `PostModel` **off main isolate** if list is large.
2. Emit state with **`posts` / `reels` non-empty**, **`isLoading: false`**, **`isRefreshing: true`** optional.
3. **Network** merge; write Hive; clear `isRefreshing`.

**UI**: Never show spinner when `items.isNotEmpty`. Use skeleton only when **empty and no cache**.

---

## 7. Hive (or Isar) — Phase 1 for this project, not “later scale”

**Why not defer**: SharedPreferences + `jsonDecode` for **large feed JSON** **blocks the UI isolate** at read time → **jank** at app start. The client’s “lag” complaint maps directly here.

**Scope**

- **Hive** boxes (or Isar collections) for: `posts`, `reels`, `longVideos` (serialized models + `updatedAt`).
- Keep SharedPreferences for **auth tokens, flags, small prefs** only.
- **New writes** go to Hive; **reads** for SWR come from Hive first.

**Capacity**: Store **more than 10** items (today’s unseen cap); tune to last N posts / pages.

### 7.1 One-time migration (mandatory—do not skip)

`UserStorageService` today stores feed-shaped data inside a **per-user JSON map** in SharedPreferences (`_userMapPrefix` + keys like `posts`, `reels`, `longVideos`). **Replacing** that with Hive **without** migration means **existing users** lose cached feeds on first launch after update → **skeletons + empty lists** until network returns → violates **“no loaders”** for returning users.

**Required steps on app upgrade**

1. On startup (once per app version or via a **`hive_feed_migration_v1_done`** flag in SharedPreferences):
   - If Hive boxes for feeds are **empty** and legacy `getCachedUnseenPosts` / `Reels` / `LongVideos` (or raw user map sections) **have data**, **read** that JSON.
   - **Write** deserialized rows into Hive in bulk.
2. **Clear** or **stop reading** the legacy feed keys from the user map (or remove migrated sections) so there is a **single source of truth** and no double-maintenance.
3. **Log** migration success/failure (non-fatal); on failure, fall back to network + skeleton—not a crash.

**Edge cases**: Logged-out user, corrupted JSON, partial map—migrate what is valid; never block app launch on migration.

---

## 8. Parallel bootstrap during splash

After `loadFromStorage()` and if logged in:

- Start **`Future.wait([...])`** for: posts, reels, long videos, stories, notifications, preferences (and optionally chat list)—**each future wrapped in try/catch** so failures are isolated.
- **Overlap** with the **2.5s** splash animation; optionally **`await` with timeout** (e.g. 2–3s) then navigate; **continue** unfinished requests after `MainScreen` mounts.
- **Do not** block navigation on full completion if deadline hits—SWR + skeleton already painted.

---

## 9. `flutter_cache_manager` — explicit configuration

**Default** `CachedNetworkImage` cache is **small** and **evicts aggressively**.

**Requirement**

- Instantiate a **named** `CacheManager` with e.g.:
  - **`stalePeriod`**: **7+ days** (or policy-aligned).
  - **`maxNrOfCacheObjects`** and/or **total size** targeting **500MB+** for thumbnail/object cache on mid-range devices (tune per product).
- Pass this manager into **`CachedNetworkImage`** (`cacheManager:`) everywhere feed/reels avatars and thumbnails load.

---

## 10. Main tabs: `AutomaticKeepAliveClientMixin` (with memory discipline)

**Issue**: `PageView.builder` without keep-alive **drops** off-screen children; switching tabs **rebuilds** `HomeFeedPage`, `ReelsScreen`, etc., which can **re-trigger** loading states and **re-init** video/widgets.

**Fix**

- Wrap each tab body in a **`StatefulWidget`** with **`AutomaticKeepAliveClientMixin`**, `@override bool get wantKeepAlive => true`, and call **`super.build(context)`** in `build`.
- Apply to: **`HomeFeedPage`**, **`ReelsPage`/`ReelsScreen`**, **`StoryPage`**, **`LongVideosPage`**, **`MusicPage`** (or the inner stateful core of each).

**Optional**: `PageStorageKey` per tab index for scroll position retention.

### 10.1 Memory warning (OOM on low-end devices)

Keeping **all five tabs alive** means their **State** objects, **scroll controllers**, and—if unmanaged—**video players** can all **reside in memory at once**. For **video-heavy** tabs, naive keep-alive + multiple initialized players risks **OOM** on **low-RAM** phones.

**Recommended pattern**

- **Keep alive**: **scroll position**, **list state**, **cached provider-driven data** (already in Riverpod/Hive)—the things that prevent **reload spinners** on tab return.
- **Do not** keep **playing** or **fully initialized** video pipelines for **off-screen** tabs: on tab **hide** (e.g. listen to `PageController` / index from parent, or `VisibilityDetector` / `RouteAware`), **pause**, **mute**, and **`dispose`** `VideoPlayerController` / **BetterPlayer** instances that belong to that tab; **re-create** when the user returns (cheap if **file/cache** is warm).

**Summary**: *Keep-alive the **shell and scroll**; **tear down active decoders** for tabs that are not visible.* This preserves the UX win without multiplying native video surfaces.

---

## 11. Isolates: `compute()` for JSON parsing

For **large** responses (e.g. 50+ posts):

- Parse **raw JSON string → `List<Map<String, dynamic>>`** (or plain DTO maps) inside **`compute(parseFeedJson, rawString)`** on a **background isolate**.
- On the **main isolate**, map those maps to **`PostModel`** (or call `PostModel.fromJson` **here**) and update providers.

Wire this in **`PostsService`**, **`ReelsService`**, **`LongVideoService`** (or a shared `feed_json_parser.dart`) **before** heavy parsing storms the UI thread.

### 11.1 Isolate boundary rules (common mid-sprint failures)

**`compute()` only accepts messages that can be sent across isolates.** The following **will break** at runtime if you ignore them:

| Rule | Detail |
|------|--------|
| **Top-level or static entry only** | The function passed to `compute` must be a **top-level function** or **static method**. **Closures** that capture `this` or locals are invalid. |
| **Arguments / return values** | Must be **sendable** (primitives, `List`/`Map` of sendables, `TransferableTypedData` patterns per SDK docs)—**not** `BuildContext`, **not** `Ref`, **not** custom classes with non-sendable fields unless you redesign. |
| **No services inside isolate parse** | If **`PostModel.fromJson`** (or nested code) touches **`DioClient`**, **`UserStorageService.instance`**, **providers**, or **singletons**, **do not** call it inside `compute`. **Split**: isolate returns **`List<Map>`**; main isolate runs `PostModel.fromJson` **only if** those factories are pure (no side effects). If `fromJson` is not pure, add **`PostModel.fromJsonStatic(Map)`** that only assigns fields, or use **code-generated** DTOs in the isolate. |
| **Test on device** | Debug vs release isolate behavior differs; verify with a **50+ item** payload. |

**Practical pattern**: `parseFeedJson(String raw) => (jsonDecode(raw) as List).cast<Map<String, dynamic>>();` as **top-level** in `feed_json_parser.dart` → `compute(parseFeedJson, body)` → loop `PostModel.fromApi...` on main isolate **after** verifying `fromJson` has **no hidden globals**.

---

## 12. `RepaintBoundary` around video surfaces

When a video plays in the **feed** or a **tile**, **sibling rebuilds** (like count, comment badge, socket-driven updates) can **invalidate** a large ancestor and force **expensive repaints** of the **video texture** subtree → **dropped frames** and **stutter**.

**Fix**: Wrap **`VideoTile`**, the **BetterPlayer** widget, and other **high-cost** subtrees in **`RepaintBoundary`**. This is typically **one widget** around the player stack; combine with **targeted `Consumer`/`Selector`** so only text/icons rebuild, not the player.

---

## 13. Network layer (unchanged essentials)

- **`DioClient`**: persistent connections; **HTTP/2** on server if available.
- **Retries** with jitter for idempotent GETs.
- **`CancelToken`** when leaving screens to prioritize prefetch bandwidth.

---

## 14. Offline and degraded network (still “no loaders”)

SWR already shows **cached** content when the API fails. **Specify behavior** so QA and design agree—avoid a **full-screen error** that feels like a loader failure.

| State | UX |
|-------|-----|
| **Offline**, cache **non-empty** | Show feed/reels from cache **silently**; optional **thin banner**: “You’re offline — showing saved posts” (dismissible). **No** blocking error sheet. |
| **Offline**, cache **empty** | **Skeleton** → then **calm empty state** (“Connect to see new posts”), not a red error dialog. |
| **Slow network** | Keep **skeleton** until first byte or cache paint; **do not** swap to spinner mid-screen. Background refresh can show **subtle** refresh indicator only if product allows. |
| **Stale timestamp** | Optional small “Updated 2h ago” when serving **only** cache—transparency without breaking **no-loader** feel. |

**Implementation hints**: `connectivity_plus` (or similar) + provider flag `isOffline`; gate **banners** only, not **data clearing**.

---

## 15. Metrics (verify the contract)—with **how** to measure

Targets are useless without **hooks**. Use at least one of the following per metric.

| Metric | Target (indicative) | **Where / how to measure** |
|--------|----------------------|----------------------------|
| **Time to first skeleton** | Visible same frame as route | **`Stopwatch`** in `HomeFeedPage.build` / first frame: start in `initState`, stop when skeleton widget is built; log in debug or **Firebase Performance** **custom trace** `feed_first_skeleton`. |
| **Time to cached content paint** | **< 200 ms** after `MainScreen` when Hive hit | Stopwatch: **start** at provider `hydrateFromHive()` entry, **stop** after `state = copyWith(posts: …)`; attribute trace `feed_hydrate_ms`. |
| **Tab switch** | No duplicate `loadPosts()` / no spinner | **Log** in notifier: `debugPrint` counter or **analytics event** when `loadPosts` invoked; assert **not** called on tab index change if data present. |
| **Rebuffer / stall** | **0** in prefetch-hit session | **Better Player** / **video_player** **listeners**: count `isBuffering == true` transitions while `isPlaying`; log **`video_rebuffer_count`** per session. **Firebase Performance**: trace `reel_session` with custom metric `rebuffer_count`. |
| **JSON parse jank** | Fewer UI jank frames post-change | **DevTools** Performance + **Timeline**; before/after **`compute()`** on 50+ item payload. Optional: **`FlutterTimeline`** or trace `json_parse_isolate_ms` around `compute`. |
| **Migration** | 100% eligible users migrated | Log **`hive_migration_ok`** / **`hive_migration_skipped`** / **`hive_migration_failed`** once per install version. |

**Rule**: Every numeric goal in this doc should map to **one trace name** or **one log line** before the sprint closes.

---

## 16. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Full-file reel prefetch on slow network | Cap concurrent downloads; fall back to stream + faststart MP4 |
| 500MB image cache on low-end devices | **Tiered limits** by `MediaQuery`/device class or user setting |
| Stale feed | SWR + pull-to-refresh; optional “Updated” chip |
| Memory (reels / multiple tabs) | Strict player pool; dispose far indices; **§10.1** — keep-alive **UI state**, **pause + dispose** off-screen **decoders** |
| Keep-alive OOM on low-RAM | Same as above; never leave **N** simultaneous **playing** players for **N** tabs |
| `compute()` misuse | **§11.1** — top-level parse only; `fromJson` stays on main isolate if non-pure |
| Hive upgrade without migration | **§7.1** — one-time copy from SharedPreferences; log outcomes |

---

## 17. Summary

This document sequences work for **no loaders** and **no perceptible buffering**: **skeletons**, **SWR**, **MP4 faststart**, **tab keep-alive with video teardown (§10.1)**, **BlurHash with client-only fallbacks (§5.2)**, **local video-frame thumbnails (§5.3)**, **Hive with mandatory SharedPreferences migration (§7.1)**, **parallel splash bootstrap**, **full next-reel prefetch + HLS lookahead**, **`compute()` with isolate rules (§11.1)**, **large named image cache**, **`RepaintBoundary` on video surfaces**, **offline/degraded UX (§14)**, and **named metrics/traces (§15)**. Together they address implementation risks called out in review—backend delays, isolate boundaries, memory, migration, repaint jank, and unmeasurable goals.

---

## 18. File reference map (for implementers)

| Area | Primary files |
|------|----------------|
| App entry | `lib/main.dart` |
| Splash | `lib/features/splash/splash_screen.dart` |
| Tabs / PageView | `lib/features/main/main_screen.dart` — add keep-alive wrappers here or in each page |
| Feed UI | `lib/features/home/home_feed_page.dart` — skeletons, cache manager |
| Reels | `lib/features/reels/reels_screen.dart`, `reels_page.dart` |
| Posts / reels / long state | `lib/core/providers/posts_provider_riverpod.dart`, `reels_provider_riverpod.dart`, `long_videos_provider.dart` |
| Local storage + migration | `lib/services/storage/user_storage_service.dart`; add **`hive_feed_migration`** (or app bootstrap) per **§7.1** |
| Feed video | `lib/core/widgets/video_tile.dart` — **`RepaintBoundary`**; `lib/core/providers/video_player_provider.dart` |
| JSON isolate entrypoint | e.g. `lib/core/utils/feed_json_parser.dart` — **top-level** `parseFeedJson` only (**§11.1**) |
| Offline banner | New small provider using `connectivity_plus` (or platform APIs) — **§14** |
| HTTP / parse | `lib/core/api/dio_client.dart`, `lib/services/posts/*.dart` |

This document is **implementation-ready** and **ordered for the client’s strict requirements**.
