# Long Videos Fix Plan

> Rule: Complete each section fully before starting the next.  
> Mark [x] only after implementation **and** manual verification.  
> No media_kit. No `setState` in long-videos feature code. Riverpod only.

---

## STATUS

**Current section:** Section 6 — Embedded handoff / resume (next)  
**Completed:** Sections 0–3 (code); Section 4 (code); Section 5 (code) — device verification for §2/§1/§3/§4/§5 pending  
**Also:** `VideoPlayerScreen` embedded strip: letterboxed slot + `setOverriddenFit(contain|cover)` by fullscreen vs embedded (YouTube-style framing).  

### STEP 0 — Audit summary (read before coding)

**Paths:** Video UI lives under `lib/features/video/` (there is no `lib/features/video_player/`).

| Question | Answer |
|----------|--------|
| Long video **list** state provider | `longVideosProvider` → `LongVideosNotifier` / `LongVideosState` in `lib/features/long_videos/providers/long_videos_provider.dart` |
| Per-tile widget state | `longVideoWidgetProvider` → `LongVideoWidgetNotifier` / `LongVideoWidgetState` in `lib/features/long_videos/providers/long_video_widget_provider.dart` |
| Tab index | `mainTabIndexProvider` (`lib/core/providers/main_tab_index_provider.dart`, `StateProvider<int>`). `main_screen.dart` sets `ref.read(mainTabIndexProvider.notifier).state = index` |
| `LongVideoWidgetState` fields | … includes **`isMuted`**, **`isBuffering`**; `warmUp()`, **`autoplay()`**, **`autoPause()`**, **`toggleMute()`** |
| `warmUp()` / `play()` / `pause()` | **`play()`** (unmutes), **`pause()`**, **`warmUp()`**, **`autoplay()`** (muted), **`autoPause()`** |
| BetterPlayer inline config | `_initializePlayer()` in `long_video_widget_provider.dart`: `BetterPlayerConfiguration` (16:9, cover, no controls), `BetterPlayerDataSource.network` + `longVideoNetworkCache`, buffering constants as in file |
| Bottom padding working pattern | `HomeFeedPage`: `EdgeInsets.only(top: 8.h, bottom: widget.bottomPadding)` on sliver padding. **Long videos:** `LongVideosPage` → `LongVideosScreen(bottomPadding)`; main `ListView` bottom padding + skeleton list `12 + bottomPadding`. |
| Search / feed player files | **`long_videos_search_screen.dart` entire file is commented out.** **`long_video_feed_player.dart` entire file is commented out.** Feed uses **`_buildVideoPlayer` inside `long_videos_screen.dart`** (Stack: thumbnail OR `SafeBetterPlayerWrapper`, plus play button) — not `LongVideoFeedPlayer` |
| `media_kit` / `MediaKit` in `lib/` | **Removed** (see Section 0). Previously: pubspec, main.dart, adaptive_track_selection, comments. |
| Long-video related provider lifetime | **`longVideosProvider`:** `ref.keepAlive()` ✓. **`longVideoWidgetProvider`:** `autoDispose` family. **`longVideoPlaybackProvider`:** read file to confirm (apply plan: manager should be keepAlive) |

**Git history:** `git log --oneline -20` shows general commits; no single commit message explicitly titled “revert media_kit” — treat repo state as source of truth.

---

## SECTION 0 — Cleanup: Remove All media_kit Remnants

### 0.1 Find and delete media_kit files

- [x] Run: `rg "media_kit|MediaKit|media_kit_video" lib/ -g "*.dart" -l` (or equivalent grep)
- [x] List every file returned by that grep
- [x] For each file: determine if it is ONLY used for media_kit  
      If yes → DELETE the file  
      If no → remove only the media_kit parts, keep the rest
- [x] Check `pubspec.yaml`: confirm no media_kit dependency remains
- [x] Run `flutter pub get` — confirm it resolves without media_kit

### 0.2 Check for broken imports

- [x] Run: `dart analyze` (scoped: long_videos + touched core files) — **0 errors**
- [x] Fix every error caused by removed media_kit files
- [ ] Confirm: full `flutter analyze` / release build on your machine

