#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"
workspace=apps/macos/macos/ICloudSyncMac.xcworkspace
if [ ! -f apps/macos/macos/Pods/Manifest.lock ]; then
  echo 'Run pnpm pods:macos before checking the macOS app.' >&2
  exit 1
fi
# Compile and link the actual app without an Apple Developer signing identity.
# Real iCloud access must be checked separately with a provisioned app.
xcodebuild -workspace "$workspace" -scheme ICloudSyncMac-macOS \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath apps/macos/macos/build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
