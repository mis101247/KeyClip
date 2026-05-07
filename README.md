# KeyClip

KeyClip is a small macOS menu bar clipboard manager built with Swift and SwiftUI. It polls the general pasteboard, stores recent text clips locally as JSON, shows history in a status item popover, and lets you restore a previous entry without re-adding it to history.

## Building without Xcode

This repository includes a Swift Package Manager manifest and a small bundle script so you can build the app from Terminal with Xcode Command Line Tools only.

Prerequisite:

```sh
xcode-select --install
```

Build and assemble the `.app` bundle:

```sh
cd KeyClip
./build.sh
open KeyClip.app
```

On Gatekeeper-strict systems, an ad-hoc or unsigned local build may require right-clicking `KeyClip.app` and choosing **Open** the first time.

## Prerequisites

- Xcode 15 or newer
- macOS 13 or newer
- An Apple Developer account or local signing identity for running the app

## Create the Xcode Project

1. Open Xcode and choose **File > New > Project**.
2. Select **macOS > App**.
3. Set **Product Name** to `KeyClip`.
4. Set **Bundle Identifier** to `com.keyo.KeyClip`.
5. Set **Interface** to `SwiftUI`.
6. Set **Language** to `Swift`.
7. Leave **Use Core Data** unchecked.
8. Save the project inside this repository's `KeyClip` folder.

## Add the Provided Source Files

1. Delete Xcode's generated `ContentView.swift`.
2. Keep the generated app target, but replace the generated app entry point with the provided `KeyClipApp.swift`.
3. Add every file from the `KeyClip/` source folder in this repository to the app target:
   - `KeyClipApp.swift`
   - `AppDelegate.swift`
   - `Controllers/MenuBarController.swift`
   - `Clipboard/ClipboardMonitor.swift`
   - `Clipboard/ClipboardHistoryStore.swift`
   - `Models/ClipboardHistoryItem.swift`
   - `Views/ClipboardPopoverView.swift`
   - `Views/ClipboardHistoryRowView.swift`
   - `Utilities/StringHashing.swift`

## Frameworks and Settings

1. In the app target, open **General > Frameworks, Libraries, and Embedded Content**.
2. Add `CryptoKit.framework`.
3. Open the app target's `Info.plist`.
4. Add `Application is agent (UIElement)` with Boolean value `YES`.
   - Raw key: `LSUIElement`
5. Open **Signing & Capabilities**.
6. Select your team and verify the bundle identifier is `com.keyo.KeyClip`.
7. Enable automatic signing unless your environment requires manual signing.

## Build and Run

1. Select the `KeyClip` scheme.
2. Choose a macOS run destination.
3. Press **Command-R**.
4. The app appears only in the menu bar with a clipboard icon.
5. Copy text from any app, then click the menu bar icon to view clipboard history.
6. Click a history row to write that item back to the pasteboard and close the popover.

## Implementation Notes

- The app uses a SwiftUI `@main` app with only a `Settings` scene, so no standard window opens.
- `AppDelegate` sets the activation policy to accessory mode and retains the history store, clipboard monitor, and menu bar controller.
- `ClipboardMonitor` polls `NSPasteboard.general.changeCount` every 0.5 seconds.
- Empty, whitespace-only, and text clips larger than 500 KB are ignored.
- `ClipboardHistoryStore` persists up to 100 clips at `~/Library/Application Support/com.keyo.KeyClip/clipboard-history.json`.
- Duplicate clips are detected by SHA-256 hash after normalizing line endings for hashing only, while preserving the original clipboard content.
