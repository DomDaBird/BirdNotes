#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"

cd "$REPOSITORY_ROOT"

echo "[Security] Typische Zugangsdaten und private Schlüssel suchen"
SECRET_PATTERN='(AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{40,255})'
if command -v rg >/dev/null 2>&1; then
    SECRET_FOUND="$(rg -n --hidden --glob '!\.git/**' "$SECRET_PATTERN" . || true)"
else
    SECRET_FOUND="$(git grep -nE "$SECRET_PATTERN" -- . || true)"
fi

if [[ -n "$SECRET_FOUND" ]]; then
    echo "$SECRET_FOUND"
    echo "Möglicher geheimer Schlüssel im Repository gefunden."
    exit 1
fi

echo "[Security] Persönliche lokale Angaben suchen"
PRIVATE_METADATA_PATTERN='(/Users/[A-Za-z0-9._-]+/|[A-Za-z]:\\Users\\[A-Za-z0-9._-]+\\|DEVELOPMENT_TEAM = [A-Z0-9]{10};|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.(com|de|org|net|io|dev|app|edu|gov|co|me|info))'
if command -v rg >/dev/null 2>&1; then
    PRIVATE_METADATA_FOUND="$(rg -n --hidden --glob '!\.git/**' "$PRIVATE_METADATA_PATTERN" . || true)"
else
    PRIVATE_METADATA_FOUND="$(git grep -nE "$PRIVATE_METADATA_PATTERN" -- . || true)"
fi

if [[ -n "$PRIVATE_METADATA_FOUND" ]]; then
    echo "$PRIVATE_METADATA_FOUND"
    echo "Persönlicher Pfad, E-Mail-Adresse oder fest eingetragene Apple-Team-ID im Repository gefunden."
    exit 1
fi

echo "[Security] Unsichere Produktionsabkürzungen prüfen"
UNSAFE_PATTERN='try!|fatalError\('
if command -v rg >/dev/null 2>&1; then
    UNSAFE_FOUND="$(rg -n "$UNSAFE_PATTERN" BirdNotes BirdNotesCore/Sources BirdNotesTechnicalCore/Sources || true)"
else
    UNSAFE_FOUND="$(grep -REn "$UNSAFE_PATTERN" BirdNotes BirdNotesCore/Sources BirdNotesTechnicalCore/Sources || true)"
fi

if [[ -n "$UNSAFE_FOUND" ]]; then
    echo "$UNSAFE_FOUND"
    echo "Erzwungene Fehlerbehandlung im Produktionscode gefunden."
    exit 1
fi

echo "[Security] Versionierte symbolische Links prüfen"
TRACKED_SYMLINKS="$(git ls-files -s | awk '$1 == "120000" { print $4 }')"
if [[ -n "$TRACKED_SYMLINKS" ]]; then
    echo "$TRACKED_SYMLINKS"
    echo "Versionierte symbolische Links sind ohne dokumentierte Ausnahme nicht erlaubt."
    exit 1
fi

echo "BirdNotes-Security-Baseline ist erfüllt."
