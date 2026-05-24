# Remuxer UI And UX Standards

Remuxer is a dense macOS batch-work app. The UI should help users understand a queue of video conversions quickly, choose safe options deliberately, and see risk before work starts.

These standards are durable product constraints. Apply them before and after every SwiftUI layout, control, icon, or state change.

## Product Feel

- Build a calm, readable, work-focused macOS interface. Avoid decorative layouts that make the queue harder to scan.
- Optimize every screen for the user's immediate job: add files, inspect status, understand blockers, choose output behavior, and start or cancel work.
- Prefer clear text and standard macOS controls over clever compact UI. Compactness is not a win if the meaning becomes ambiguous.
- Keep visual hierarchy obvious: file identity first, current state second, next available action third, warnings and destructive consequences clearly separated.
- Do not let the first working layout be the final pass. Functional UI still needs a readability and affordance review.

## Readability And Layout

- Queue rows must be scannable at a glance: file name, preset, status, progress, and blockers should not compete visually.
- Detail panels should group related choices and outcomes. Do not mix status, destructive consequences, and unrelated badges in one ambiguous cluster.
- Use spacing, section titles, labels, and control grouping to explain relationships. Do not rely on icon color alone.
- Keep text human-readable. Avoid truncated labels unless the surrounding layout still makes the purpose clear.
- Empty, queued, ready, converting, blocked, failed, completed, selected, disabled, hover, and menu states must be considered when changing shared UI.

## Controls And Affordances

- Anything that looks clickable must be clickable. Anything that is not clickable must not look like an action.
- Icon-only buttons must use the shared icon-control tooltip behavior and show exactly one tooltip.
- Do not combine native `.help` with the custom icon-control tooltip for the same icon-only button.
- Icon-only buttons must also have accessibility labels and hints that match the visible action.
- Prefer a labeled button or menu when an action is important, destructive, unusual, or hard to infer from the icon alone.
- Non-clickable status icons should be visually subdued and paired with text when the meaning is not obvious.
- Do not use a destructive-looking icon, such as a red trash icon, as a passive status indicator.

## Color And Risk

- Red is reserved for failed, blocked, destructive, or dangerous states and actions.
- Orange is for warnings or caution that does not block work.
- Green is for completed or safe success states.
- Secondary color is for passive metadata and low-priority status.
- Never use color as the only way to communicate meaning.

## Conversion-Specific UX

- Surface blockers before conversion starts and keep warnings close to the affected output or stream behavior.
- Show aggregate batch progress in a way that separates completed item count from per-file conversion progress. Show time remaining only when the estimate is based on enough measured progress data to be useful.
- Be explicit when output behavior can remove source files. The control for that behavior must be labeled and located with related queue options.
- Do not present source removal as a row-level action unless there is an actual per-item action.
- Keep developer-only information, such as full commands and logs, behind Dev Mode unless it is necessary for normal use.
- Copy actions must explain what they copy through their tooltip and accessibility text.

## Visual Review Checklist

Before calling UI work complete, inspect the changed screens in the running app and check:

- Can a user understand the primary state and next action in under a few seconds?
- Are all icon-only buttons explained by one tooltip, not zero or two?
- Does any passive icon look like a button or destructive action?
- Are disabled controls still understandable?
- Are errors, warnings, destructive actions, and ordinary metadata visually distinct?
- Does the layout remain readable with long file names, multiple queued files, and selected items?
- Did the change make the queue easier to scan rather than merely more compact?

If the app cannot be launched or visually inspected, state that explicitly in the handoff and do not imply visual verification happened.
