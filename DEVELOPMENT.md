# KeyClip — Development Notes

Internal documentation for building, contributing to, and understanding the KeyClip codebase. End-user instructions live in [`README.md`](./README.md).

## Building without Xcode

The repository includes a Swift Package Manager manifest and a small bundle script so you can build the app from Terminal with Xcode Command Line Tools only.

Prerequisite:

```sh
xcode-select --install
```

Build and assemble the `.app` bundle:

```sh
./build.sh
open KeyClip.app
```

On Gatekeeper-strict systems, an ad-hoc or unsigned local build may require right-clicking `KeyClip.app` and choosing **Open** the first time.

## Building with Xcode

### Prerequisites

- Xcode 15 or newer
- macOS 13 or newer
- An Apple Developer account or local signing identity for running the app

### Create the Xcode Project

1. Open Xcode and choose **File > New > Project**.
2. Select **macOS > App**.
3. Set **Product Name** to `KeyClip`.
4. Set **Bundle Identifier** to `com.keyo.KeyClip`.
5. Set **Interface** to `SwiftUI`.
6. Set **Language** to `Swift`.
7. Leave **Use Core Data** unchecked.
8. Save the project inside this repository's `KeyClip` folder.

### Add the Provided Source Files

1. Delete Xcode's generated `ContentView.swift`.
2. Keep the generated app target, but replace the generated app entry point with the provided `KeyClipApp.swift`.
3. Add every file from the `KeyClip/` source folder in this repository to the app target:
   - `KeyClipApp.swift`
   - `AppDelegate.swift`
   - `Controllers/MenuBarController.swift`
   - `Clipboard/ClipboardMonitor.swift`
   - `Clipboard/ClipboardHistoryStore.swift`
   - `Clipboard/ClipboardGroupStore.swift`
   - `Clipboard/AttachmentStore.swift`
   - `Clipboard/RetentionSweeper.swift`
   - `Models/ClipboardHistoryItem.swift`
   - `Models/ContentType.swift`
   - `Models/ClipboardGroup.swift`
   - `Models/RetentionPolicy.swift`
   - `Views/ClipboardPopoverView.swift`
   - `Views/ClipboardHistoryRowView.swift`
   - `Views/SidebarView.swift`
   - `Views/Theme.swift`
   - `Utilities/ContentTypeDetector.swift`
   - `Utilities/AppIconLoader.swift`
   - `Utilities/GlobalHotkey.swift`
   - `Utilities/StringHashing.swift`
   - `Utilities/UserSettings.swift`

### Frameworks and Settings

1. In the app target, open **General > Frameworks, Libraries, and Embedded Content**.
2. Add `CryptoKit.framework`.
3. Open the app target's `Info.plist`.
4. Add `Application is agent (UIElement)` with Boolean value `YES`.
   - Raw key: `LSUIElement`
5. Open **Signing & Capabilities**.
6. Select your team and verify the bundle identifier is `com.keyo.KeyClip`.
7. Enable automatic signing unless your environment requires manual signing.

### Run

1. Select the `KeyClip` scheme.
2. Choose a macOS run destination.
3. Press **Command-R**.
4. The app appears only in the menu bar with a clipboard icon.
5. Copy text from any app, then click the menu bar icon to view clipboard history.
6. Click a history row to write that item back to the pasteboard and close the popover.

## Architecture

- The app uses a SwiftUI `@main` app with only a `Settings` scene, so no standard window opens.
- `AppDelegate` sets the activation policy to accessory mode and retains the history store, clipboard monitor, group store, retention sweeper, global hotkey, and menu bar controller.
- `ClipboardMonitor` polls `NSPasteboard.general.changeCount` every 0.5 seconds and captures the frontmost app at the moment of capture for source attribution.
- `GlobalHotkey` registers ⇧⌘V via Carbon's `RegisterEventHotKey` so the popover can be summoned from anywhere.
- `ContentTypeDetector` inspects each clip and the pasteboard to assign one of: Text, Rich Text, Link, Email, Phone, Color, Emoji, or Code. Image is produced when PNG / TIFF is on the pasteboard. File / Files cases exist in the model but are not produced by the current monitor.
- `ClipboardHistoryItem.title` stores an optional user note for identifying why a clip was saved. Empty titles are normalized back to nil, and titled items appear in the built-in Tags group.
- `ClipboardHistoryStore` persists up to 100 ungrouped clips at `~/Library/Application Support/com.keyo.KeyClip/clipboard-history.json`; items in Tags or custom groups are protected from the history cap.
- `ClipboardGroupStore` persists user-defined groups at `~/Library/Application Support/com.keyo.KeyClip/clipboard-groups.json` and prunes orphaned item IDs whenever a clip is dropped from history.
- `AttachmentStore` writes images and RTF payloads to `~/Library/Application Support/com.keyo.KeyClip/attachments/` for thumbnails and pasteboard restoration. Attachments are deleted alongside their owning history item.
- `RetentionSweeper` runs at launch, every 30 minutes thereafter, and immediately when the retention policy changes. It first removes any item flagged `isOversize` after 24 hours, then enforces the user-selected policy. Items in Tags or any custom group are always exempt.

## Capture Rules

- Empty and whitespace-only clips are ignored.
- Hard cap is 100 MB per clip across text, RTF, and image.
- Anything larger than 10 MB is accepted but flagged `isOversize`, marked with a "24h" badge in the UI, and force-expired after 24 hours unless it belongs to Tags or a custom group.
- Duplicate clips are detected by SHA-256 hash after normalizing line endings for hashing only, while preserving the original clipboard content.

## Persistence Compatibility

The history JSON is forward-compatible: every field added after the initial release uses `decodeIfPresent` with a sensible fallback. Clips written before any given field existed continue to decode without errors.

## Theme

`Views/Theme.swift` centralizes the color palette, type scale, spacing, and radius tokens used across the popover. Light and dark variants are provided via `NSColor(name:dynamicProvider:)` so the app follows the system appearance automatically.