### 0.3 Verify reverted BetterPlayer code is intact

- [x] Confirm `BetterPlayerController` is used in long video widget notifier
- [x] Confirm `BetterPlayerController` is used in `VideoPlayerScreen` where applicable
- [x] Confirm no references to `Player()` or `VideoController()` from media_kit remain

---

## SECTION 1 — Bottom Padding Fix

### 1.1 Understand existing working pattern

- [x] Read how `main_screen.dart` passes `bottomPadding` to home tab
- [x] Read how `home_feed_page.dart` applies it
- [x] Document the exact pattern: which widget wraps with padding, where

### 1.2 Apply same pattern to long videos

- [x] Find `LongVideosPage` — the thin wrapper widget
- [x] Confirm `bottomPadding` parameter exists or add it matching home pattern
- [x] Pass `bottomPadding` through to `LongVideosScreen`
- [x] Apply padding to the `ListView` / `CustomScrollView` bottom in `LongVideosScreen` using the same widget/approach as home — replicate exactly
- [ ] Verify: last video tile is fully visible above the bottom nav bar (**device**)

---

## SECTION 2 — Fix Double Video Player in Feed Tile

### 2.1 Audit feed tile

- [x] Read `_buildVideoPlayer` (and any other player builders) in `long_videos_screen.dart`
- [x] Find every place `BetterPlayer` / `SafeBetterPlayerWrapper` is rendered
- [x] Confirm at most **one** BetterPlayer in the Stack at any time  
      If two exist under any condition: remove the duplicate

### 2.2 Fix the visibility guard

- [x] Define `videoPaintVisible` (or equivalent) covering:  
      SHOW: playing && !buffering at t=0; SHOW: paused && position > `Duration.zero`;  
      HIDE: buffering at t=0; HIDE: controller null; HIDE: not initialized  
      Implemented as `_longVideoTileVideoPaintVisible` + `LongVideoWidgetState.isBuffering`.
- [x] Wrap BetterPlayer in **`AnimatedOpacity`** (opacity 0/1), not `Visibility(maintainState: false)` that disposes ExoPlayer
- [x] `RepaintBoundary` around BetterPlayer subtree and thumbnail subtree
- [ ] Verify: no double surfaces under any scroll/play/pause combination (**device**)

---

## SECTION 3 — YouTube-Style Autoplay (Pure Riverpod)

### 3.1 Create `LongVideoAutoplayManager` provider

- [x] Add `lib/features/long_videos/providers/long_video_autoplay_manager.dart`
- [x] `StateNotifierProvider` — **`ref.keepAlive()`** (survives tab switches)
- [x] State: `dominantVideoId`, `isEnabled` (ratios kept private in notifier, not in state)
- [x] `reportVisibility(videoId, fraction)` with hysteresis (per spec: re-elect when current &lt; 0.40; new candidate &gt; 0.60 and **stable across &gt; one report**)
- [x] Emit only when `dominantVideoId` (or required fields) actually change
- [x] `removeVideo`, `disable`, `enable`
- [x] No `setState` — pure `StateNotifier`

### 3.2 Wire `visibility_detector` into each tile

- [x] Add `visibility_detector` to `pubspec.yaml` if absent
- [x] Wrap tile (or `_buildVideoPlayer` subtree) with `VisibilityDetector` — `Key('lv_tile_${video.id}')`
- [x] `onVisibilityChanged` → manager.`reportVisibility`
- [x] `dispose` → `removeVideo`

### 3.3 React to dominant changes

- [x] In `LongVideosScreen.build`: `ref.listen` manager **`.select((s) => s.dominantVideoId)`**
- [x] Dominant → `autoplay()`; lost dominant → `autoPause()`
- [x] Implement **`autoplay()`** / **`autoPause()`** on notifier (or extend existing): muted autoplay, near-end seek, no dispose on autoPause

### 3.4 Mute toggle

- [x] Add `isMuted` to `LongVideoWidgetState`; `toggleMute()` on notifier
- [x] Feed tile: **no** inline play/pause/seek/mute controls — tap opens `VideoPlayerScreen` only; autoplay + thin progress bar for dominant tile; `prefetchNextAfter` on dominant autoplay

