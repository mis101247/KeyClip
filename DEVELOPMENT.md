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

Build a drag-to-Applications DMG:

```sh
./release_dmg.sh
open dist/KeyClip-1.0.dmg
```

The DMG contains `KeyClip.app` and an `Applications` shortcut, so users can drag the app into Applications. `build.sh` generates a placeholder `AppIcon.icns` during bundling; replace `scripts/generate_icon.swift` or copy in a final `AppIcon.icns` when you have a production icon.

## Sparkle Updates

KeyClip uses Sparkle for update checks. Local development builds can omit the update feed and key; release builds should provide them:

```sh
VERSION=1.1 \
BUILD_NUMBER=2 \
UPDATE_FEED_URL=https://example.com/keyclip/appcast.xml \
SPARKLE_PUBLIC_ED_KEY="public-key-from-generate-keys" \
APPCAST_DOWNLOAD_URL_PREFIX=https://example.com/keyclip/ \
./release_dmg.sh
```

Run this once on your release machine to create Sparkle's EdDSA key pair and print the public key:

```sh
./scripts/generate_sparkle_keys.sh
```

Sparkle stores the private key in your login Keychain by default. Keep it safe. If you prefer CI secrets, pass the private key to the release script with either `SPARKLE_PRIVATE_ED_KEY_FILE=/path/to/key` or `SPARKLE_PRIVATE_ED_KEY="..."`.

The release script writes the DMG to `dist/KeyClip-$VERSION.dmg`, copies it into `dist/appcast/`, and runs Sparkle's `generate_appcast` tool to create or update `dist/appcast/appcast.xml`. Upload the contents of `dist/appcast/` to the same location used by `UPDATE_FEED_URL` and `APPCAST_DOWNLOAD_URL_PREFIX`.

For the `keyclip.keyo.tw` website, run:

```sh
VERSION=1.1 BUILD_NUMBER=2 ./scripts/release_keyclip_tw.sh
```

This stages a deployable static site in `dist/site/`:

```text
dist/site/
├── appcast.xml
├── download/
│   └── KeyClip-1.1.dmg
└── index.html
```

Deploy the contents of `dist/site/` to `https://keyclip.keyo.tw/`.

To deploy that site to Vercel:

```sh
./scripts/deploy_keyclip_vercel.sh
```

## Developer ID Notarization

Local builds use ad-hoc signing, so macOS may show an unidentified or unverified developer warning. Public downloads should be signed with a Developer ID Application certificate and notarized by Apple.

Create a reusable notary profile once:

```sh
xcrun notarytool store-credentials keyclip \
  --apple-id you@example.com \
  --team-id TEAMID \
  --password app-specific-password
```

Build, notarize, generate appcast, and stage the website with your Developer ID identity:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
VERSION=1.1 BUILD_NUMBER=2 \
NOTARY_PROFILE=keyclip \
NOTARIZE=1 \
./scripts/release_keyclip_tw.sh
```

The release script notarizes before generating `appcast.xml`, so Sparkle signs the final stapled DMG bytes. You can also notarize one DMG manually for diagnosis:

```sh
NOTARY_PROFILE=keyclip VERSION=1.1 ./scripts/notarize_dmg.sh
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
   - `Utilities/L10n.swift`
   - `Utilities/StringHashing.swift`
   - `Utilities/UserSettings.swift`
   - `Resources/en.lproj/Localizable.strings`
   - `Resources/zh-Hant.lproj/Localizable.strings`

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

## README Screenshots

The repository includes a deterministic demo mode for refreshing README screenshots with seeded clipboard history, settings, exclusion rules, and statistics data.

Generate the screenshots:

```sh
./scripts/capture_screenshots.sh
```

The script defaults to English for stable README output. Pass `DEMO_LANGUAGE=zh-Hant` to capture the Traditional Chinese UI:

```sh
DEMO_LANGUAGE=zh-Hant ./scripts/capture_screenshots.sh
```

Update the README screenshot block:

```sh
./scripts/update_readme_screenshots.sh
```

The capture script writes PNG files to `docs/assets/screenshots/`. Demo mode renders the SwiftUI window content from inside the app process, so it does not require macOS Screen Recording permission.

## Localization

KeyClip uses Apple `.lproj` resource folders and `Localizable.strings` files through the `L10n.tr(_:)` helper. The initial supported languages are English (`Resources/en.lproj/Localizable.strings`) and Traditional Chinese (`Resources/zh-Hant.lproj/Localizable.strings`).

Users can choose **Follow System**, **English**, or **Traditional Chinese** from Settings > General > Language. The setting is persisted as `appLanguage` with one of these values:

- `system`
- `en`
- `zh-Hant`

Language is resolved once at app launch. If the user changes it in Settings, they need to restart KeyClip before the UI language changes.

In normal app usage, language follows the user's macOS language preferences. For deterministic demo and screenshot runs, set `KEYCLIP_LANGUAGE=en` / `KEYCLIP_LANGUAGE=zh-Hant` or pass the launch argument `-KeyClipLanguage en`.

To add another language:

1. Create a new resource folder, for example `KeyClip/Resources/ja.lproj/`.
2. Copy `Localizable.strings` from `en.lproj`.
3. Translate the values while keeping every key unchanged.
4. Run `swift build` and `./build.sh` to verify both SwiftPM and the assembled app bundle include the resource bundle.

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
