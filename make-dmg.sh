#!/bin/bash
# Builds a Release Aries.app and packages it as Aries.dmg (drag-to-Applications).
# No paid Apple account needed. Run from the repo root: bash make-dmg.sh
set -e

SCHEME="Aries"
PROJECT="Valentine.xcodeproj"
APP_NAME="Aries"
BUILD_DIR="build_dmg"
DMG_NAME="Aries.dmg"

echo "==> Building Release..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build a Release app into a known location.
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$BUILD_DIR/dd" \
    CONFIGURATION_BUILD_DIR="$PWD/$BUILD_DIR/app" \
    build

APP_PATH="$BUILD_DIR/app/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found after build."
    exit 1
fi

echo "==> Staging .dmg contents..."
STAGE="$BUILD_DIR/stage"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
# A symlink to /Applications so the user can drag the app onto it.
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $DMG_NAME..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG_NAME"

echo "==> Cleaning up..."
rm -rf "$BUILD_DIR"

echo "Done. Created $DMG_NAME"
echo "Upload it to a GitHub Release on your fork (see README)."
