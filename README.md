# KeyClip

A calm, fast clipboard manager that lives in your macOS menu bar.

<img src="https://github.com/user-attachments/assets/b3bd83c5-dde3-47b5-9214-d450418fb817" alt="KeyClip popover screenshot" width="620" />

KeyClip remembers what you copy — text, rich text with formatting, images, links, code, and more — and brings it back with a keystroke. Items you care about can be filed into custom groups so they stick around; everything else cleans itself up on a schedule you choose.

## Highlights

- **⇧⌘V from anywhere** to open the popover
- **⌘1 – ⌘0** quick-paste the first ten visible clips
- **Auto-detected content types** (Text, Rich Text, Image, Link, Code, Email, Phone, Color, Emoji) shown with colored icons
- **Custom groups** — drag any clip in, or right-click → *Add to Group*. Items in groups never expire and are skipped by Clear
- **Source app** label on every clip so you remember where it came from
- **Retention policy** (Forever / 1 / 7 / 30 days) configurable from the gear menu
- **Pause** the clipboard from the status item right-click menu when you don't want anything captured

## Install

### Build it yourself (no Xcode app required)

```sh
xcode-select --install   # one-time
git clone https://github.com/mis101247/KeyClip.git
cd KeyClip
./build.sh
open KeyClip.app
```

The first launch on a Gatekeeper-strict Mac may need a right-click → **Open** because the local build is unsigned.

## Use

- Click the clipboard icon in the menu bar (or press **⇧⌘V**) to open the popover.
- Copy anything from any app — KeyClip captures it and the menu bar icon briefly fills in to confirm.
- Click a clip (or press **⌘1**–**⌘9** / **⌘0**) to put it back on the pasteboard.
- Right-click a clip for **Copy**, **Add to Group**, or **Delete**.
- Right-click the menu bar icon for **Pause Clipboard** and **Quit**.

## Limits

- Up to 100 clips of recent history (groups don't count toward this).
- Each clip up to 100 MB. Anything between 10 MB and 100 MB is kept for only 24 hours and shows a small "24h" warning badge.
- Custom groups have no size limit and never expire.

## Where data lives

```
~/Library/Application Support/com.keyo.KeyClip/
├── clipboard-history.json
├── clipboard-groups.json
└── attachments/        # images and RTF payloads
```

To reset everything, quit KeyClip and delete that folder.

## Development

See [`DEVELOPMENT.md`](./DEVELOPMENT.md) for build details, source layout, and architecture notes.
