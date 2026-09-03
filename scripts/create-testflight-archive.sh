#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Verwendung: ./scripts/create-testflight-archive.sh <Zielordner>"
    exit 2
fi

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
DESTINATION_DIRECTORY="$1"

cd "$REPOSITORY_ROOT"
./scripts/check-project.sh

BUILD_SETTINGS="$(xcodebuild \
    -project BirdNotes.xcodeproj \
    -scheme BirdNotes \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -showBuildSettings)"
APP_VERSION="$(awk '$1 == "MARKETING_VERSION" && $2 == "=" { print $3; exit }' <<< "$BUILD_SETTINGS")"
BUILD_NUMBER="$(awk '$1 == "CURRENT_PROJECT_VERSION" && $2 == "=" { print $3; exit }' <<< "$BUILD_SETTINGS")"

if [[ -z "$APP_VERSION" ]] || [[ -z "$BUILD_NUMBER" ]]; then
    echo "Version oder Buildnummer konnte nicht aus der Release-Konfiguration gelesen werden."
    exit 1
fi

mkdir -p "$DESTINATION_DIRECTORY"
ARCHIVE_PATH="$DESTINATION_DIRECTORY/BirdNotes-${APP_VERSION}-${BUILD_NUMBER}.xcarchive"
if [[ -e "$ARCHIVE_PATH" ]]; then
    echo "Das Zielarchiv existiert bereits: $ARCHIVE_PATH"
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Hinweis: Das Arbeitsverzeichnis enthält nicht versionierte Änderungen."
fi

echo "Erstelle signiertes TestFlight-Archiv: $ARCHIVE_PATH"
xcodebuild \
    -project BirdNotes.xcodeproj \
    -scheme BirdNotes \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    archive

echo "Archiv erfolgreich erstellt: $ARCHIVE_PATH"
if command -v open >/dev/null 2>&1; then
    # Archive außerhalb von ~/Library/Developer/Xcode/Archives werden im
    # Organizer nicht automatisch gelistet. Direktes Öffnen registriert das
    # erzeugte Archiv bei Xcode und zeigt es unmittelbar im Organizer an.
    if open -a Xcode "$ARCHIVE_PATH"; then
        echo "Das Archiv wurde in Xcode geöffnet. Wähle Validate App und anschließend Distribute App > TestFlight & App Store."
        exit 0
    fi
fi

echo "Öffne die .xcarchive-Datei im Finder per Doppelklick und wähle anschließend Validate App sowie Distribute App > TestFlight & App Store."
