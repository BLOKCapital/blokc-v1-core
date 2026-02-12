#!/usr/bin/env bash
# sync-storage-registry.sh
# Full auto-sync: scans the entire codebase and rebuilds storage-registry.json
# from scratch by discovering all type(X).name declarations.
#
# Module-to-directory mapping is defined below. Update the MODULES array
# when adding new modules to the protocol.
#
# Usage:
#   ./scripts/sync-storage-registry.sh

set -euo pipefail

REGISTRY="storage-registry.json"

# ═══════════════════════════════════════════════════════════════════════
#  MODULE → DIRECTORY MAPPING
#  Update this when adding new modules to the protocol.
# ═══════════════════════════════════════════════════════════════════════

declare -A MODULE_DIRS=(
    ["BASE"]="src/garden/facets/baseFacets/ src/garden/libraries/"
    ["INDEX"]="src/garden/facets/indexFacets/"
    ["GMX_V2"]="src/garden/facets/utilityFacets/arbitrumOne/gmxV2/"
    ["REWARD_COLLECTION"]="src/garden/facets/utilityFacets/arbitrumOne/rewardCollection/"
    ["AAVE_V3"]="src/garden/facets/utilityFacets/arbitrumOne/aaveV3/"
    ["UNISWAP_V2"]="src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/"
    ["UNISWAP_V3"]="src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/"
    ["CAMELOT_V2"]="src/garden/facets/utilityFacets/arbitrumOne/camelotV2/"
    ["CAMELOT_V3"]="src/garden/facets/utilityFacets/arbitrumOne/camelotV3/"
    ["PENDLE_V2"]="src/garden/facets/utilityFacets/arbitrumOne/pendleV2/"
    ["CCTP"]="src/garden/facets/utilityFacets/arbitrumOne/cctp/"
    ["WITHDRAW"]="src/garden/facets/utilityFacets/arbitrumOne/withdraw/"
)

# ═══════════════════════════════════════════════════════════════════════

# Function to discover storage libraries in given directories
# Uses python3 to strip both // and /* */ comments before extracting type(X).name
discover_libs() {
    local dirs="$1"
    python3 -c "
import re, glob, os

dirs = '$dirs'.split()
names = set()
for d in dirs:
    for f in glob.glob(os.path.join(d, '**', '*.sol'), recursive=True):
        if os.path.basename(f) == 'LibStorageSlot.sol':
            continue
        with open(f) as fh:
            code = fh.read()
        code = re.sub(r'/\*.*?\*/', '', code, flags=re.DOTALL)
        code = re.sub(r'//.*', '', code)
        for m in re.finditer(r'type\((\w+)\)\.name', code):
            names.add(m.group(1))
print(' '.join(sorted(names)))
"
}

# Build the new registry
echo "Syncing storage-registry.json..."
echo ""

MODULES_JSON="{"
FIRST=true

for module_name in $(echo "${!MODULE_DIRS[@]}" | tr ' ' '\n' | sort); do
    dirs="${MODULE_DIRS[$module_name]}"
    libs=$(discover_libs "$dirs")

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        MODULES_JSON="$MODULES_JSON,"
    fi

    # Build JSON for this module using python3
    MODULE_JSON=$(python3 -c "
import json
libs = '$libs'.split() if '$libs'.strip() else []
entry = {
    'storage_libraries': sorted(libs)
}
print(json.dumps(entry))
")

    MODULES_JSON="$MODULES_JSON \"$module_name\": $MODULE_JSON"

    if [ -n "$libs" ]; then
        echo "  $module_name: $libs"
    else
        echo "  $module_name: stateless"
    fi
done

MODULES_JSON="$MODULES_JSON }"

# Write the full registry
python3 -c "
import json

modules = json.loads('''$MODULES_JSON''')

registry = {
    'description': 'Registry of deployed storage library names per module. Used to guard against library renames that would silently destroy storage slot offsets in deployed Gardens. Modules with empty storage_libraries arrays contain only stateless facets. Module versions are tracked on-chain via FacetRegistry.getModuleVersion(moduleId).',
    'modules': dict(sorted(modules.items()))
}

with open('$REGISTRY', 'w') as f:
    json.dump(registry, f, indent=2)
    f.write('\n')

print()
print(f'Wrote {len(modules)} modules to $REGISTRY')
"
