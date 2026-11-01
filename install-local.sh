#!/usr/bin/env bash
# Build AeroSpace from this checkout and install it over /Applications/AeroSpace.app
# Uses Xcode's toolchain instead of swiftly and skips docs/shell-completion (no ruby/rust needed)
# Usage: ./install-local.sh ["codesign identity"]
set -euo pipefail
cd "$(dirname "$0")"

identity="${1:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | head -1)}"
test -n "$identity" || { echo "No codesign identity found" >&2; exit 1; }
version="$(git describe --tags --abbrev=0 | sed 's/^v//; s/-Beta$//')-bl4ko"

# Stand-in for swiftly: `swiftly run swift` -> Xcode's swift, `swiftly use --print-location` -> Xcode toolchain
shim="$(mktemp -d)"
trap 'rm -rf "$shim"; git checkout -q -- Sources/Common xcode' EXIT
mkdir "$shim/tc"
cp "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/ToolchainInfo.plist" "$shim/tc/Info.plist"
plutil -replace CFBundleIdentifier -string com.apple.dt.toolchain.XcodeDefault "$shim/tc/Info.plist"
cat > "$shim/swiftly" <<EOF
#!/bin/sh
[ "\$1" = use ] && { echo "$shim/tc"; exit; }
[ "\$1" = run ] && shift && [ "\$1" = swift ] && shift
exec /usr/bin/swift "\$@"
EOF
chmod +x "$shim/swiftly"
export PATH="$shim:/opt/homebrew/bin:$PATH"

/opt/homebrew/bin/bash ./generate.sh --build-version "$version" --codesign-identity "$identity" --generate-git-hash
cli=(build -c release --arch arm64 --arch x86_64 --product aerospace)
swift "${cli[@]}"
cli_bin="$(swift "${cli[@]}" --show-bin-path)/aerospace"
codesign -f -s "$identity" "$cli_bin"
(cd xcode && xcrun xcodebuild -quiet clean build -scheme AeroSpace -destination generic/platform=macOS \
    -configuration Release -derivedDataPath .xcode-build)
app=xcode/.xcode-build/Build/Products/Release/AeroSpace.app
codesign -v "$app"

if brew list --cask aerospace &> /dev/null; then brew uninstall --cask aerospace; fi
pkill -x AeroSpace && while pgrep -x AeroSpace > /dev/null; do sleep 0.2; done || true
rm -rf /Applications/AeroSpace.app
cp -R "$app" /Applications/
install -m 755 "$cli_bin" /opt/homebrew/bin/aerospace
open -a AeroSpace
echo "Installed AeroSpace $version"
