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
  ARCH="$(uname -m)"
  export ARCH
fi

Build="build_$ARCH"
BundleName="PantheonSlicer-3"
Contents="$BundleName.app/Contents"
Executable="${Contents}/MacOS/$BundleName"
SIGN_IDENTITY="Developer ID Application: Pantheon Design Ltd. (LXVCBJ7HN9)"

pushd $Build
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

codesign --deep --force --verbose --options runtime --timestamp --entitlements ../scripts/disable_validation.entitlements -s "$SIGN_IDENTITY" "$BundleName/$BundleName.app"

ln -s /Applications $BundleName/Applications
hdiutil create -volname "$BundleName" -srcfolder "$BundleName" -ov -format UDZO $BundleName.dmg
codesign --deep --force --verbose --options runtime --timestamp --entitlements ../scripts/disable_validation.entitlements -s "$SIGN_IDENTITY" $BundleName.dmg 
xcrun notarytool submit "$BundleName.dmg" --wait --keychain-profile "notarytool-password"
xcrun stapler staple "$BundleName.dmg"

popd
    