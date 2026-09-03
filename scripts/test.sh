#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
TEST_MODE="${1:-all}"
TEMPORARY_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/birdnotes-tests.XXXXXX")"
RESOLVED_TEST_DESTINATION="${BIRDNOTES_TEST_DESTINATION:-}"

cleanup() {
    rm -rf "$TEMPORARY_TEST_ROOT"
}
trap cleanup EXIT

cd "$REPOSITORY_ROOT"

run_core_tests() {
    echo "[Tests] BirdNotesCore Unit-, Integrations-, Security- und Migrationstests"
    CLANG_MODULE_CACHE_PATH="$TEMPORARY_TEST_ROOT/clang-cache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$TEMPORARY_TEST_ROOT/swiftpm-cache" \
    swift test \
        --package-path BirdNotesCore \
        --scratch-path "$TEMPORARY_TEST_ROOT/swift-build" \
        --enable-code-coverage

    echo "[Tests] BirdNotesTechnicalCore Einheiten-, Parser-, Diagramm-, Format- und Securitytests"
    CLANG_MODULE_CACHE_PATH="$TEMPORARY_TEST_ROOT/technical-clang-cache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$TEMPORARY_TEST_ROOT/technical-swiftpm-cache" \
    swift test \
        --package-path BirdNotesTechnicalCore \
        --scratch-path "$TEMPORARY_TEST_ROOT/technical-swift-build" \
        --enable-code-coverage
}

resolve_simulator_destination() {
    if [[ -n "$RESOLVED_TEST_DESTINATION" ]]; then
        return
    fi

    local destinations
    local simulator_id
    destinations="$(xcodebuild \
        -project BirdNotes.xcodeproj \
        -scheme BirdNotes \
        -showdestinations 2>/dev/null)"
    simulator_id="$(echo "$destinations" \
        | awk '/platform:iOS Simulator/ && /name:iPad/ && !/unavailable/ && !/placeholder/ {
            line = $0
            sub(/^.*id:/, "", line)
            sub(/,.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            print line
            exit
        }')"

    if [[ -z "$simulator_id" ]]; then
        simulator_id="$(echo "$destinations" \
            | awk '/platform:iOS Simulator/ && !/unavailable/ && !/placeholder/ {
                line = $0
                sub(/^.*id:/, "", line)
                sub(/,.*/, "", line)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                print line
                exit
            }')"
    fi

    if [[ -z "$simulator_id" ]]; then
        echo "Kein verfügbarer iOS-Simulator gefunden." >&2
        echo "Installiere in Xcode ein iOS-Simulator-Runtime oder setze BIRDNOTES_TEST_DESTINATION." >&2
        return 1
    fi

    RESOLVED_TEST_DESTINATION="platform=iOS Simulator,id=$simulator_id"
}

run_app_tests() {
    local destination
    resolve_simulator_destination
    destination="$RESOLVED_TEST_DESTINATION"
    echo "[Tests] App-nahe ZIP-, Layout- und Regressionstests auf $destination"
    xcodebuild \
        -project BirdNotes.xcodeproj \
        -scheme BirdNotes \
        -configuration Debug \
        -destination "$destination" \
        -derivedDataPath "$TEMPORARY_TEST_ROOT/derived-data" \
        CODE_SIGNING_ALLOWED=NO \
        test \
        -only-testing:BirdNotesTests
}

run_ui_tests() {
    local destination
    resolve_simulator_destination
    destination="$RESOLVED_TEST_DESTINATION"
    echo "[Tests] Isolierter UI-Smoke-Test auf $destination"
    xcodebuild \
        -project BirdNotes.xcodeproj \
        -scheme BirdNotes \
        -configuration Debug \
        -destination "$destination" \
        -derivedDataPath "$TEMPORARY_TEST_ROOT/derived-data" \
        CODE_SIGNING_ALLOWED=NO \
        test \
        -only-testing:BirdNotesUITests
}

run_address_sanitizer_tests() {
    local destination
    resolve_simulator_destination
    destination="$RESOLVED_TEST_DESTINATION"
    echo "[Tests] App-Tests mit Address Sanitizer auf $destination"
    xcodebuild \
        -project BirdNotes.xcodeproj \
        -scheme BirdNotes \
        -configuration Debug \
        -destination "$destination" \
        -derivedDataPath "$TEMPORARY_TEST_ROOT/derived-data-asan" \
        -enableAddressSanitizer YES \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        test \
        -only-testing:BirdNotesTests
}

run_thread_sanitizer_tests() {
    local destination
    resolve_simulator_destination
    destination="$RESOLVED_TEST_DESTINATION"
    echo "[Tests] App-Tests mit Thread Sanitizer auf $destination"
    xcodebuild \
        -project BirdNotes.xcodeproj \
        -scheme BirdNotes \
        -configuration Debug \
        -destination "$destination" \
        -derivedDataPath "$TEMPORARY_TEST_ROOT/derived-data-tsan" \
        -enableThreadSanitizer YES \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        test \
        -only-testing:BirdNotesTests
}

case "$TEST_MODE" in
    core)
        run_core_tests
        ;;
    app)
        run_app_tests
        ;;
    ui)
        run_ui_tests
        ;;
    asan)
        run_address_sanitizer_tests
        ;;
    tsan)
        run_thread_sanitizer_tests
        ;;
    sanitizers)
        run_address_sanitizer_tests
        run_thread_sanitizer_tests
        ;;
    all)
        run_core_tests
        run_app_tests
        run_ui_tests
        ;;
    *)
        echo "Verwendung: ./scripts/test.sh [core|app|ui|asan|tsan|sanitizers|all]"
        exit 2
        ;;
esac

echo "BirdNotes-Teststufe '$TEST_MODE' erfolgreich."
