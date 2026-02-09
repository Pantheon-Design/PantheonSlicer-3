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
BuildDir="build/$ARCH/PantheonSlicer-3"
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

# Sign the app bundle
echo ""
echo "=== Signing App Bundle ==="
if [ "$USE_ENTITLEMENTS" = true ]; then
    codesign --deep --force --verbose --options runtime --timestamp \
        --entitlements "../../../$ENTITLEMENTS_PATH" \
        -s "$SIGN_IDENTITY" "$AppBundle"
else
    codesign --deep --force --verbose --options runtime --timestamp \
        -s "$SIGN_IDENTITY" "$AppBundle"
fi

if [ $? -ne 0 ]; then
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

hdiutil create -volname "$BundleName" -srcfolder . -ov -format UDZO "$BundleName.dmg"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create DMG!"
    popd > /dev/null
    exit 1
fi

echo "✓ DMG created successfully"

# Sign the DMG
echo ""
echo "=== Signing DMG ==="
if [ "$USE_ENTITLEMENTS" = true ]; then
    codesign --deep --force --verbose --options runtime --timestamp \
        --entitlements "../../../$ENTITLEMENTS_PATH" \
        -s "$SIGN_IDENTITY" "$BundleName.dmg"
else
    codesign --deep --force --verbose --options runtime --timestamp \
        -s "$SIGN_IDENTITY" "$BundleName.dmg"
fi

if [ $? -ne 0 ]; then
    echo "❌ Failed to sign DMG!"
    popd > /dev/null
    exit 1
fi

# Verify DMG signature
echo ""
echo "=== Verifying DMG Signature ==="
codesign --verify --deep --strict --verbose=2 "$BundleName.dmg"

if [ $? -ne 0 ]; then
    echo "❌ DMG signature verification failed!"
    popd > /dev/null
    exit 1
fi

echo "✓ DMG signed successfully"

# Submit for notarization
echo ""
echo "=== Submitting for Notarization ==="
echo "This may take several minutes..."
xcrun notarytool submit "$BundleName.dmg" --wait --keychain-profile "notarytool-password"

# Check notarization result
if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Notarization successful!"
    
    # Staple the ticket
    echo ""
    echo "=== Stapling Ticket ==="
    xcrun stapler staple "$BundleName.dmg"
    
    if [ $? -eq 0 ]; then
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
