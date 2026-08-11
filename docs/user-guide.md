# 粘易 User Guide

粘易 is a macOS menu bar clipboard history app. It records supported text and image clipboard items locally so you can search, preview, restore, favorite, and delete previous copies.

## Start And Open

Launch `粘易.app`. The app runs from the menu bar with a folded-loop icon. Choose **Open History** from the menu bar item, or press the global shortcut `Command + Shift + V` when it is available.

## Record Clipboard History

Text recording and image recording can be enabled or disabled in **Settings**. Supported image inputs include PNG, TIFF, JPEG browser data where available, and local image file copies from Finder. Very large images are skipped according to the configured single-image size limit.

## Sensitive Content Filtering

**Settings → Privacy → Filter sensitive content** is enabled by default, including after upgrading from a version that did not store this preference. While enabled, text matching common password, token, identity-number, or payment-card patterns is skipped instead of being added to history.

The first request to turn filtering off shows a warning that the local SQLite history database is not encrypted and that matching sensitive text may be stored on this Mac. Cancelling the warning leaves filtering enabled. If you accept the warning, filtering turns off immediately and matching text becomes eligible for the normal local capture flow, including multiline technical text.

To restore the safer default, return to **Settings → Privacy** and enable **Filter sensitive content** again. Re-enabling takes effect immediately for future captures and does not require another confirmation. It does not automatically remove records saved while filtering was off; delete those records individually or use the clear-data controls if needed.

## Browse, Search, And Filter

The history overlay groups records into **Just Now**, **Today**, and **Earlier** sections. Use the recent-source ribbon to focus on an application, the search field to filter text history, and the filter menu to choose all/text/image records, a time range, or favorites. Long text opens in the detail view; image records show thumbnails and an image detail preview.

Structured search is available in the same field. Examples include `app:terminal type:shell docker`, `fav:true`, and `before:7d`. Tokens can be removed individually and ordinary terms remain highlighted in matching results.

## Content Actions And OCR

Select a record and press `Command-K`, use its type icon, or choose actions from **More Actions**. Actions run locally and can be chained; for example, use **Decode Base64** followed by **Format JSON**. The result remains editable before you copy it, direct-paste it, or save it as a new derived record.

The action list is selected from the copied content type instead of showing every registered action. JSON, URL, Base64, JWT, timestamp, SQL, shell, plain text, raw images, and OCR text each receive a focused action set. For example, a raw image does not show JSON formatting, while OCR text is classified from the recognized text.

JWT inspection only decodes visible fields. The signature warning means the app does not verify the JWT signature or establish trust. Timestamp, URL, JSON, Base64, SQL, shell and text actions likewise only transform local clipboard text.

For image records, open details and select **Recognize Text**. OCR is manual and local. Edit the recognized text, then select **Save** to make it searchable and usable with content actions.

## Restore Items

Single-click a history row to restore that item, close the history panel, return focus to the app that was active before opening history, and send `Command + V`. Use the row's **More Actions** menu to preview long text or images without pasting. Arrow keys move the inline selection, and `Enter` directly pastes the selected item.

On first launch, 粘易 checks whether macOS Accessibility permission is available. If it is missing, the app shows a reminder with an **Open System Settings** button. If permission is still unavailable when you select an item for direct paste, the history panel stays open and shows the reminder again. Grant access under **System Settings → Privacy & Security → Accessibility**, then click the item again.

## Manage Data

Use row actions to favorite, restore, or delete individual records. **Clear Text** removes text history from the main window. **Settings → Clear All Data** asks for confirmation and then removes local history records and stored image files.

## Settings

Settings are organized into **General**, **Privacy**, **Storage and Data**, and **About & Updates**. They include text/image recording toggles, sensitive-content filtering, launch-at-login preference backed by macOS Login Items, Dock icon preference, history retention days, text/image count limits, single-image size limit, and total storage cap. The single-image size limit applies to new image captures, while cleanup runs on startup and uses the count and storage limits to bound local data growth.

General settings also include **Appearance** with **Follow System**, **Light**, and **Dark** options. Appearance changes apply immediately and persist across launches; following the system remains the default.

## About And Updates

Open **Settings → About & Updates** to view the running application name, version, and build number. The **Automatically check for updates** switch controls Sparkle's periodic checks. Use **Check for Updates…** to request a foreground check at any time; Sparkle's standard update interface reports whether an update is available and handles verification, installation, cancellation, and relaunch for a formally published update.

Automatic and manual checks request the fixed GitHub Pages appcast and may download GitHub-hosted release notes or an update package from GitHub Releases. These requests contain update metadata only. They do not upload clipboard history, copied text, images, content hashes, or app preferences, and the app does not query the GitHub Releases API to discover versions.

## Privacy Notes

Clipboard content stays on this Mac and is not uploaded by update checks. Keep sensitive-content filtering enabled if you do not want recognized sensitive patterns stored locally, and use blocked-app controls for applications whose clipboard changes should always be skipped. Sensitive detection is best-effort, so release behavior should still be verified against your actual workflow before distribution.

The current release does not encrypt the local history database or app-managed image files. Use macOS account security and disk encryption such as FileVault if you need device-level protection for local files.
