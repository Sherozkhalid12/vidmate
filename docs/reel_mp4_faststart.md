# Reel video encoding — MP4 faststart (moov atom)

## Requirement

Progressive MP4 reels must be encoded so the **moov** atom appears **before** **mdat** (metadata at the start of the file). Otherwise the player may issue a range request to the **end** of the file before playback starts, causing visible buffering.

## FFmpeg (on upload or batch re-encode)

```bash
ffmpeg -i input.mp4 -c copy -movflags +faststart output.mp4
```

For re-encode (when copy is not possible):

```bash
ffmpeg -i input.mp4 -c:v libx264 -c:a aac -movflags +faststart output.mp4
```

## Verification

1. Open a reel **video URL** in Chrome DevTools → Network.
2. Start playback and confirm the player does **not** need an initial **Range** request that jumps to the **last** bytes solely to read the index (typical symptom of moov-at-end).

Coordinate with backend/CDN to run **faststart** in the upload pipeline or as a transcoding step.
