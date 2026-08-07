# 粘易 User Guide

粘易 is a macOS menu bar clipboard history app. It records supported text and image clipboard items locally so you can search, preview, restore, favorite, and delete previous copies.

## Start And Open

Launch `粘易.app`. The app runs from the menu bar with a folded-loop icon. Choose **Open History** from the menu bar item, or press the global shortcut `Command + Shift + V` when it is available.

## Record Clipboard History

Text recording and image recording can be enabled or disabled in **Settings**. Supported image inputs include PNG, TIFF, JPEG browser data where available, and local image file copies from Finder. Very large images are skipped according to the configured single-image size limit.

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

Settings are organized into **General**, **Privacy**, and **Storage and Data**. They include text/image recording toggles, launch-at-login preference backed by macOS Login Items, Dock icon preference, history retention days, text/image count limits, single-image size limit, and total storage cap. The single-image size limit applies to new image captures, while cleanup runs on startup and uses the count and storage limits to bound local data growth.

General settings also include **Appearance** with **Follow System**, **Light**, and **Dark** options. Appearance changes apply immediately and persist across launches; following the system remains the default.

## Privacy Notes

Clipboard content stays on this Mac. Do not copy sensitive data into history if you do not want it stored locally. Sensitive-text filtering and blocked-app controls are implemented in the capture pipeline, but release behavior should still be verified against your actual workflow before distribution.

The current release does not encrypt the local history database or app-managed image files. Use macOS account security and disk encryption such as FileVault if you need device-level protection for local files.
