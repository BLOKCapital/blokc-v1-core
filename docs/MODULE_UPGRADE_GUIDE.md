# Module Registry Upgrade Guide

> **Audience:** Developers adding, upgrading, or removing facets in the BLOK Capital V2 Core protocol.

---

## How Storage Works in This Protocol

Each facet stores its state in a **namespace storage slot** derived from the library name:

```solidity
bytes32 slot = keccak256(bytes(type(LibraryName).name)) & ~bytes32(uint256(0xff));
```

This means:
- **The library name IS the storage key.** If you rename a library, the slot changes, and all deployed Gardens lose access to that data permanently.
- **Each library must have a unique name.** Two libraries with the same name produce the same slot → silent storage collision.
- The low byte is masked (EIP-7201) to avoid collision with Solidity's native storage layout.

All slot derivation goes through **one single helper** — [`LibStorageSlot.deriveStorageSlot()`](src/garden/libraries/LibStorageSlot.sol). Every storage library must use it.

---

## Safety Guards (Automated)

Three Forge tests run automatically on every `forge test`:

| Guard | What it catches |
|---|---|
| `test_noStorageSlotCollisions` | Two different files using the same library name in `type(X).name` |
| `test_catchesDuplicateStorageSlotCollision` | Proves the collision detector works (using a test mock) |
| `test_deployedStorageLibrariesNotRenamed` | A library listed in `storage-registry.json` no longer exists in the codebase |

These are defined in [`FacetRegistryTestBase.sol`](test/facetRegistry/FacetRegistryTestBase.sol) and inherited by all test suites.

---

## The Storage Registry

[`storage-registry.json`](storage-registry.json) tracks every module and its deployed storage library names. Module versions are tracked **on-chain** via `FacetRegistry.getModuleVersion(moduleId)`. Example:

```json
{
  "GMX_V2": {
    "storage_libraries": ["GmxV2Storage"]
  },
  "UNISWAP_V3": {
    "storage_libraries": []
  }
}
```

- Modules with **storage** have their library names frozen — renaming them is a breaking change.
- Modules with **empty arrays** are stateless — safe to refactor freely.

### Scripts

| Script | Command | When to use |
|---|---|---|
| **Full sync** | `./scripts/sync-storage-registry.sh` | Rebuild the entire registry from the codebase |
| **Single module** | `./scripts/update-module-registry.sh MODULE_NAME dir/` | After deploying or upgrading one module |

Both scripts auto-discover `type(X).name` declarations and update the JSON.

---

## Upgrade Checklist

### Before Making Changes

- [ ] Run `forge test` — confirm all 3 storage guards pass on the current codebase

### Adding a New Facet to a Module

- [ ] If the facet needs storage, create a `*Storage.sol` library with a **unique name**
- [ ] Use `LibStorageSlot.deriveStorageSlot(type(YourStorage).name)` for slot derivation — do NOT inline the formula
- [ ] **Do NOT inherit from any contract that has its own storage variables** (diamond facets must be stateless contracts — all state goes through namespace libraries)
- [ ] Run `forge test` — `test_noStorageSlotCollisions` will catch any name conflicts

### Removing a Facet from a Module

- [ ] **Do NOT delete or rename the storage library** — its slot may still hold data in deployed Gardens
- [ ] Remove the facet from the module's `FacetCut[]` via `upgradeModule()`
- [ ] The storage library file can remain in the codebase as dead code (safe) or be archived

### Renaming a Storage Library (DANGER)

> **Never rename a deployed storage library.** It changes the slot and destroys all data in that namespace across every deployed Garden.

If a rename is truly necessary:
1. Deploy a **migration facet** that reads from the old slot and writes to the new slot
2. Execute the migration on every deployed Garden
3. Only then update the registry

### Adding a New Module

- [ ] Create facets in the appropriate directory under `src/garden/facets/`
- [ ] If the module has storage, create `*Storage.sol` libraries using `LibStorageSlot`
- [ ] Add the module's directory to the `MODULE_DIRS` mapping in `scripts/sync-storage-registry.sh`
- [ ] Register the module via `FacetRegistry.registerModule(moduleId)`
- [ ] After deployment, run: `./scripts/update-module-registry.sh MODULE_NAME path/to/dir/`
- [ ] Commit the updated `storage-registry.json`

### Modifying a Storage Struct Layout

- [ ] **Only append new fields** at the end of the struct — never reorder, remove, or change types of existing fields
- [ ] This is not enforced by automated tests — rely on code review

### Deploying / Upgrading

```bash
# 1. Run all guards
forge test

# 2. Deploy via your deployment script
forge script ...

# 3. Update the registry for any changed modules
./scripts/update-module-registry.sh MODULE_NAME path/to/module/dir/

# 4. Commit the updated registry
git add storage-registry.json
git commit -m "chore: update storage registry after MODULE_NAME upgrade"
```

---

## Quick Reference: Rules

| Rule | Enforced by |
|---|---|
| Unique library names | `test_noStorageSlotCollisions` (auto) |
| No renames of deployed libs | `test_deployedStorageLibrariesNotRenamed` (auto) |
| Use `LibStorageSlot.deriveStorageSlot()` | Code review |
| No stateful inheritance in facets | Code review |
| Append-only struct fields | Code review |
| Update `storage-registry.json` after deploy | `update-module-registry.sh` / `sync-storage-registry.sh` |

---

## File Map

```
storage-registry.json                          ← Offchain registry of existing library names
src/garden/libraries/LibStorageSlot.sol         ← Centralised slot derivation helper
src/garden/libraries/LibDiamond.sol             ← Diamond core storage
src/garden/facets/baseFacets/*/                 ← Base module storage libraries
src/garden/facets/indexFacets/IndexStorage.sol  ← Index module storage
src/garden/facets/utilityFacets/*/              ← Utility module storage libraries
test/facetRegistry/FacetRegistryTestBase.sol    ← All 3 test guards live here
test/check_storage_slot_collisions.sh           ← FFI script: collision detection
test/check_storage_registry.sh                  ← FFI script: rename detection
scripts/sync-storage-registry.sh                ← Full registry rebuild
scripts/update-module-registry.sh               ← Per-module registry update
```
