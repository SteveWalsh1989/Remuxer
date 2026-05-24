# Remuxer

Remuxer is a native macOS app for converting `.mkv` files and repairing `.mp4` remuxes with FFmpeg.

It focuses on clear queue management and honest conversion plans, so users can see what will be copied, converted, extracted, blocked, or left out before work starts.

## What It Does

- Converts `.mkv` files and can remux `.mp4` files using a bundled FFmpeg runtime.
- Lets users queue multiple files, review each file, and start conversions in batches.
- Supports presets for MP4 compatibility, Apple HEVC, broad H.264 compatibility, and MKV archive output.
- Shows warnings and blockers before conversion starts.
- Can extract unsupported subtitle tracks as separate sidecar files when that option is enabled.
- Can write outputs beside the source file, into a selected folder, or into one folder per source file.
- Can auto-rename, replace, or block when an output file already exists.
- Can move original source files to Trash after a successful conversion when that option is enabled.

## Current Limitations

- Remuxer currently accepts `.mkv` inputs and `.mp4` inputs that need remux repair.
- MP4 is a compatibility container and cannot preserve every MKV feature.
- The `Lossless MP4` preset only copies compatible streams. It blocks video or audio that would require re-encoding.
- Copied HEVC video in MP4 outputs is tagged as `hvc1` for Apple playback compatibility.
- MP4-incompatible subtitles are either extracted as sidecar files or shown as warnings, depending on the subtitle extraction setting.
- MKV attachments and cover art are not preserved in MP4 outputs and are surfaced as warnings.
- Source files are moved to Trash only after successful conversion and sidecar extraction. If the output would replace the source file, conversion is blocked.
