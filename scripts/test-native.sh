#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/icloud-sync-native-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
xcrun swiftc \
  "$repo_root/apps/mobile/ios/ICloudSync/CloudDocuments.swift" \
  "$repo_root/apps/mobile/ios/tests/CloudDocumentsTests.swift" \
  -o "$test_dir/cloud-documents-tests"
"$test_dir/cloud-documents-tests"
