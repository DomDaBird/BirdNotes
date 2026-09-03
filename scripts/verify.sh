#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
TEMPORARY_BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/birdnotes-verify.XXXXXX")"

cleanup() {
    rm -rf "$TEMPORARY_BUILD_ROOT"
}
trap cleanup EXIT

cd "$REPOSITORY_ROOT"

./scripts/check-project.sh
./scripts/check-security.sh
./scripts/test.sh all

echo "[Build] Generischen iOS-Release-Gerätebuild erstellen"
xcodebuild \
    -project BirdNotes.xcodeproj \
    -scheme BirdNotes \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$TEMPORARY_BUILD_ROOT/derived-data" \
    CODE_SIGNING_ALLOWED=NO \
    build

echo "[Analyse] Statische Xcode-Release-Analyse ausführen"
xcodebuild \
    -project BirdNotes.xcodeproj \
    -scheme BirdNotes \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$TEMPORARY_BUILD_ROOT/derived-data" \
    CODE_SIGNING_ALLOWED=NO \
    analyze

echo "BirdNotes-Qualitätsprüfung erfolgreich."
