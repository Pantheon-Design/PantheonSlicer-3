#!/bin/bash

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

# Updated build directory structure
BuildDir="build/$ARCH/PantheonSlicer-3"
BundleName="PantheonSlicer-3"
AppBundle="$BundleName.app"
SIGN_IDENTITY="Developer ID Application: Pantheon Design Ltd. (LXVCBJ7HN9)"

# Check if build directory exists
if [ ! -d "$BuildDir" ]; then
    echo "Error: Build directory not found at $BuildDir"
    echo "Please build the application first with: ./pantheon_build_release_macos.sh -a $ARCH"
    exit 1
fi

# Check if app bundle exists
if [ ! -d "$BuildDir/$AppBundle" ]; then
    echo "Error: App bundle not found at $BuildDir/$AppBundle"
    exit 1
fi

pushd "$BuildDir"

# Clean up any existing distribution files
if [ -f "$BundleName.dmg" ]; then
    echo "Deleting existing image at $BundleName.dmg"
    rm "$BundleName.dmg"
fi

if [ -f "$BundleName.zip" ]; then
    echo "Deleting existing $BundleName.zip"
    rm "$BundleName.zip"
fi

if [ -f "$BundleName.tar" ]; then
    echo "Deleting existing $BundleName.tar"
    rm "$BundleName.tar"
fi

if [ -f "temp.dmg" ]; then
    echo "Deleting existing temp.dmg"
    rm "temp.dmg"
fi

if [ -d "pack" ]; then
    echo "Deleting existing pack folder"
    rm -r "pack"
fi

# Sign the app bundle
echo "Signing $AppBundle..."
codesign --deep --force --verbose --options runtime --timestamp \
    --entitlements ../../scripts/disable_validation.entitlements \
    -s "$SIGN_IDENTITY" "$AppBundle"

# Verify the signature
echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$AppBundle"

# Create DMG
echo "Creating DMG..."
# Create a temporary folder for DMG contents if it doesn't exist
if [ ! -L "Applications" ]; then
    ln -s /Applications Applications
fi

hdiutil create -volname "$BundleName" -srcfolder . -ov -format UDZO "$BundleName.dmg"

# Sign the DMG
echo "Signing DMG..."
codesign --deep --force --verbose --options runtime --timestamp \
    --entitlements ../../scripts/disable_validation.entitlements \
    -s "$SIGN_IDENTITY" "$BundleName.dmg"

# Verify DMG signature
echo "Verifying DMG signature..."
codesign --verify --deep --strict --verbose=2 "$BundleName.dmg"

# Submit for notarization
echo "Submitting for notarization..."
xcrun notarytool submit "$BundleName.dmg" --wait --keychain-profile "notarytool-password"

# Check notarization result
if [ $? -eq 0 ]; then
    echo "Notarization successful!"
    
    # Staple the ticket
    echo "Stapling ticket..."
    xcrun stapler staple "$BundleName.dmg"
    
    if [ $? -eq 0 ]; then
        echo "✅ Success! Signed and notarized DMG created at: $BuildDir/$BundleName.dmg"
    else
        echo "⚠️  Warning: Stapling failed, but DMG is notarized"
    fi
else
    echo "❌ Notarization failed!"
    exit 1
fi

popd
