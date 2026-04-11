# folderwardrobe

`folderwardrobe` is a native macOS utility for customizing Finder folders with a fast, visual workflow.

It focuses on three things:
- folder color/tint
- custom folder icon replacement
- metadata presets (Finder comment + tags)

## What It Does

- Accepts folders via drag-and-drop or picker.
- Shows current vs preview icon before apply.
- Applies changes persistently using native macOS APIs.
- Stores reusable collections for:
  - Icons
  - Metadata presets
- Supports revert/undo by saving per-folder snapshots before first apply.

## Current UI Layout

- Main window:
  - Folders list + selection
  - Color controls
  - Folder Icon Source (`None` or `Custom`)
  - Apply/Revert actions
  - Quick access buttons for `Metadata...` and `Open Collections`
- Menu bar:
  - `Collections > Open Collections`
  - `Collections > Open Metadata`
- Collections popup:
  - `Icons`
  - `Metadata`

## Persistence & Finder Integration

The app uses:
- `NSWorkspace.setIcon(_:forFile:options:)` for folder icons.
- Extended attributes for Finder metadata:
  - `com.apple.metadata:kMDItemFinderComment`
  - `com.apple.metadata:_kMDItemUserTags`
- App-owned metadata xattr:
  - `com.foldercolor.customization.v1`

Snapshot storage location:
- `~/Library/Application Support/folderwardrobe/snapshots.json`

Collections storage location:
- `~/Library/Application Support/folderwardrobe/`
  - `icon-library.json`
  - `metadata-library.json`
  - `color-library.json`

## Requirements

- macOS 13+
- Xcode 15+ (or Swift 5.10+ toolchain)

## Build & Run

```bash
swift build
swift run folderwardrobe
```

## Package `.app` + `.dmg`

```bash
./scripts/package_dmg.sh
```

Outputs:
- `dist/folderwardrobe.app`
- `dist/folderwardrobe.dmg`

## App Icon Behavior

Packaging script now auto-selects icon source from `icons/`.
Priority:
1. `icons/Image.png`
2. `icons/AppIcon.png`
3. `icons/icon.png`
4. `icons/AppIcon.icns`
5. `icons/icon.icns`
6. Newest matching image/icns in `icons/`

Optional override:
```bash
ICON_SOURCE="/absolute/path/to/icon.png" ./scripts/package_dmg.sh
```

## Project Structure

- `Package.swift`
- `Sources/FolderColorApp/Models` - models/errors
- `Sources/FolderColorApp/Services` - rendering, apply/revert, xattr, snapshots, collections storage
- `Sources/FolderColorApp/ViewModels` - state + actions
- `Sources/FolderColorApp/Views` - SwiftUI UI + popups + commands
- `Sources/FolderColorApp/Utilities` - image helpers
- `scripts/package_dmg.sh` - build + app bundle + dmg packaging

## Notes

- Finder metadata display can lag until Finder refreshes.
- Some copy/move methods may strip xattrs.
- Protected/system folders can fail due to permissions.

## Notarize For Distribution

Use the notarization script (Developer ID sign + notarize + staple):

```bash
APPLE_ID="your-apple-id@example.com" \
APPLE_TEAM_ID="YOURTEAMID" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./scripts/notarize_dmg.sh
```

Outputs (notarized + stapled):
- `dist/folderwardrobe.app`
- `dist/folderwardrobe.dmg`

Optional signing override:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/notarize_dmg.sh
```
