# Features

## Folder Intake

- Drag folders directly into the app.
- Add folders via system picker.
- Multi-folder list with selection, remove, and clear.

## Visual Customization

- Live side-by-side preview (`Current` vs `Preview`).
- Folder tint toggle and custom color selection.
- Reusable saved colors in the main color section.

## Folder Icon Source

- `None` mode (keep default folder icon behavior).
- `Custom` mode:
  - import custom icon/image files
  - clear icon
  - save icon to library
  - open collections directly from icon source controls

## Collections

Collections are opened from:
- Menu bar (`Collections > Open Collections`)
- Main window icon source section (`Open Collections`)

### Icons Collection

- Import icon files into library.
- Save current custom icon to library.
- Apply saved icon to current draft.
- Right-click actions:
  - Crop
  - Delete

### Metadata Collection

- Create metadata collection presets for future use:
  - name
  - Finder comment
  - tags
- Save current draft metadata as preset.
- Apply preset directly to selected folder.
- Context actions:
  - Apply to selected folder
  - Load metadata only
  - Delete

## Metadata Popup

Opened from:
- Menu bar (`Collections > Open Metadata`)
- Main window action button (`Metadata...`)

Capabilities:
- Edit Finder comment
- Edit tags
- Save metadata preset to collection
- Jump to Collections popup

## Apply/Revert Behavior

- Apply to selected folder.
- Apply to all listed folders.
- Revert selected folder to original state.
- Revert all listed folders.

## Persistence

- Finder comment and tags are written through native metadata xattrs.
- App customization metadata is persisted for reload.
- Snapshot of original state captured before first apply for reliable undo.

## Packaging

- One-step script builds release `.app` and `.dmg`.
- App icon is auto-detected from `icons/` (with optional override).
