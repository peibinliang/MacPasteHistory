# MacPasteHistory User Guide

MacPasteHistory is a macOS menu bar clipboard history app. It records supported text and image clipboard items locally so you can search, preview, restore, favorite, and delete previous copies.

## Start And Open

Launch `MacPasteHistory.app`. The app runs from the menu bar with a clipboard icon. Choose **Open History** from the menu bar item, or press the global shortcut `Command + Shift + V` when it is available.

## Record Clipboard History

Text recording and image recording can be enabled or disabled in **Settings**. Supported image inputs include PNG, TIFF, JPEG browser data where available, and local image file copies from Finder. Very large images are skipped according to the configured single-image size limit.

## Browse, Search, And Filter

The main history window shows text and image records in newest-first order. Use the search field to filter text history, the type segmented control to switch between all/text/image records, and the favorites checkbox to show only starred records. Long text opens in the detail view; image records show thumbnails and an image detail preview.

## Restore Items

Select a record and click the restore button, or use keyboard selection and press `Enter`. The app writes the selected text or image back to the system clipboard. Double-click a history row to restore that item, close the history window, return focus to the app that was active before opening history, and send `Command + V`.

The first double-click paste may ask for macOS Accessibility permission because the app must send a keyboard shortcut to another app. After granting permission in System Settings, reopen history and double-click the item again.

## Manage Data

Use row actions to favorite, restore, or delete individual records. **Clear Text** removes text history from the main window. **Settings → Clear All Data** asks for confirmation and then removes local history records and stored image files.

## Settings

Settings include text/image recording toggles, launch-at-login preference backed by macOS Login Items, Dock icon preference, history retention days, text/image count limits, single-image size limit, and total storage cap. The single-image size limit applies to new image captures, while cleanup runs on startup and uses the count and storage limits to bound local data growth.

## Privacy Notes

Clipboard content stays on this Mac. Do not copy sensitive data into history if you do not want it stored locally. Sensitive-text filtering and blocked-app controls are implemented in the capture pipeline, but release behavior should still be verified against your actual workflow before distribution.
