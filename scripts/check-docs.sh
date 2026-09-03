#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
FAILED=0

cd "$REPOSITORY_ROOT"

echo "[Dokumentation] Lokale Markdown-Links prüfen"

while IFS= read -r document; do
    while IFS= read -r match; do
        line_number="${match%%:*}"
        link_expression="${match#*:}"
        target="${link_expression#](}"
        target="${target%)}"
        target="${target%%#*}"
        target="${target#<}"
        target="${target%>}"

        if [[ -z "$target" ]] || [[ "$target" == *"://"* ]] || [[ "$target" == mailto:* ]]; then
            continue
        fi

        decoded_target="${target//%20/ }"
        document_directory="$(cd "$(dirname "$document")" && pwd)"
        if [[ ! -e "$document_directory/$decoded_target" ]]; then
            echo "$document:$line_number: Ziel fehlt: $target"
            FAILED=1
        fi
    done < <(grep -Eno '\]\(([^)#]+)(#[^)]*)?\)' "$document" || true)
done < <(
    find . -maxdepth 1 -type f -name '*.md' -print
    find docs -type f -name '*.md' -print
)

if [[ "$FAILED" -ne 0 ]]; then
    exit 1
fi

echo "Alle lokalen Markdown-Links sind gültig."
