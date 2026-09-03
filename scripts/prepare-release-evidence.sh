#!/bin/bash

set -euo pipefail

if [[ "$#" -ne 1 ]] || [[ -z "$1" ]]; then
    echo "Verwendung: ./scripts/prepare-release-evidence.sh <Zielordner>"
    exit 2
fi

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
TEMPLATE="$REPOSITORY_ROOT/docs/evidence/RELEASE_TEST_EVIDENCE_TEMPLATE.md"
OUTPUT_DIRECTORY="$1"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
COMMIT="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
OUTPUT="$OUTPUT_DIRECTORY/BirdNotes-Release-Testnachweis-$TIMESTAMP.md"

mkdir -p "$OUTPUT_DIRECTORY"
{
    echo "<!-- erzeugt am $(date '+%Y-%m-%d %H:%M:%S %z'); Ausgangscommit $COMMIT -->"
    echo
    sed "s/^- Commit:$/- Commit: $COMMIT/" "$TEMPLATE"
} > "$OUTPUT"

echo "Release-Testnachweis erstellt: $OUTPUT"
