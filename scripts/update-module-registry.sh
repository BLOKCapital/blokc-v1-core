#!/usr/bin/env bash
# update-module-registry.sh
# Auto-discovers storage libraries in the given directories and upserts
# the module entry in storage-registry.json.
#
# Usage:
#   ./scripts/update-module-registry.sh <MODULE_NAME> <DIR1> [DIR2] ...
#
# Examples:
#   ./scripts/update-module-registry.sh GMX_V2 src/garden/facets/utilityFacets/arbitrumOne/gmxV2/
#   ./scripts/update-module-registry.sh BASE src/garden/facets/baseFacets/ src/garden/libraries/
#   ./scripts/update-module-registry.sh UNISWAP_V3 src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/
#
# The script:
#   1. Scans the given directories for type(X).name declarations (stripping comments)
#   2. Extracts unique library names
#   3. Upserts the module entry in the registry

set -euo pipefail

REGISTRY="storage-registry.json"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <MODULE_NAME> <DIR1> [DIR2] ..."
    echo "Example: $0 GMX_V2 src/garden/facets/utilityFacets/arbitrumOne/gmxV2/"
    exit 1
fi

MODULE_NAME="$1"
shift
SEARCH_DIRS="$@"

if [ ! -f "$REGISTRY" ]; then
    echo "ERROR: $REGISTRY not found. Run scripts/sync-storage-registry.sh first."
    exit 1
fi

# Discover storage libraries using python3 (strips // and /* */ comments)
LIBS=$(python3 -c "
import re, glob, os

dirs = '$SEARCH_DIRS'.split()
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
")

# Update the registry using python3 heredoc
python3 << PYEOF
import json

module_name = "${MODULE_NAME}"
libs = "${LIBS}".split() if "${LIBS}".strip() else []

with open("${REGISTRY}", "r") as f:
    data = json.load(f)

data["modules"][module_name] = {
    "storage_libraries": sorted(libs)
}

with open("${REGISTRY}", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"Updated {module_name}")
if libs:
    sep = ", "
    print(f"  Storage libraries: {sep.join(sorted(libs))}")
else:
    print("  Stateless module (no storage libraries)")
PYEOF
