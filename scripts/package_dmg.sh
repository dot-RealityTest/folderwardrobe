#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_DISPLAY_NAME="folderwardrobe"
APP_EXECUTABLE="folderwardrobe"
BUNDLE_ID="com.kika.folderwardrobe"
BUNDLE_VERSION="$(date +%Y%m%d%H%M%S)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/${APP_DISPLAY_NAME}.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/${APP_DISPLAY_NAME}.dmg"
ICON_DIR="$ROOT_DIR/icons"
ICON_SOURCE="${ICON_SOURCE:-}"
ICON_NAME="AppIcon"
ICON_CORNER_RADIUS="220"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

resolve_icon_source() {
  local dir="$1"
  local candidate

  for candidate in \
    "$dir/Image.png" \
    "$dir/AppIcon.png" \
    "$dir/icon.png" \
    "$dir/AppIcon.icns" \
    "$dir/icon.icns"; do
    if [[ -f "$candidate" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done

  local latest
  latest="$(ls -1t \
    "$dir"/*.png "$dir"/*.PNG \
    "$dir"/*.jpg "$dir"/*.JPG \
    "$dir"/*.jpeg "$dir"/*.JPEG \
    "$dir"/*.icns "$dir"/*.ICNS 2>/dev/null | head -n 1 || true)"

  if [[ -n "$latest" ]]; then
    printf "%s\n" "$latest"
  fi
}

resolve_sign_identity() {
  local raw
  raw="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  printf "%s\n" "$raw" | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1
}

apply_bundle_icon() {
  local icon_file="$1"
  local app_path="$2"

  swift - "$icon_file" "$app_path" <<'SWIFT'
import AppKit
import Foundation

let args = CommandLine.arguments
if args.count >= 3 {
    let iconURL = URL(fileURLWithPath: args[1])
    let appPath = args[2]
    if let image = NSImage(contentsOf: iconURL) {
        _ = NSWorkspace.shared.setIcon(image, forFile: appPath, options: [])
    }
}
SWIFT
}

if [[ -z "$ICON_SOURCE" ]]; then
  ICON_SOURCE="$(resolve_icon_source "$ICON_DIR" || true)"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(resolve_sign_identity || true)"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

echo "Signing identity: $SIGN_IDENTITY"

swift build -c release

rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$DMG_ROOT"
cp "$ROOT_DIR/.build/release/$APP_EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE"

HAS_ICON=0
if [[ -n "${ICON_SOURCE:-}" && -f "$ICON_SOURCE" ]]; then
  echo "Using app icon source: $ICON_SOURCE"
  HAS_ICON=1
  ICON_WORKDIR="$(mktemp -d)"
  ICONSET_DIR="$ICON_WORKDIR/${ICON_NAME}.iconset"
  NORMALIZED_MASTER="$ICON_WORKDIR/${ICON_NAME}-master.png"
  mkdir -p "$ICONSET_DIR"

  # Normalize icon with zero padding: trim transparent edges and scale to full canvas.
  swift - "$ICON_SOURCE" "$NORMALIZED_MASTER" "$ICON_CORNER_RADIUS" <<'SWIFT'
import AppKit
import Foundation
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 3 else { fatalError("Missing icon paths") }
let inputPath = args[1]
let outputPath = args[2]
let cornerRadius = CGFloat(Double(args.count > 3 ? args[3] : "220") ?? 220)

guard let source = NSImage(contentsOfFile: inputPath) else {
    fatalError("Unable to load icon source at \(inputPath)")
}

guard let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Unable to read CGImage from icon source")
}

let srcWidth = sourceCG.width
let srcHeight = sourceCG.height
let bytesPerPixel = 4
let bytesPerRow = srcWidth * bytesPerPixel
var pixelBuffer = [UInt8](repeating: 0, count: srcHeight * bytesPerRow)

guard let scanContext = CGContext(
    data: &pixelBuffer,
    width: srcWidth,
    height: srcHeight,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Unable to create scan context")
}

scanContext.draw(sourceCG, in: CGRect(x: 0, y: 0, width: srcWidth, height: srcHeight))

var minX = srcWidth
var minY = srcHeight
var maxX = 0
var maxY = 0
var hasVisiblePixel = false

for y in 0 ..< srcHeight {
    for x in 0 ..< srcWidth {
        let offset = y * bytesPerRow + (x * bytesPerPixel)
        let alpha = pixelBuffer[offset + 3]
        if alpha > 0 {
            hasVisiblePixel = true
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
}

let croppedCG: CGImage = {
    guard hasVisiblePixel else { return sourceCG }
    let cropRect = CGRect(
        x: minX,
        y: minY,
        width: (maxX - minX + 1),
        height: (maxY - minY + 1)
    )
    return sourceCG.cropping(to: cropRect) ?? sourceCG
}()

let targetSize = NSSize(width: 1024, height: 1024)
let output = NSImage(size: targetSize, flipped: false) { rect in
    NSColor.clear.setFill()
    rect.fill()

    let effectiveRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
    let clipPath = NSBezierPath(roundedRect: rect, xRadius: effectiveRadius, yRadius: effectiveRadius)
    clipPath.addClip()

    NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height)).draw(
        in: rect,
        from: NSRect(origin: .zero, size: NSSize(width: croppedCG.width, height: croppedCG.height)),
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    return true
}

guard
    let tiff = output.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fatalError("Unable to generate normalized icon image")
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$NORMALIZED_MASTER" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$NORMALIZED_MASTER" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done

  iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/${ICON_NAME}.icns"
  rm -rf "$ICON_WORKDIR"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_EXECUTABLE}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>${BUNDLE_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
PLIST

if [[ "$HAS_ICON" -eq 1 ]]; then
  cat >> "$APP_BUNDLE/Contents/Info.plist" <<PLIST
    <key>CFBundleIconName</key>
    <string>${ICON_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>${ICON_NAME}</string>
PLIST
fi

cat >> "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
</dict>
</plist>
PLIST

SIGN_ARGS=(--force --deep --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--options runtime --timestamp)
  # Notarization rejects Finder metadata xattrs, so keep signed bundles clean.
  xattr -cr "$APP_BUNDLE"
fi
codesign "${SIGN_ARGS[@]}" "$APP_BUNDLE"

if [[ "$HAS_ICON" -eq 1 && "$SIGN_IDENTITY" == "-" ]]; then
  apply_bundle_icon "$APP_BUNDLE/Contents/Resources/${ICON_NAME}.icns" "$APP_BUNDLE"
fi

cp -R "$APP_BUNDLE" "$DMG_ROOT/"

if [[ "$HAS_ICON" -eq 1 && "$SIGN_IDENTITY" == "-" ]]; then
  apply_bundle_icon "$APP_BUNDLE/Contents/Resources/${ICON_NAME}.icns" "$DMG_ROOT/${APP_DISPLAY_NAME}.app"
fi
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "$APP_DISPLAY_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" >/tmp/folderwardrobe_dmg.log
rm -rf "$DMG_ROOT"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
fi

echo "Built app: $APP_BUNDLE"
echo "Built dmg: $DMG_PATH"
