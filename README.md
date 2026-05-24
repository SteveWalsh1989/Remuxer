# Remuxer

Remuxer is a native macOS SwiftUI app for converting `.mkv` files into more compatible outputs with FFmpeg while being explicit about what can and cannot be preserved.

The main product rule is honesty: the app should never silently re-encode video or audio, silently drop streams, or describe an output as lossless unless the conversion planner verifies that every relevant stream can be copied or safely extracted.

## Current Status

Remuxer currently has a SwiftUI queue interface, conversion planning, output path handling, FFmpeg/ffprobe process wrappers, a bundled FFmpeg runtime, and unit tests for the core non-UI behavior. The queue supports per-file output names and batch sequence renaming for episode-style batches. Normal users see a progress-focused detail view by default; Dev Mode exposes raw file paths, FFmpeg commands, and logs with copy actions for debugging. Remuxer owns conversion end to end: users should not need to install or configure FFmpeg.

## Prerequisites

- macOS 14 or newer.
- Xcode installed at `/Applications/Xcode.app`.
- SwiftLint installed locally for lint checks.

For local development only, `REMUXER_FFMPEG_BIN_DIR` can point at a folder containing `ffmpeg` and `ffprobe`. That override must stay out of the normal user interface.

The bundled FFmpeg runtime lives in `Remuxer/Resources/FFmpeg/bin` and is copied into the app bundle. Runtime build details and license files live in `Remuxer/Resources/FFmpeg`.

Remuxer is intentionally not app-sandboxed. The bundled FFmpeg child process needs normal filesystem access to create converted videos and subtitle sidecars in user-selected output locations.

## Common Commands

```bash
scripts/format.sh
scripts/lint.sh --fix
scripts/lint.sh
scripts/test.sh
scripts/build.sh
```

Use `scripts/build_and_run.sh` when you need to build and launch the app locally.

## Presets

- `Lossless MP4`: copies MP4-compatible streams and blocks instead of re-encoding video or audio.
- `Apple HEVC`: transcodes video to HEVC for Apple devices, using Apple hardware encoding where available.
- `Universal MP4`: transcodes video to H.264 for broad playback compatibility.
- `Archive`: keeps MKV output and copies original streams for preservation.

Unsupported subtitles are extracted as sidecar files when the selected preset supports extraction. MKV attachments cannot be preserved in MP4 and should be surfaced as warnings before conversion.

## Architecture

- `Remuxer/App`: application entry point and dependency wiring.
- `Remuxer/Views`: SwiftUI screens and controls.
- `Remuxer/Domain`: conversion presets, plans, streams, output options, queue models, and typed domain state.
- `Remuxer/Planning`: compatibility rules and conversion plan generation.
- `Remuxer/Queue`: queue state transitions and orchestration.
- `Remuxer/Processes`: FFmpeg/ffprobe discovery and execution behind protocols.
- `Remuxer/Filesystem`: output destination, collision, sidecar, and security-scoped access helpers.
- `Remuxer/Support`: small shared utilities.
- `RemuxerTests`: focused unit tests for core behavior.

## Documentation

Project-level agent guidance lives in `AGENTS.md`. Durable project docs belong under `docs/`; local planning notes live under `docs/planning/` and are intentionally ignored by Git until they are promoted into tracked documentation.

Update this README or the relevant docs whenever setup, commands, architecture boundaries, conversion behavior, or product constraints change.
