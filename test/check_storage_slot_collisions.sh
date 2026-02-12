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

set -euo pipefail

# Use provided directories or default to src/
SEARCH_DIRS="${@:-src/}"

# For each .sol file containing a type(X).name pattern:
#   1. Strip comment lines (// and * prefixed lines)
#   2. Extract ALL identifiers from type(X).name declarations
#   3. Deduplicate within the same file (a file may use the same name twice)
#   4. Output one "name:file" pair per unique name per file
# Then find any name appearing across multiple files.
for f in $(grep -rl 'type([A-Za-z0-9_]*)\.name' $SEARCH_DIRS --include='*.sol' 2>/dev/null); do
    grep -v '^\s*//' "$f" | grep -v '^\s*\*' | grep -oP 'type\(\K[A-Za-z0-9_]+(?=\)\.name)' | sort -u | while read -r name; do
        echo "$name"
    done
done | sort | uniq -d
