#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MediaHarbor"
BUNDLE_ID="app.mediaharbor.desktop"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${MEDIAHARBOR_VERSION:-0.0.0-dev}"
BUILD_CONFIGURATION="debug"

if [[ "$MODE" == "--package" || "$MODE" == "package" ]]; then
  BUILD_CONFIGURATION="release"
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$PROJECT_ROOT"
swift build -c "$BUILD_CONFIGURATION"
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>MediaHarbor</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME launched successfully."
    ;;
  --package|package)
    ARCHITECTURE="$(uname -m)"
    ARCHIVE="$DIST_DIR/$APP_NAME-v$APP_VERSION-macos-$ARCHITECTURE.zip"
    DISK_IMAGE="$DIST_DIR/$APP_NAME-v$APP_VERSION-macos-$ARCHITECTURE.dmg"
    READ_WRITE_IMAGE="$DIST_DIR/$APP_NAME-v$APP_VERSION-macos-$ARCHITECTURE-rw.dmg"
    PACKAGE_MOUNT="$(mktemp -d "$DIST_DIR/$APP_NAME-mount.XXXXXX")"
    cleanup_package() {
      hdiutil detach "$PACKAGE_MOUNT" >/dev/null 2>&1 || true
      rm -f "$READ_WRITE_IMAGE"
      rmdir "$PACKAGE_MOUNT" >/dev/null 2>&1 || true
    }
    trap cleanup_package EXIT
    xattr -cr "$APP_BUNDLE"
    codesign --force --deep --sign - "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
    rm -f "$ARCHIVE" "$DISK_IMAGE" "$READ_WRITE_IMAGE"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"
    hdiutil create -volname "$APP_NAME" -size 64m -fs HFS+ -type UDIF "$READ_WRITE_IMAGE"
    hdiutil attach -nobrowse -mountpoint "$PACKAGE_MOUNT" "$READ_WRITE_IMAGE" >/dev/null
    ditto "$APP_BUNDLE" "$PACKAGE_MOUNT/$APP_NAME.app"
    ln -s /Applications "$PACKAGE_MOUNT/Applications"
    xattr -cr "$PACKAGE_MOUNT/$APP_NAME.app"
    codesign --force --deep --sign - "$PACKAGE_MOUNT/$APP_NAME.app"
    codesign --verify --deep --strict --verbose=2 "$PACKAGE_MOUNT/$APP_NAME.app"
    hdiutil detach "$PACKAGE_MOUNT" >/dev/null
    hdiutil convert "$READ_WRITE_IMAGE" -format UDZO -o "$DISK_IMAGE"
    cleanup_package
    trap - EXIT
    shasum -a 256 "$ARCHIVE" "$DISK_IMAGE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2
    exit 2
    ;;
esac
