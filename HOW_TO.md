# How To Use folderwardrobe

## 1. Add Folders

1. Launch the app.
2. Drag folders into the left panel, or click to choose folders.
3. Select a folder from the list.

## 2. Change Folder Color

1. In `Color`, enable `Enable Folder Tint`.
2. Pick your color.
3. (Optional) click `Save Current Color` for quick reuse.

## 3. Use a Custom Folder Icon

1. In `Folder Icon Source`, choose `Custom`.
2. Click `Choose Custom Icon` and pick an image/icon file.
3. Optional actions:
   - `Save To Icon Library`
   - `Open Collections` to manage/apply saved icons

## 4. Work With Icon Collections

1. Open collections (`Open Collections` button or menu bar).
2. Go to `Icons` tab.
3. You can:
   - import icon files
   - save current icon
   - click a saved icon to load/apply in draft
   - right-click icon for `Crop` or `Delete`

## 5. Work With Metadata Collections

1. Open collections and go to `Metadata` tab.
2. In `Create Metadata Collection`, fill:
   - name (optional)
   - Finder comment
   - tags (comma separated)
3. Click `Create Collection`.
4. Click any saved metadata item to apply it to the selected folder.
5. Right-click for:
   - `Apply to Selected Folder`
   - `Load Metadata Only`
   - `Delete`

## 6. Use Metadata Popup

Open metadata popup from:
- Menu bar: `Collections > Open Metadata`
- Main window: `Metadata...`

In popup, you can edit comment/tags and save presets to collections.

## 7. Apply Changes

- `Apply to Selected` applies current draft to selected folder.
- `Apply to All` applies current draft to all listed folders.

## 8. Revert Changes

- `Revert Selected` restores original selected folder state.
- `Revert All` restores original state for all listed folders.

## Build & Package

### Build locally

```bash
swift build
```

### Run

```bash
swift run folderwardrobe
```

### Build `.app` and `.dmg`

```bash
./scripts/package_dmg.sh
```

Output files:
- `dist/folderwardrobe.app`
- `dist/folderwardrobe.dmg`

## App Icon Override (Optional)

Use a specific icon file when packaging:

```bash
ICON_SOURCE="/absolute/path/to/icon.png" ./scripts/package_dmg.sh
```

## Troubleshooting

- If Finder does not immediately show metadata/icon changes, refresh Finder.
- If apply fails on protected locations, verify folder permissions.
- If metadata is too large, reduce icon/metadata payload size and retry.

## Notarize For Release

```bash
APPLE_ID="your-apple-id@example.com" \
APPLE_TEAM_ID="YOURTEAMID" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./scripts/notarize_dmg.sh
```

This will:
- build + sign app with Developer ID
- build + sign DMG
- submit DMG to Apple notarization service
- wait for `Accepted`
- staple ticket to both `.app` and `.dmg`
