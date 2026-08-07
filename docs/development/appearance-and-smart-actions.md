# Appearance And Smart Content Actions

## Background And Goal

粘易 needs to remain comfortable in different macOS appearances and keep its developer actions relevant to the copied content. The feature adds a persisted system/light/dark appearance preference and replaces the near-global action list with classification-driven action sets.

## User Scenarios

1. A user selects **Follow System**, **Light**, or **Dark** in General settings and all open app windows update immediately.
2. A copied JSON value shows JSON actions, while a copied URL shows URL actions.
3. A raw image only shows binary image-compatible actions. An image with saved OCR text is classified from that text instead.
4. Plain text retains general cleanup and encoding operations without exposing decoders and structured formatters that do not match it.

## Interaction Flow

1. `ClipboardMonitor` runs complete local classification before saving text metadata.
2. `ContentActionPanelViewModel` classifies the current source again when the action panel opens. This also covers old records and unsaved OCR text.
3. `ContentActionSuitabilityPolicy` maps the effective classification to visible action IDs.
4. The command palette renders and searches only that filtered collection.
5. `AppearanceService` persists a settings change and applies it through `NSApp.appearance`; `.system` clears the override so macOS controls the result.

## Technical Design

| Module | Responsibility |
| --- | --- |
| `AppAppearance` | Defines the system, light, and dark preference values and localization keys. |
| `AppearanceService` | Persists and immediately applies the global AppKit appearance. |
| `UserDefaultsConfig` | Stores `config.appAppearance`, defaulting invalid or missing values to `system`. |
| `ContentClassifier` | Detects JSON, URL, Base64, JWT, timestamp, SQL, shell, or plain text locally. |
| `ContentActionSuitabilityPolicy` | Owns the classification-to-visible-action mapping. |
| `ContentActionPanelViewModel` | Resolves the active type and exposes only suitable actions to the UI. |

## Action Mapping

| Classification | Visible actions |
| --- | --- |
| Plain text | Text cleanup/case/code-block actions, JSON escape, URL encode, Base64 encode, shell argument quote |
| JSON | JSON actions |
| URL | URL actions |
| Base64 | Base64 actions |
| JWT | JWT inspection |
| Timestamp | Timestamp conversion |
| SQL | SQL single-line formatting |
| Shell | Shell argument quoting |
| Raw image | Image-compatible Base64 encoding |

The visibility policy is separate from action validation. A hidden action invoked through an existing internal path still returns its precise validation error instead of a generic unsupported-action error.

## Configuration

| Name | Key | Type | Default | Values | Scope | User editable | Restart |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Application appearance | `config.appAppearance` | String | `system` | `system`, `light`, `dark` | Entire app | Yes | No |

## Data And Migration

No database schema change or migration is required. Existing clipboard records are reclassified when their action panel opens, so stale or missing classification metadata does not expose the old full action set.

## Error Handling

- Missing or unknown appearance values fall back to following macOS.
- Empty raw-image text stays classified as image.
- A user-selected content override takes precedence over automatic text classification.
- Action execution retains action-specific validation and localized failures.

## Privacy And Security

Classification and transformations remain entirely local. No clipboard text, image data, classification result, or appearance preference is uploaded or written to remote logs. This feature introduces no new permission or network dependency.

## Testing

Automated coverage includes appearance defaults, invalid-value fallback, persistence, immediate application, complete capture-time SQL classification, action-panel classification for all supported structured types, plain-text filtering, raw-image filtering, OCR text routing, and existing validation failures.

## Future Extensions

New content types or actions should be added to `ContentActionSuitabilityPolicy` with a matching classification and visibility test. Image conversion or compression actions can join the image mapping once they exist.
