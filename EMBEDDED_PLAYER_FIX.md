# Embedded Player Fix Plan

> Complete each item fully before the next.
> Mark [x] only after implementation AND device verification.

---

## FIX 1 - Stop disposing inline controller before navigation

### Root cause confirmed:
- [x] Transition path uses pause + detach handoff, not direct inline dispose before push.

### Fix:
- [x] In long-videos tap transition, keep pause-only behavior before navigation (no inline dispose path added).
- [x] Disable autoplay manager before push.
- [x] Write resume hint before push.
- [x] Re-enable autoplay manager after pop.
- [x] Added post-pop stabilization delay (350ms) before reactivation.
- [ ] Verify on device: `BufferQueue has been abandoned` removed/reduced to non-cascading transient lifecycle logs.
- [ ] Verify on device: no double active ExoPlayer for same URL during open/close loop.

---

## FIX 2 - Wait for initialized event before calling play()

### Root cause confirmed:
- [x] Embedded provider path could call `play()` without guaranteed initialized sequencing.

### Fix:
- [x] Added `_waitForInitializedEvent(...)` with `Completer` + 10s timeout.
- [x] Embedded non-handoff path now waits for initialized (or timeout) before `play()`.
- [x] Handoff path with `resumePlayback` now waits for initialized before `play()`.
- [x] Kept `autoPlay: false` in embedded BetterPlayer config.
- [ ] Verify on device: video starts on open consistently (no frozen first frame).

---

## FIX 3 - Use `startAt` instead of early `seekTo` for initial resume

### Root cause confirmed:
- [x] Initial resume relied on later seek/event timing.

### Fix:
- [x] Embedded config now sets `BetterPlayerConfiguration(startAt: resumeFrom)`.
- [x] Removed pre-init resume seek path for embedded cold start.
- [x] Kept user-initiated seek methods unchanged.
- [ ] Verify on device: open position matches inline position (+/- 2s).
- [ ] Verify on device: no seek-to-zero flash before resume.

---

## FIX 4 - Guard `warmUp/autoplay/autoPause` while embedded is open

### Root cause confirmed:
- [x] Warm/autoplay operations could run during embedded lifecycle and compete with transition.

### Fix:
- [x] Added `_embeddedOpen` guard in `LongVideoWidgetNotifier`.
- [x] Added `setEmbeddedOpen(bool)` API.
- [x] `warmUp`, `autoplay`, `autoPause` now return early when embedded is open.
- [x] Set `_embeddedOpen=true` before push and false after pop in long-videos tap flow.
- [ ] Verify on device: no duplicate player behavior during transition.

---

## FIX 5 - Resume hint read at start of initialization

### Root cause confirmed:
- [x] Hint consumption happened later in init flow previously.

### Fix:
- [x] `longVideoEmbedResumeHintProvider` is now read at the start of `_initializePlayer`, before awaits.
- [x] Hint is sanitized and consumed for same-url only.
- [x] If absent, fallback to saved progress.
- [x] Near-end positions are normalized to `Duration.zero`.
- [ ] Verify on device: hint does not leak to subsequent unrelated video opens.

---

## FIX 6 - Slide-up navigation transition covers init time

### Fix:
- [x] Replaced embedded open route with `PageRouteBuilder`.
- [x] Slide-up transition: `Offset(0,1) -> Offset.zero`, `Curves.easeOutCubic`.
- [x] Transition duration set to 320ms.
- [ ] Verify on device: no visible blank/frozen frame after transition completes.

---

## VERIFICATION CHECKLIST

### Logcat verification
- [ ] Open long videos tab, scroll to arm autoplay, then autoplay works.
- [ ] Tap embedded open: one stable player path, no repeated surface-abandon cascade.
- [ ] No repeated `dequeueBuffer: BufferQueue has been abandoned` storm tied to each open.

### Functional verification
- [ ] Embedded starts reliably when fully visible.
- [ ] Resume position is correct (+/- 2s).
- [ ] Rapid open -> close -> open does not freeze/crash.
- [ ] Close embedded returns to feed and inline tile warmup remains stable.

### State verification
- [ ] `longVideoEmbedResumeHintProvider` cleared after consume.
- [ ] Autoplay manager disabled while embedded open and re-enabled after pop.
- [ ] Embedded guard false after return.

### flutter analyze
- [ ] Run `flutter analyze` and confirm zero new errors.

