# Current Functionality

This document describes the app behavior implemented in the current codebase. Keep it aligned with product behavior, presets, output handling, and process execution.

## User Workflow

- Remuxer accepts `.mkv` files through drag and drop, the Add MKV Files panel, and app-opened file URLs.
- The queue ignores unsupported file extensions and duplicate source URLs already in the queue.
- Users can analyze queued files before conversion or press Start and let the queue analyze missing plans first.
- Queue rows show file name, selected preset, status, inline progress during conversion, and blocking issues.
- The detail view shows the selected file, preset, stream summary, status, progress, editable output name, output summary, and queue options.
- Dev Mode is available from the app commands. It reveals raw source/output paths, generated FFmpeg commands, sidecar paths, and logs with copy actions.
- Completed items can be removed with Clear Completed. Failed or blocked items can be retried from the queue context menu.

## Queue Options

- The default preset is `Lossless MP4`. Users can change the default and apply it to the whole queue or the current selection.
- Per-file custom output names are supported. Matching output extensions are stripped, and invalid names such as path separators, `.` and `..` are rejected.
- Series Options appear when more than one file is queued. A prefix and numeric start value generate padded names such as `PeaceMaker S02E01`.
- Series naming applies when Start is pressed. If multiple files are selected, it applies to the selected files in queue order; otherwise it applies to the whole queue.
- Extra subtitle sidecar extraction is off by default.
- Remove originals after success is on by default. Source files are deleted only after all sidecar extraction and the primary conversion complete successfully.

## Output Destinations

- `Beside Source` writes output next to each input file and is the default.
- `Selected Folder` writes every output into the chosen folder.
- `Folder Per File` writes each output into a folder named after the source file. If a selected folder exists, those per-file folders are created there; otherwise they are created beside each source file.
- Destination choices are persisted as recent destinations. Users can save selected destinations and remove saved destinations from the Output menu.
- Collision handling supports `Auto Rename`, `Replace`, and `Block`.
- `Auto Rename` appends a numeric suffix such as `Movie 2.mp4` when the planned output path exists.
- `Replace` allows FFmpeg to overwrite the output path.
- `Block` prevents conversion before FFmpeg runs when the planned output path exists.
- Generated sidecars use the same base output name plus stream index and language when available, for example `Movie.2.eng.srt`.

## Preset Behavior

- `Lossless MP4` remuxes compatible video, audio, and MP4-compatible subtitle streams with `-c copy`. It blocks incompatible video and audio because those would require re-encoding or transcoding.
- `Apple HEVC` transcodes video with `hevc_videotoolbox`, tags HEVC as `hvc1`, copies compatible audio, and converts incompatible audio to AAC at 192 kbps.
- `Universal MP4` transcodes video with `h264_videotoolbox`, outputs `yuv420p`, copies compatible audio, and converts incompatible audio to AAC at 192 kbps.
- `Archive` keeps MKV output, maps all streams, copies metadata and chapters, and uses stream copy for preservation.
- MP4 presets copy metadata and chapters into the output.
- MP4 presets warn when attachments or cover art are present because those streams are not mapped into MP4 output.
- Unsupported subtitles are not copied into MP4. With sidecar extraction off, Remuxer warns that they will not be included. With sidecar extraction on, Remuxer generates one extraction command per unsupported subtitle stream.
- Subtitle sidecar extensions are selected from codec names: SRT, ASS, SSA, WebVTT, and PGS have specific extensions; unknown subtitle codecs use `.sub`.

## Runtime And Process Execution

- Remuxer bundles FFmpeg and ffprobe in `Remuxer/Resources/FFmpeg/bin`; the app bundle searches `FFmpeg/bin` under its resources.
- `REMUXER_FFMPEG_BIN_DIR` is a development override for local builds. The bundled runtime is searched first for each executable, and the override can fill in missing bundled tools.
- Missing FFmpeg or ffprobe produces a user-readable conversion engine error instead of starting analysis or conversion.
- Conversion and analysis use `Process` with executable URLs and argument arrays. The app does not construct shell commands for FFmpeg work.
- FFprobe reads streams, chapters, format duration, and format metadata from JSON.
- FFmpeg stderr is logged into queue item logs. Progress is parsed from `time=HH:MM:SS.xx` output when media duration is available.
- Cancelling terminates the active process and returns the item to queued state.

## Current Constraints

- Remuxer only accepts `.mkv` input files.
- MP4 is a compatibility container and cannot preserve every MKV feature.
- The app is intentionally not app-sandboxed in the current build. Security-scoped access is isolated behind a helper, but durable bookmarks and App Store sandbox behavior remain future production concerns.
- Remuxer does not silently re-encode video or audio in the `Lossless MP4` preset. Other MP4 presets intentionally transcode video and may transcode incompatible audio with warnings.
- Remuxer does not silently drop unsupported subtitles, MP4-incompatible attachments, or cover art. It surfaces warnings before conversion starts.
