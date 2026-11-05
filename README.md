# SignBridge for Mac

Minimal **menu bar** signing app for Indian DSC / PKCS#11 tokens. Native SwiftUI, Apple HIG.

Private keys stay on the token. Documents are hashed on-device; only the SHA-256 fingerprint is signed via [`signbridge-rpc`](https://github.com/Hunchbite/signbridge).

```
┌─ menu bar ─────────────────────────┐
│  SignBridge          1 certificate │
│  Certificate · Synthetic Indian…   │
│  [ Sign Document… ]                │
│  OpenSC ready · 3 modules          │
│  Settings…                  Quit   │
└────────────────────────────────────┘
```

## Requirements

- macOS 14+
- Xcode 16+
- [`signbridge-rpc`](https://github.com/Hunchbite/signbridge) on disk (release build or `~/.signbridge/bin/`)

## Build & run

```bash
# 1. Engine (once)
cd ../signbridge && cargo build -p signbridge-rpc --release

# 2. App
cd ../signbridge-mac
xcodegen generate
open SignBridge.xcodeproj
# ⌘R — look for the signature glyph in the menu bar
```

Or from the CLI:

```bash
xcodegen generate
xcodebuild -scheme SignBridge -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/SignBridge.app
```

## Settings

| Field | Purpose |
|---|---|
| Engine path | Override auto-discovery of `signbridge-rpc` |
| Token PIN | Optional; stored in UserDefaults for local use |

## Design notes

- `LSUIElement` agent — lives in the menu bar, not the Dock
- `MenuBarExtra` + `.window` style (macOS 13+)
- System materials, SF Symbols, Settings scene (⌘,)
- No document upload: local hash only

## Licence

MIT OR Apache-2.0 · Hunchbite
