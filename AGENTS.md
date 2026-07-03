# Repository Guidelines

## Project Structure & Module Organization

This repository currently contains the product requirements and OpenSpec planning artifacts for a macOS clipboard history app.

- `AI_CODING_RULES.md`: mandatory AI agent development rules. Read this before modifying code, docs, specs, or configuration.
- `Mac 剪贴板历史工具功能清单与开发任务清单.md`: source requirements and phased task list.
- `openspec/changes/`: proposed changes, one directory per implementation phase.
- `openspec/changes/change-order.md`: recommended change execution and archive order.
- `openspec/specs/`: archived or accepted specifications after changes are applied.

When implementation begins, follow the planned Swift module layout from the requirements document: `App/`, `Clipboard/`, `Database/`, `Models/`, `Views/`, `ViewModels/`, `Services/`, `Utils/`, and `Resources/`.

## Build, Test, and Development Commands

Use OpenSpec to inspect and validate planning work:

- `openspec list`: show active changes and task progress.
- `openspec status --change <change-name>`: inspect artifact completion for a change.
- `openspec validate <change-name> --strict`: validate a change before implementation or archive.
- `openspec instructions <artifact> --change <change-name> --json`: retrieve artifact-specific authoring instructions.

Current build and test commands:

- `xcodegen generate`: regenerate `MacPasteHistory.xcodeproj` from `project.yml`.
- `scripts/validate-xcode-file-references.sh`: regenerate the Xcode project and verify Swift file references resolve to real files.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory -destination 'platform=macOS,arch=arm64' build`: build the macOS app.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory -destination 'platform=macOS,arch=arm64' test`: run unit tests.

## Coding Style & Naming Conventions

Use Swift and SwiftUI conventions for implementation. Prefer clear type names such as `ClipboardMonitor`, `ClipboardHistoryRepository`, and `SensitiveContentService`. Name OpenSpec changes in kebab-case, for example `add-text-clipboard-history`. Keep Markdown task checkboxes in `- [ ] 1.1 ...` format so OpenSpec can track progress.

## Testing Guidelines

Each change’s `tasks.md` includes implementation details, prerequisites, and acceptance conditions. Treat those acceptance conditions as the minimum test checklist. Add unit tests for services and repositories, and UI or manual verification for menu bar, pasteboard, shortcut, and release flows once the Xcode project exists.

## Commit & Pull Request Guidelines

No git history exists in this workspace yet, so no repository-specific commit convention is established. Use concise imperative commits such as `Add text clipboard history spec`. Pull requests should include the related OpenSpec change name, a summary of completed tasks, validation output, screenshots for UI changes, and any known limitations.

## Security & Configuration Tips

Clipboard data is sensitive. Do not hardcode secrets, do not log copied content, and keep all history local unless a future spec explicitly changes that behavior. Validate privacy, pause, blocked-app, and clear-data behavior before release work.

## Agent-Specific Instructions

Before starting any development task, Codex and other AI agents MUST read `AI_CODING_RULES.md` and follow it as the primary project coding standard. If a task conflicts with those rules, stop and ask for clarification before editing files.
