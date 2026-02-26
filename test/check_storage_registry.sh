#!/usr/bin/env bash
# check_storage_registry.sh
# Validates that every library name in storage-registry.json still exists
# as a type(X).name declaration in the codebase.
#
# If a library was renamed, its old name will no longer appear in any
# type(X).name call, and this script outputs the missing names.
#
# Usage:
#   ./test/check_storage_registry.sh
#
# Output: comma-separated library names from the registry that are missing
#         from the codebase. Should be empty if no libraries were renamed.

set -euo pipefail

REGISTRY="storage-registry.json"

if [ ! -f "$REGISTRY" ]; then
    echo "ERROR:storage-registry.json not found"
    exit 1
fi

# Extract all storage library names from the JSON using python3
REGISTERED_NAMES=$(python3 -c "
import json
with open('$REGISTRY') as f:
    data = json.load(f)
for module in data['modules'].values():
    for lib in module['storage_libraries']:
        print(lib)
" | sort -u)

# For each registered name, check if type(Name).name exists in src/
MISSING=""
for name in $REGISTERED_NAMES; do
    FOUND=$(grep -rl "type($name)" src/ --include='*.sol' 2>/dev/null | head -1 || true)
    if [ -z "$FOUND" ]; then
        if [ -n "$MISSING" ]; then
            MISSING="$MISSING,$name"
        else
            MISSING="$name"
        fi
    fi
done

if [ -n "$MISSING" ]; then
    echo "$MISSING"
fi
