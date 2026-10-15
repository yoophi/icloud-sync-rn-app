#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"
sdk_path=$(xcrun --sdk iphoneos --show-sdk-path)
pods=apps/mobile/ios/Pods
react_framework="$pods/React-Core-prebuilt/React.xcframework/ios-arm64"
react_headers="$pods/React-Core-prebuilt/Headers"
modulemap="$react_headers/module.modulemap"
if [ ! -f "$modulemap" ]; then
  echo 'Run pnpm pods before checking the iOS native module.' >&2
  exit 1
fi
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/icloud-sync-ios-check.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM
if ! xcrun swiftc -typecheck -sdk "$sdk_path" -target arm64-apple-ios15.1 \
  -F "$react_framework" -I "$react_headers" -I "$pods/ReactNativeDependencies/Headers" \
  -Xcc "-fmodule-map-file=$modulemap" -Xcc -DRCT_REMOVE_LEGACY_ARCH=1 \
  -Xcc -Wno-nullability-completeness -Xcc -Wno-incomplete-umbrella \
  apps/mobile/ios/ICloudSync/CloudDocuments.swift \
  apps/mobile/ios/ICloudSync/ICloudFiles.swift > "$check_dir/swift.log" 2>&1; then
  cat "$check_dir/swift.log" >&2
  exit 1
fi
if ! xcrun clang -fsyntax-only -fobjc-arc -fmodules -target arm64-apple-ios15.1 \
  -isysroot "$sdk_path" -F "$react_framework" -I "$react_headers" \
  "-fmodule-map-file=$modulemap" -DRCT_REMOVE_LEGACY_ARCH=1 \
  -Wno-nullability-completeness -Wno-incomplete-umbrella \
  apps/mobile/ios/ICloudSync/ICloudFilesBridge.m > "$check_dir/objc.log" 2>&1; then
  cat "$check_dir/objc.log" >&2
  exit 1
fi
echo 'PASS: iOS Swift module typecheck and Objective-C bridge syntax with React Native headers'
