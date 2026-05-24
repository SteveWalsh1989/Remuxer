# Remuxer Agent Instructions

Remuxer is a production-quality native macOS SwiftUI app for converting `.mkv` files into more compatible outputs using FFmpeg.

## Product Truths

- Be honest about preservation. MP4 is a compatibility container and cannot preserve every MKV feature.
- Never claim "lossless", "no loss", or equivalent unless the conversion planner verifies that every relevant stream can be copied or safely extracted.
- Do not silently re-encode video or audio.
- Do not silently drop streams.
- Surface warnings and blockers before conversion starts.
- Prefer preserving video, audio, chapters, useful metadata, and compatible subtitle tracks.
- Extract unsupported subtitles as sidecar files when the selected preset supports extraction.

## Architecture

- Keep UI/views, view models/state, domain models, queue management, process execution, conversion planning, and filesystem/output handling separated.
- Wrap `ffmpeg` and `ffprobe` behind protocols so planner and queue logic remain unit-testable.
- Keep preset logic data-driven where practical, but avoid abstractions that do not remove current complexity.
- Model media data explicitly: video streams, audio streams, subtitle streams, attachments, chapters, metadata, warnings, blockers, commands, and output paths.
- Use typed errors with user-readable messages. Avoid broad `catch` blocks and success-shaped fallbacks.

## macOS App Standards

- Target macOS 14+ unless a newer macOS API materially improves the product and is worth requiring.
- Use SwiftUI for the interface and AppKit only for desktop behaviors SwiftUI cannot model cleanly.
- Build a calm, dense, batch-work UI. The queue is the main screen.
- Prefer native macOS affordances: toolbar actions, menus/commands, file importer, drag and drop, settings, keyboard shortcuts, and standard panels.
- Keep App Store compatibility in mind: isolate external process execution, file access, sandbox-sensitive behavior, and any future bundled-FFmpeg choice behind narrow interfaces.

## FFmpeg And Process Rules

- Start with externally installed `ffmpeg` and `ffprobe`; do not bundle FFmpeg in the first version.
- Detect missing tools and show a clear setup error.
- Construct commands as executable paths plus argument arrays. Do not build shell strings.
- Do not invoke shell parsing for conversion commands.
- Stream FFmpeg progress into app state where practical.
- Support cancelling active conversions through the process layer.

## Output And Filesystem Rules

- Default output naming should change only the extension when the container changes, for example `john-wick.mkv` to `john-wick.mp4`.
- Avoid overwriting existing files unless the user explicitly chooses replace.
- Support beside-source output, selected-folder output, and one-folder-per-source output.
- Design output location handling so recent and saved destinations can be added without rewriting conversion logic.
- Treat security-scoped file access and bookmarks as future production concerns, especially for App Store-oriented builds.

## Testing And Hygiene

- Add unit tests for non-UI logic before considering core behavior complete.
- Required coverage areas: ffprobe JSON decoding, compatibility decisions, conversion plans for each preset, sidecar path generation, collision handling, queue state transitions, and missing tool detection.
- Do not add brittle UI snapshot tests.
- After editing code, run the formatter, SwiftLint, and relevant tests before considering the task complete.
- Fix warnings and errors caused by the implementation.

