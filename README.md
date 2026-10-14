# Light Bringer

A small native macOS menu-bar clipboard utility built with SwiftUI.

## Features

- Fixed, reusable text snippets
- The 20 most recent unique text or file clipboard items
- Click any item to copy it
- Right-click an item to pin or delete it
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

## Build and install the app

```sh
chmod +x scripts/build-app.sh
./scripts/build-app.sh --install
open "/Applications/Light Bringer.app"
```

The script creates a release build, packages it as `dist/Light Bringer.app`, ad-hoc signs it for this Mac, and copies it to `/Applications`.
