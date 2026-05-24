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

## Project Context And Docs

- Read `README.md`, `docs/README.md`, and relevant files under `docs/` before making product or architecture changes.
- Read `docs/ui-ux-standards.md` before changing SwiftUI views, controls, icon buttons, tooltips, layout, color, state presentation, or visual hierarchy.
- Treat `docs/planning/` as local planning context. Promote durable decisions, setup steps, and user-facing behavior into tracked docs when they become part of the product.
- Update documentation in the same change when behavior, setup, commands, architecture boundaries, or preset semantics change.
- Keep the root README useful for a new contributor: purpose, prerequisites, build/test commands, architecture map, and current product constraints.
- Do not let docs drift from implementation. If code and docs disagree, verify the code path and update the stale side.

## Architecture

- Keep UI/views, view models/state, domain models, queue management, process execution, conversion planning, and filesystem/output handling separated.
- Wrap `ffmpeg` and `ffprobe` behind protocols so planner and queue logic remain unit-testable.
- Keep preset logic data-driven where practical, but avoid abstractions that do not remove current complexity.
- Model media data explicitly: video streams, audio streams, subtitle streams, attachments, chapters, metadata, warnings, blockers, commands, and output paths.
- Use typed errors with user-readable messages. Avoid broad `catch` blocks and success-shaped fallbacks.

## Swift Standards

- Follow Swift API Design Guidelines and existing project style before introducing new patterns.
- Prefer small value types for domain models, protocol-backed dependencies at app boundaries, and explicit dependency injection for testable logic.
- Keep SwiftUI views focused on layout and user interaction. Put state transitions, queue orchestration, filesystem decisions, and process execution outside views.
- Use structured concurrency deliberately. Keep UI-facing mutable state on the main actor and avoid unstructured tasks unless bridging callback APIs.
- Prefer `let`, exhaustive `switch` statements, clear enum cases, and typed errors over stringly typed state.
- Avoid force unwraps, force tries, broad casts, and unnecessary `as` assertions. If a cast is needed, make the invariant clear.
- Keep names meaningful and domain-specific. Avoid abbreviations unless they are established terms such as FFmpeg, MP4, MKV, AAC, HEVC, or URL.

## macOS App Standards

- Target macOS 14+ unless a newer macOS API materially improves the product and is worth requiring.
- Use SwiftUI for the interface and AppKit only for desktop behaviors SwiftUI cannot model cleanly.
- Build a calm, dense, batch-work UI. The queue is the main screen.
- Prefer native macOS affordances: toolbar actions, menus/commands, file importer, drag and drop, settings, keyboard shortcuts, and standard panels.
- Keep App Store compatibility in mind: isolate external process execution, file access, sandbox-sensitive behavior, and any future bundled-FFmpeg choice behind narrow interfaces.

## UI And UX Standards

- Treat `docs/ui-ux-standards.md` as mandatory product guidance, not optional polish.
- Start UI work by naming the user's job for the changed screen and the visible states affected.
- Prioritize human-readable layouts over compact icon-heavy layouts. Compactness is a failure if the control purpose or state becomes ambiguous.
- Anything that looks clickable must be clickable. Anything passive must not look like a control or destructive action.
- Icon-only buttons must use one shared tooltip mechanism and show exactly one tooltip. Do not combine `.help` with the custom icon-control tooltip on the same icon-only control.
- Every icon-only button must have a tooltip, accessibility label, and accessibility hint that describe the action in plain language.
- Do not use destructive symbols or red styling for passive hints. A red trash icon means delete/remove/destructive action, not background status.
- Prefer labels for important, destructive, unusual, or hard-to-infer actions.
- Keep file identity, queue status, next action, and risk/warnings visually distinct.
- After UI edits, launch the app and inspect the affected screens/states before finalizing. If visual inspection is not possible, say so explicitly.
- Before finalizing UI work, run a visual critique pass for readability, hierarchy, affordance, tooltip count, disabled states, long text, and error/warning/destructive color use.
- In the handoff for UI changes, state what the user will see differently and what visual states were checked.

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

## Comments

- Add comments only when they explain intent, constraints, tradeoffs, or non-obvious behavior.
- Prefer concise single-line `//` comments near the code they clarify.
- Do not add comments that restate the next line of code.
- Never reference conversations, temporary decisions, or implementation options in comments.

## Testing And Hygiene

- Add unit tests for non-UI logic before considering core behavior complete.
- Required coverage areas: ffprobe JSON decoding, compatibility decisions, conversion plans for each preset, sidecar path generation, collision handling, queue state transitions, and missing tool detection.
- Do not add brittle UI snapshot tests.
- After editing code, run the formatter, SwiftLint, and relevant tests before considering the task complete.
- Use the project scripts where possible: `scripts/format.sh`, `scripts/lint.sh --fix`, `scripts/lint.sh`, `scripts/test.sh`, and `scripts/build.sh`.
- Fix warnings and errors caused by the implementation.

## Git And Commits

- Only commit when explicitly asked.
- Before committing, inspect the diff and avoid staging unrelated user changes.
- Write meaningful commit messages in the imperative mood that describe the product or engineering outcome, for example `Add security-scoped access for queued conversions`.
- Prefer one focused commit per coherent change. Do not mix documentation, refactors, and behavior changes unless they are part of the same work.
