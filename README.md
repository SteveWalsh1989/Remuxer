# Remuxer

Remuxer is a native macOS SwiftUI app for converting `.mkv` files into more compatible outputs with FFmpeg while being explicit about what can and cannot be preserved.

The main product rule is honesty: the app should never silently re-encode video or audio, silently drop streams, or describe an output as lossless unless the conversion planner verifies that every relevant stream can be copied or safely extracted.

## Current Status

Remuxer currently has a SwiftUI queue interface, conversion planning, output path handling, FFmpeg/ffprobe process wrappers, app-bundle runtime discovery, and unit tests for the core non-UI behavior. Release builds should include Remuxer's FFmpeg runtime in the app bundle.

## Prerequisites

- macOS 14 or newer.
- Xcode installed at `/Applications/Xcode.app`.
- `ffmpeg` and `ffprobe` in the bundled runtime folder at `Remuxer/Resources/FFmpeg/bin` before packaging a distributable app.
- SwiftLint installed locally for lint checks.

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
