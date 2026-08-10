#!/bin/bash

set -e  # Exit on error

while getopts "a:" opt; do
  case "${opt}" in
    a )
        export ARCH="$OPTARG"
        ;;
    * )
        ;;
  esac
done

if [ -z "$ARCH" ]; then
  ARCH="universal"
  export ARCH
fi

echo "Signing and notarizing for architecture: $ARCH"

# Updated directory structure to match your setup
BuildDir="build_$ARCH/PantheonSlicer-3"
BundleName="PantheonSlicer-3"
AppBundle="$BundleName.app"
SIGN_IDENTITY="Developer ID Application: Pantheon Design Ltd. (LXVCBJ7HN9)"

# Check if build directory exists
if [ ! -d "$BuildDir" ]; then
    echo "❌ Error: Build directory not found at $BuildDir"
    exit 1
fi

# Check if app bundle exists
if [ ! -d "$BuildDir/$AppBundle" ]; then
    echo "❌ Error: App bundle not found at $BuildDir/$AppBundle"
    exit 1
fi

# Check if entitlements file exists
ENTITLEMENTS_PATH="scripts/disable_validation.entitlements"
if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo "⚠️  Warning: Entitlements file not found at $ENTITLEMENTS_PATH"
    echo "Signing without entitlements..."
    USE_ENTITLEMENTS=false
else
    USE_ENTITLEMENTS=true
fi

echo ""
echo "=== Starting signing process ==="
echo "App Bundle: $BuildDir/$AppBundle"
echo "Identity: $SIGN_IDENTITY"
echo ""

pushd "$BuildDir" > /dev/null

# Clean up any existing distribution files
echo "Cleaning up old distribution files..."
[ -f "$BundleName.dmg" ] && rm "$BundleName.dmg"
[ -f "$BundleName.zip" ] && rm "$BundleName.zip"
[ -f "$BundleName.tar" ] && rm "$BundleName.tar"
[ -f "temp.dmg" ] && rm "temp.dmg"
[ -d "pack" ] && rm -r "pack"

# Unlock keychain to prevent password prompts
echo "Unlocking keychain..."
security unlock-keychain ~/Library/Keychains/login.keychain-db || echo "⚠️  Could not unlock keychain, you may be prompted for password"

# Sign the app bundle (retry — timestamp.apple.com is occasionally unavailable)
echo ""
echo "=== Signing App Bundle ==="
SIGN_OK=false
for attempt in 1 2 3; do
    if [ "$USE_ENTITLEMENTS" = true ]; then
        if codesign --deep --force --verbose --options runtime --timestamp \
            --entitlements "../../$ENTITLEMENTS_PATH" \
            -s "$SIGN_IDENTITY" "$AppBundle"; then
            SIGN_OK=true
            break
        fi
    else
        if codesign --deep --force --verbose --options runtime --timestamp \
            -s "$SIGN_IDENTITY" "$AppBundle"; then
            SIGN_OK=true
            break
        fi
    fi
    echo "Signing attempt $attempt failed, retrying in 15 seconds..."
    sleep 15
done

if [ "$SIGN_OK" != true ]; then
    echo "❌ Failed to sign app bundle!"
    popd > /dev/null
    exit 1
fi

# Verify the signature
echo ""
echo "=== Verifying App Signature ==="
codesign --verify --deep --strict --verbose=2 "$AppBundle"

if [ $? -ne 0 ]; then
    echo "❌ Signature verification failed!"
    popd > /dev/null
    exit 1
fi

echo "✓ App bundle signed successfully"

# Create DMG
echo ""
echo "=== Creating DMG ==="
# Create a temporary folder for DMG contents if it doesn't exist
if [ ! -L "Applications" ]; then
    ln -s /Applications Applications
fi

# Use HFS+ filesystem (-fs HFS+) because APFS DMGs do not support ticket stapling.
# macOS 26+ defaults to APFS, which causes stapling to fail with Error 65.
#
# Build under a staging volume name, then rename before converting. macOS App
# Management (TCC) blocks writing an app bundle at
# /Volumes/$BundleName/$AppBundle because that path is registered to the app
# installed in /Applications, so `hdiutil create -volname $BundleName` fails
# with "Operation not permitted" unless the terminal app has the App
# Management privacy permission. Renaming the volume afterwards never writes
# the protected path.
TEMP_DMG="$(mktemp -d)/temp.dmg"
hdiutil create -volname "$BundleName-staging" -srcfolder . -ov -format UDRW -fs HFS+ "$TEMP_DMG"
STAGING_DEV=$(hdiutil attach "$TEMP_DMG" -nobrowse | grep Apple_HFS | awk '{print $1}')
diskutil rename "$STAGING_DEV" "$BundleName"
hdiutil detach "$STAGING_DEV"
hdiutil convert "$TEMP_DMG" -format UDZO -o "$BundleName.dmg" -ov
rm -f "$TEMP_DMG"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create DMG!"
    popd > /dev/null
    exit 1
fi

echo "✓ DMG created successfully"

# Note: DMGs are NOT code-signed. Signing a DMG with codesign conflicts with
# stapling, because stapling modifies the file and invalidates the code signature.
# Gatekeeper validates DMGs via the stapled notarization ticket, not a code signature.

# Submit for notarization
echo ""
echo "=== Submitting for Notarization ==="
echo "This may take several minutes..."
xcrun notarytool submit "$BundleName.dmg" --wait --keychain-profile "notarytool-password"

# Check notarization result
if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Notarization successful!"
    
    # Staple the ticket (may need retries — Apple's CDN can lag behind acceptance)
    echo ""
    echo "=== Stapling Ticket ==="
    STAPLE_SUCCESS=false
    for i in 1 2 3 4 5; do
        if xcrun stapler staple "$BundleName.dmg"; then
            STAPLE_SUCCESS=true
            break
        fi
        echo "Stapling attempt $i failed, waiting 30 seconds before retry..."
        sleep 30
    done

    if [ "$STAPLE_SUCCESS" = true ]; then
        echo ""
        echo "✅ SUCCESS!"
        echo "Signed and notarized DMG created at:"
        echo "  $(pwd)/$BundleName.dmg"
        echo ""
        echo "You can now distribute this DMG."
    else
        echo ""
        echo "⚠️  Warning: Stapling failed, but DMG is notarized"
        echo "Users will need internet connection on first launch to verify."
        echo ""
        echo "DMG location:"
        echo "  $(pwd)/$BundleName.dmg"
    fi
else
    echo ""
    echo "❌ Notarization failed!"
    echo ""
    echo "To get more details, run:"
    echo "  xcrun notarytool log <submission-id> --keychain-profile \"notarytool-password\""
    popd > /dev/null
    exit 1
fi

popd > /dev/null
