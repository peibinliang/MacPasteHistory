# 粘易 User Guide

粘易 is a macOS menu bar clipboard history app. It records supported text and image clipboard items locally so you can search, preview, restore, favorite, and delete previous copies.

## Start And Open

Launch `粘易.app`. The app runs from the menu bar with a folded-loop icon. Choose **Open History** from the menu bar item, or press the global shortcut `Command + Shift + V` when it is available.

## Record Clipboard History

Text recording and image recording can be enabled or disabled in **Settings**. Supported image inputs include PNG, TIFF, JPEG browser data where available, and local image file copies from Finder. Very large images are skipped according to the configured single-image size limit.

## Browse, Search, And Filter

The main history window shows text and image records in newest-first order. Use the search field to filter text history, the type segmented control to switch between all/text/image records, and the favorites checkbox to show only starred records. Long text opens in the detail view; image records show thumbnails and an image detail preview.

## Restore Items

Single-click a history row to restore that item, close the history panel, return focus to the app that was active before opening history, and send `Command + V`. Use the row's details button to preview long text or images without pasting. The restore button and keyboard `Enter` action only write the selected item back to the system clipboard.

The first direct paste may ask for macOS Accessibility permission because the app must send a keyboard shortcut to another app. After granting permission in System Settings, reopen history and click the item again.

## Manage Data

Use row actions to favorite, restore, or delete individual records. **Clear Text** removes text history from the main window. **Settings → Clear All Data** asks for confirmation and then removes local history records and stored image files.

## Settings

Settings include text/image recording toggles, launch-at-login preference backed by macOS Login Items, Dock icon preference, history retention days, text/image count limits, single-image size limit, and total storage cap. The single-image size limit applies to new image captures, while cleanup runs on startup and uses the count and storage limits to bound local data growth.

## Privacy Notes

Clipboard content stays on this Mac. Do not copy sensitive data into history if you do not want it stored locally. Sensitive-text filtering and blocked-app controls are implemented in the capture pipeline, but release behavior should still be verified against your actual workflow before distribution.

The current release does not encrypt the local history database or app-managed image files. Use macOS account security and disk encryption such as FileVault if you need device-level protection for local files.
