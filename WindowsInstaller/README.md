# Prerequesites:

## Install Wix:
dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org
dotnet tool install --global wix
wix --version

Usage: dotnet build .\WindowsInstaller.wixproj