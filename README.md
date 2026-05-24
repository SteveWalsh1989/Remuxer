# Remuxer

Remuxer is a native macOS app for converting `.mkv` files and repairing `.mp4` remuxes with FFmpeg.

It focuses on clear queue management and honest conversion plans, so users can see what will be copied, converted, extracted, blocked, or left out before work starts.

## What It Does

- Converts `.mkv` files and can remux `.mp4` files using a bundled FFmpeg runtime.
- Lets users queue multiple files, review each file, and start conversions in batches.
- Shows queue-level batch progress, completed item count, and an estimated time remaining when enough measured data exists.
- Supports presets for MP4 compatibility, Apple HEVC, broad H.264 compatibility, and MKV archive output.
- Shows warnings and blockers before conversion starts.
- Can extract unsupported subtitle tracks as separate sidecar files when that option is enabled.
- Can write outputs beside the source file, into a selected folder, or into one folder per source file.
- Can auto-rename, replace, or block when an output file already exists.
- Moves original source files to Trash after a successful conversion when that option is enabled.

## Requirements

- macOS 14 or newer.
- Xcode with the macOS SDK and command line tools.
- The bundled FFmpeg runtime under `Remuxer/Resources/FFmpeg/bin`. Local development can set `REMUXER_FFMPEG_BIN_DIR` to fill in missing tools, but bundled tools are searched first.

## Common Commands

```bash
scripts/format.sh
scripts/lint.sh --fix
scripts/lint.sh
scripts/test.sh
scripts/build.sh
scripts/build_and_run.sh
scripts/dist.sh
```

`scripts/dist.sh` builds a local distributable app bundle at `dist/Remuxer.app` and verifies that bundled `ffmpeg` and `ffprobe` are present.

## Architecture Map

- `Remuxer/App`: app entry point and dependency wiring.
- `Remuxer/Domain`: explicit media, queue, output, preset, and plan models.
- `Remuxer/Planning`: stream compatibility decisions and FFmpeg command planning.
- `Remuxer/Queue`: analysis, conversion orchestration, active batch state, and queue updates.
- `Remuxer/Processes`: `ffmpeg`, `ffprobe`, progress parsing, cancellation, and toolchain lookup.
- `Remuxer/Filesystem`: output preparation, source Trash handling, and security-scoped access boundary.
- `Remuxer/Support`: small shared helpers and formatting utilities.
- `Remuxer/Views`: SwiftUI queue, detail, options, and developer-mode surfaces.
- `RemuxerTests`: unit coverage for planning, queue behavior, toolchain lookup, output paths, FFprobe decoding, and process execution helpers.

## Current Limitations

- Remuxer currently accepts only `.mkv` and `.mp4` inputs. MP4 input support is scoped to remux repair, not general video editing.
- MP4 is a compatibility container and cannot preserve every MKV feature.
- The `Lossless MP4` preset only copies compatible streams. It blocks video or audio that would require re-encoding.
- Copied HEVC video in MP4 outputs is tagged as `hvc1` for Apple playback compatibility.
- MP4-incompatible subtitles are either extracted as sidecar files or shown as warnings, depending on the subtitle extraction setting.
- MKV attachments and cover art are not preserved in MP4 outputs and are surfaced as warnings.
- Source files are moved to Trash, not permanently removed, only after successful conversion and sidecar extraction. If the output would replace the source file, conversion is blocked or auto-renamed depending on the collision setting.
