# Light Bringer

A small native macOS menu-bar clipboard utility built with SwiftUI.

## Preview

<img src="docs/light-bringer-preview.jpg" alt="Light Bringer clipboard menu" width="422">

## Features

- Fixed, reusable text snippets and file selections
- Import and export fixed text presets as a JSON array
- The 20 most recent unique text or file clipboard items
- Click any item to copy it
- Right-click an item to pin or delete it
- Right-click the menu-bar icon for the first 5 fixed and 5 most recent items; click one to copy it
- Option + right-click anywhere on screen opens the same menu at the cursor (asks for Accessibility permission)
- Local persistence with `UserDefaults`
- Menu-bar-only interface

## Requirements

- macOS 13 or newer
- Xcode 15 or newer

## Run

Open `Package.swift` in Xcode and run the **LightBringer** scheme, or use:

```sh
swift run LightBringer
```

The clipboard history is stored locally in the app's user defaults. Plain text up to 20,000 characters and copied file references are recorded.

### Fixed-item preset format

Use the import button to choose a `.json` file containing an array of strings, or use the export button to create one:

```json
[
  "Thanks!",
  "I'll get back to you shortly."
]
```

Imported items are merged with existing fixed items; duplicates are skipped. Export includes fixed text items only, because file references are machine-specific.

### Quick menu

Right-click the menu-bar icon, or hold **Option** and right-click anywhere on screen, to open a menu with the first 5 fixed items and the 5 most recent copies. Click an item to copy it.

Option + right-click needs the Accessibility permission so Light Bringer can intercept that click (plain right-clicks are never touched). Grant it in System Settings → Privacy & Security → Accessibility. Because the app is ad-hoc signed, macOS may reset the permission after a rebuild; remove and re-add Light Bringer in that list if the shortcut stops working.

## Build and install the app

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh --install
open "/Applications/Light Bringer.app"
```

The script creates a release build, packages it as `dist/Light Bringer.app`, ad-hoc signs it for this Mac, and copies it to `/Applications`.