### 3.5 Thin progress bar

- [x] Reuse `position` / `duration` on state; `LinearProgressIndicator` height 2, dominant-only (plus **500ms** position throttle in notifier listener)

### 3.6 Verify autoplay (manual checklist in original prompt)

- [ ] … (all scenarios from prompt)

---

## SECTION 4 — Restore Long Video Search Screen

### 4.1 Locate commented screen

- [x] File: `lib/features/long_videos/long_videos_search_screen.dart` (restored; replaced commented file)
- [x] Thumbnail + tap → `VideoPlayerScreen` only; filter via Riverpod (`longVideoFeedSearchQueryProvider` + `longVideoSearchFilteredProvider`) — **no** `setState`

### 4.2 Restore without media_kit

- [x] Active implementation; no media_kit, no inline BetterPlayer in search rows

### 4.3 Wire navigation

- [x] Search icon in `LongVideosScreen` header → `LongVideosSearchScreen(bottomPadding: …)`

### 4.4 Verify search

- [ ] Results, tap opens player, analyze clean (**device**)

---

## SECTION 5 — Warmup and Pool Management

### 5.1 Staggered warmup on scroll

- [x] Public **`warmUp()`** on notifier — **no-op when already initialized** (scroll pool must not reset in-view playback)
- [x] Debounce **120ms**, stagger **48ms**, pool **±2** around estimated viewport center (`LongVideosScreen`)

### 5.2 Eviction

- [x] **`longVideoSavedPositionProvider`** (`Map` post id → position ms); **`release()`** on tiles leaving warm pool; skip **dominant** id; fullscreen uses `videoPlayerProvider` (separate from inline family)

### 5.3 Tab lifecycle

- [x] Leave tab **3** → cancel warm debounce timer + existing pause/disable; return to tab **3** → `enable()` + post-frame **`_applyScrollWarmPool()`**

---

## SECTION 6 — Open VideoPlayerScreen (Instant Feel)

### 6.1 Capture position

- [ ] Read position from `LongVideoWidgetState` before pause
- [ ] Pause inline (no dispose)
- [ ] Set `longVideoEmbedResumeHintProvider` (exists in `lib/core/providers/long_video_embedded_handoff_provider.dart`)

### 6.2 Navigation

- [ ] `PageRouteBuilder` slide-up ~300ms
- [ ] `VideoPlayerScreen` consumes resume hint in notifier init

### 6.3 Return from route

- [ ] Re-enable manager; delay ~350ms; re-warm tile; autoplay re-elects

---

## SECTION 7 — Final Verification

- [ ] `flutter analyze` — zero errors
- [ ] `rg "media_kit|MediaKit" lib/` — zero results
- [ ] `rg "setState" lib/features/long_videos/` — zero matches in **active** (non-comment) code
- [ ] No double video surfaces; bottom padding; search; autoplay; tab switch; resume position; stress scroll (20+ tiles); background

---

## IMPLEMENTATION RULES — ENFORCED

**Prohibitions:** No media_kit; no `setState` in long-videos feature; no duplicate BetterPlayer in one tile; no new packages without checking `pubspec.yaml`; extend existing providers before inventing; do not dispose inline controller on push to `VideoPlayerScreen` (pause only); **`longVideosProvider` must stay keepAlive**; autoplay drives play — no feed play button if spec requires.

**Practices:** Read full file before edit; `ref.watch(...select(...))` for single fields; `ref.listen` for play/pause side effects; guard `warmUp`; `mounted` after `await`; `BetterPlayerEventType.exception` → dispose + reset via post-frame callback; `RepaintBoundary` on thumbnail + player; `ValueKey(video.id)` on tiles; throttle position updates (max 1 / 500ms while playing).

---

## COMMIT CONVENTION

After each verified section:

`git commit -m "fix(long-videos): section [N] - [name] complete"`

One commit per section.

---

## SUCCESS CRITERIA (end state)

- No `media_kit` in repo or dependencies  
- Muted autoplay, scroll handoff, tab pause/resume  
- Slide-up fullscreen with correct resume time  
- Search restored  
- Bottom nav does not overlap content  
- No duplicate surfaces  
- No `setState` in long-videos feature tree  
