## Context

The user should be able to summon the history panel and restore items quickly. This phase builds on existing restore behavior and adds keyboard-first interaction.

## Goals / Non-Goals

**Goals:**
- Register Command + Shift + V by default.
- Open the panel from the global shortcut.
- Handle shortcut conflicts gracefully.
- Support keyboard navigation and Enter restore.
- Close the panel with Escape and show restore feedback.

**Non-Goals:**
- Automatic paste into the current app and advanced shortcut rules are deferred.

## Decisions

- Store shortcut configuration in settings so future customization persists across restarts.
- Keep restore behavior as clipboard write only; do not synthesize Cmd+V in this phase.
- Keep keyboard selection state in the history view model so mouse and keyboard actions share the same selected item.
- Show lightweight toast feedback after restore rather than blocking dialogs.

## Risks / Trade-offs

- Global shortcut APIs can conflict with system or app shortcuts -> detect failed registration and expose a clear conflict state.
- Keyboard focus can be inconsistent in floating panels -> explicitly focus the list when the panel opens.
- Custom shortcut capture can be error-prone -> make default shortcut work first, then add customization.
