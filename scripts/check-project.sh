#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"

cd "$REPOSITORY_ROOT"

echo "[Projekt] Property Lists und Projektdatei prüfen"
plutil -lint \
    BirdNotes/App/Info.plist \
    BirdNotes/App/PrivacyInfo.xcprivacy \
    BirdNotesCore/Sources/BirdNotesCore/PrivacyInfo.xcprivacy \
    BirdNotes.xcodeproj/project.pbxproj

if ! /usr/libexec/PlistBuddy -c 'Print :UILaunchScreen' \
    BirdNotes/App/Info.plist >/dev/null 2>&1; then
    echo "Der verpflichtende Launch-Screen-Eintrag fehlt in BirdNotes/App/Info.plist."
    exit 1
fi

echo "[Projekt] Private Laufzeitkonfiguration prüfen"
USES_NONEXEMPT_ENCRYPTION="$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' BirdNotes/App/Info.plist)"

if [[ "$USES_NONEXEMPT_ENCRYPTION" != "false" ]]; then
    echo "Die Export-Compliance-Angabe ist inkonsistent."
    exit 1
fi

if command -v rg >/dev/null 2>&1; then
    LEGACY_PURCHASE_CODE="$(rg -l 'import StoreKit|PurchaseManager|LifetimePurchaseView|BirdNotesCommercialMode|BirdNotes\.storekit' \
        BirdNotes BirdNotes.xcodeproj || true)"
else
    LEGACY_PURCHASE_CODE="$(grep -ERl 'import StoreKit|PurchaseManager|LifetimePurchaseView|BirdNotesCommercialMode|BirdNotes\.storekit' \
        BirdNotes BirdNotes.xcodeproj || true)"
fi
if [[ -n "$LEGACY_PURCHASE_CODE" ]]; then
    echo "Die App enthält noch nicht vorgesehene Kauf- oder Freischaltlogik."
    exit 1
fi

echo "[Projekt] App-Identität und Archive-Konfiguration prüfen"
if command -v rg >/dev/null 2>&1; then
    APP_IDENTITY_VALID="$(rg -l 'PRODUCT_BUNDLE_IDENTIFIER = com\.dominikvogel\.BirdNotes;' \
        BirdNotes.xcodeproj/project.pbxproj || true)"
    BUILD_NUMBER_VALID="$(rg -l 'CURRENT_PROJECT_VERSION = [1-9][0-9]*;' \
        BirdNotes.xcodeproj/project.pbxproj || true)"
else
    APP_IDENTITY_VALID="$(grep -El 'PRODUCT_BUNDLE_IDENTIFIER = com\.dominikvogel\.BirdNotes;' \
        BirdNotes.xcodeproj/project.pbxproj || true)"
    BUILD_NUMBER_VALID="$(grep -El 'CURRENT_PROJECT_VERSION = [1-9][0-9]*;' \
        BirdNotes.xcodeproj/project.pbxproj || true)"
fi
RELEASE_ARCHIVE_VALID="$(awk '
    /<ArchiveAction/ { in_archive = 1 }
    in_archive && /buildConfiguration = "Release"/ { print FILENAME; exit }
    in_archive && /<\/ArchiveAction>/ { in_archive = 0 }
' BirdNotes.xcodeproj/xcshareddata/xcschemes/BirdNotes.xcscheme)"

if [[ -z "$APP_IDENTITY_VALID" ]] || [[ -z "$BUILD_NUMBER_VALID" ]] || \
   [[ -z "$RELEASE_ARCHIVE_VALID" ]] || \
   [[ ! -f BirdNotes/Assets.xcassets/AppIcon.appiconset/AppIcon.png ]]; then
    echo "Bundle-ID, Buildnummer, Release-Archive-Aktion oder App-Icon ist für die iPad-Auslieferung unvollständig."
    exit 1
fi

echo "[Projekt] Shell-Skripte syntaktisch prüfen"
while IFS= read -r script; do
    bash -n "$script"
done < <(find scripts -type f -name '*.sh' -print | sort)

./scripts/check-docs.sh

echo "BirdNotes-Projektkonfiguration ist konsistent."
