# Embedded Player Fix — Round 2

## Summary
- Removed remaining malformed URL paths from long-video and embedded UI surfaces.
- Added strict remote URL validation to prevent `file:///` usage.
- Kept embedded transition on pause + handoff path (no pre-push release/dispose added).

## Implemented
- [x] Guarded long-video tile `videoUrl` to allow only `http/https` before player open.
- [x] Guarded long-video tile thumbnail URL before passing to image widget.
- [x] Guarded long-video author avatar URL before `CachedNetworkImage`.
- [x] Guarded embedded player author avatar URL before `NetworkImage`.
- [x] Guarded suggested video thumbnail URL before `Image.network`.
- [x] Guarded suggested video open action when `videoUrl` is invalid.

## Files Changed
- `lib/features/long_videos/long_videos_screen.dart`
- `lib/features/video/video_player_screen.dart`

## Verification To Run On Device
- [ ] No `Invalid argument(s): No host specified in URI file:///` in logcat.
- [ ] Tap-to-embedded still opens and plays from expected position.
- [ ] No regressions in avatar/thumbnail rendering (fallback icon/placeholder appears when URL invalid).

