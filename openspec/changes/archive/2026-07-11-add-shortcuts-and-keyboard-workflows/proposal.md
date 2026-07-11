## Why

Clipboard history should be fast to access without moving focus away from the current task. This phase adds global activation, keyboard navigation, restore shortcuts, and feedback.

## What Changes

- Register a global shortcut to open the history panel.
- Use Command + Shift + V as the default shortcut.
- Detect shortcut registration conflicts and inform the user.
- Support optional shortcut customization.
- Close the panel with Escape.
- Move selection with arrow keys.
- Restore the selected item with Enter.
- Show a copy success toast after restore.

## Capabilities

### New Capabilities
- `add-shortcuts-and-keyboard-workflows`: Global shortcut activation, shortcut conflict handling, keyboard navigation, Enter restore, Escape close, and restore feedback.

### Modified Capabilities

## Impact

- Affects shortcut registration, settings persistence, panel focus behavior, keyboard event handling, selection state, restore actions, and toast feedback.
