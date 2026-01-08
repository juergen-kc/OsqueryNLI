#!/bin/bash
set -e

# =============================================================================
# Osquery NLI - Release Build Script
# =============================================================================
# This script builds, signs, notarizes, and packages the app as a DMG.
#
# Prerequisites:
#   1. Xcode Command Line Tools installed
#   2. Developer ID Application certificate in Keychain
#   3. Notarization credentials stored (see below)
#   4. App icon PNG at Distribution/AppIcon.png (1024x1024)
#
# Setup notarization credentials (one-time):
#   xcrun notarytool store-credentials "AC_PASSWORD" \
#     --apple-id "juergen.klaassen@web.de" \
#     --team-id "E89Q3796E9"
#
# Usage:
#   ./scripts/build-release.sh
#   ./scripts/build-release.sh --skip-notarize  # Skip notarization (for testing)
# =============================================================================

# Configuration
APP_NAME="Osquery NLI"
BUNDLE_ID="com.klaassen.OsqueryNLI"
VERSION="1.0.4"
SIGNING_IDENTITY="Developer ID Application"  # Will auto-select your cert
NOTARIZE_PROFILE="AC_PASSWORD"  # Name used in store-credentials
TEAM_ID="E89Q3796E9"
APPLE_ID="juergen.klaassen@web.de"

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/Distribution"
OUTPUT_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$OUTPUT_DIR/OsqueryNLI.app"
DMG_NAME="OsqueryNLI-$VERSION.dmg"

# Parse arguments
SKIP_NOTARIZE=false
for arg in "$@"; do
    case $arg in
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[BUILD]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =============================================================================
# Step 0: Verify Prerequisites
# =============================================================================
log "Checking prerequisites..."

# Check for signing identity
if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
    error "No '$SIGNING_IDENTITY' certificate found. Please install your Developer ID certificate."
fi

FULL_IDENTITY=$(security find-identity -v -p codesigning | grep "$SIGNING_IDENTITY" | head -1 | sed 's/.*"\(.*\)"/\1/')
log "Using signing identity: $FULL_IDENTITY"

# Check for notarization credentials (unless skipping)
if [ "$SKIP_NOTARIZE" = false ]; then
    if ! xcrun notarytool history --keychain-profile "$NOTARIZE_PROFILE" &>/dev/null; then
        warn "Notarization credentials not found. Run:"
        warn "  xcrun notarytool store-credentials \"$NOTARIZE_PROFILE\" --apple-id \"your@email.com\" --team-id \"TEAM_ID\""
        warn "Continuing without notarization (use --skip-notarize to suppress this warning)"
        SKIP_NOTARIZE=true
    fi
fi

# =============================================================================
# Step 1: Build Release Binaries
# =============================================================================
log "Building release binaries..."
cd "$PROJECT_DIR"
swift build -c release

if [ ! -f "$BUILD_DIR/OsqueryNLI" ]; then
    error "Build failed - OsqueryNLI executable not found"
fi

if [ ! -f "$BUILD_DIR/OsqueryMCPServer" ]; then
    error "Build failed - OsqueryMCPServer executable not found"
fi

log "Build successful!"

# =============================================================================
# Step 2: Create App Bundle
# =============================================================================
log "Creating app bundle..."

# Clean previous builds
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executables
cp "$BUILD_DIR/OsqueryNLI" "$APP_BUNDLE/Contents/MacOS/"
cp "$BUILD_DIR/OsqueryMCPServer" "$APP_BUNDLE/Contents/Resources/"

# Copy AI Discovery extension (if available)
AI_EXTENSION="$PROJECT_DIR/Resources/ai_tables.ext"
if [ -f "$AI_EXTENSION" ]; then
    cp "$AI_EXTENSION" "$APP_BUNDLE/Contents/Resources/"
    log "Included AI Discovery extension"
else
    warn "AI Discovery extension not found at $AI_EXTENSION"
fi

# Copy Info.plist
cp "$DIST_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Update version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_BUNDLE/Contents/Info.plist"

# =============================================================================
# Step 3: Generate App Icon
# =============================================================================
log "Generating app icon..."

ICON_SOURCE="$DIST_DIR/AppIcon.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"

if [ -f "$ICON_SOURCE" ]; then
    # Generate iconset from source PNG
    mkdir -p "$ICONSET_DIR"

    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png"
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png"
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png"
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png"
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png"
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png"
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png"
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png"

    # Convert to icns
    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    log "App icon generated from $ICON_SOURCE"
elif [ -f "$DIST_DIR/AppIcon.icns" ]; then
    # Use existing icns file
    cp "$DIST_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    log "Using existing AppIcon.icns"
else
    warn "No app icon found. Add Distribution/AppIcon.png (1024x1024) or Distribution/AppIcon.icns"
    warn "The app will use a generic icon."
fi

# =============================================================================
# Step 4: Code Signing
# =============================================================================
log "Signing app bundle..."

# Sign the MCP server first (nested code)
codesign --force --verify --verbose \
    --sign "$FULL_IDENTITY" \
    --options runtime \
    --entitlements "$DIST_DIR/Entitlements.plist" \
    "$APP_BUNDLE/Contents/Resources/OsqueryMCPServer"

# Sign the AI Discovery extension if present
if [ -f "$APP_BUNDLE/Contents/Resources/ai_tables.ext" ]; then
    codesign --force --verify --verbose \
        --sign "$FULL_IDENTITY" \
        --options runtime \
        "$APP_BUNDLE/Contents/Resources/ai_tables.ext"
fi

# Sign the main app
codesign --force --verify --verbose \
    --sign "$FULL_IDENTITY" \
    --options runtime \
    --entitlements "$DIST_DIR/Entitlements.plist" \
    "$APP_BUNDLE"

# Verify signature
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
log "Code signing complete!"

# =============================================================================
# Step 5: Notarization
# =============================================================================
if [ "$SKIP_NOTARIZE" = false ]; then
    log "Submitting for notarization..."

    # Create ZIP for notarization
    NOTARIZE_ZIP="$OUTPUT_DIR/OsqueryNLI-notarize.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"

    # Submit and wait
    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait

    # Staple the ticket
    xcrun stapler staple "$APP_BUNDLE"

    # Clean up
    rm "$NOTARIZE_ZIP"

    log "Notarization complete!"
else
    warn "Skipping notarization (--skip-notarize flag or missing credentials)"
fi

# =============================================================================
# Step 6: Create DMG
# =============================================================================
log "Creating DMG..."

DMG_TEMP="$OUTPUT_DIR/dmg-temp"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

# Create DMG contents
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG (use name without spaces to avoid mount conflicts)
hdiutil create -volname "OsqueryNLI" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

# Sign DMG
codesign --sign "$FULL_IDENTITY" "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP"

# =============================================================================
# Done!
# =============================================================================
log "Build complete!"
echo ""
echo "============================================="
echo "  Output: $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo "============================================="
echo ""

if [ "$SKIP_NOTARIZE" = true ]; then
    warn "Note: DMG was not notarized. Users may see Gatekeeper warnings."
fi
