#!/usr/bin/env bash
# check_storage_slot_collisions.sh
# Detects if any two files use the same identifier in a type(X).name
# declaration, which would produce identical storage slots.
#
# Usage:
#   ./check_storage_slot_collisions.sh [dir1] [dir2] ...
#   Defaults to searching src/ if no arguments are provided.
#
# Output: names that appear in more than one file (should be empty).
# Portable: works with BSD grep (macOS) and GNU grep (Linux).

set -euo pipefail

# Use provided directories or default to src/
SEARCH_DIRS="${@:-src/}"

# Collect .sol files that contain type(X).name (portable: find + grep, no --include)
get_sol_files() {
    for d in $SEARCH_DIRS; do
        find "$d" -name '*.sol' 2>/dev/null || true
    done | sort -u
}

# For each .sol file containing a type(X).name pattern:
#   1. Strip comment lines (// and * prefixed lines)
#   2. Extract ALL identifiers from type(X).name declarations (portable: -oE + sed, no -P)
#   3. Deduplicate within the same file
# Then find any name appearing across multiple files.
while IFS= read -r f; do
    grep -q 'type([A-Za-z0-9_]*)\.name' "$f" 2>/dev/null || continue
    (grep -v '^[[:space:]]*//' "$f" | grep -v '^[[:space:]]*\*' \
        | grep -oE 'type\([A-Za-z0-9_]+\)\.name' || true) \
        | sed 's/type(//;s/)\.name//' \
        | sort -u
done < <(get_sol_files) | sort | uniq -d
