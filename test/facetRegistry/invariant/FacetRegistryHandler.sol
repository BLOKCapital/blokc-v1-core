// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { Test } from "forge-std/Test.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

/// @dev Minimal mock that always deploys with some code
contract HandlerMockFacet {
    uint256 private _x;
    function setX(uint256 x) external { _x = x; }
}

/// @title Handler for FacetRegistry invariant testing
/// @dev Exposes bounded actions the fuzzer can call
contract FacetRegistryHandler is Test {
    FacetRegistry public registry;

    // Tracking state for invariant assertions
    bytes32[] public registeredModules;
    bytes32[] public registeredGardenTypes;
    address[] public addedFacets;
    bytes4[] public addedSelectors;
    uint256 public actionCount;

    // Module tracking
    mapping(bytes32 => bool) public moduleExists;

    // Garden type tracking
    mapping(bytes32 => bool) public gardenTypeExists;
    mapping(bytes32 => bytes32[]) public gardenTypeModules;
    mapping(bytes32 => mapping(bytes32 => bool)) public gardenTypeModuleAllowed;

    // Facet tracking
    mapping(address => bytes32) public facetModule;
    mapping(address => bytes4[]) public facetSelectors;
    mapping(bytes4 => address) public selectorFacet;

    uint256 private _moduleNonce;
    uint256 private _gardenTypeNonce;
    uint256 private _facetNonce;

    bytes32 public constant BASE_MODULE = keccak256("BASE");

    constructor(FacetRegistry _registry) {
        registry = _registry;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         HANDLER ACTIONS
    // ═══════════════════════════════════════════════════════════════════════

    function registerModule(uint256 seed) external {
        bytes32 moduleId = keccak256(abi.encodePacked("handler_module", _moduleNonce++));

        registry.registerModule(moduleId);

        registeredModules.push(moduleId);
        moduleExists[moduleId] = true;
        actionCount++;
    }

    function addFacetToModule(uint256 moduleIndex, uint256 numSelectors) external {
        if (registeredModules.length == 0) return;

        moduleIndex = bound(moduleIndex, 0, registeredModules.length - 1);
        numSelectors = bound(numSelectors, 1, 3);
        bytes32 moduleId = registeredModules[moduleIndex];

        HandlerMockFacet mock = new HandlerMockFacet();
        address facetAddr = address(mock);

        bytes4[] memory sels = new bytes4[](numSelectors);
        for (uint256 i = 0; i < numSelectors; i++) {
            sels[i] = bytes4(keccak256(abi.encodePacked("handler_sel", _facetNonce++)));
        }

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facetAddr,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sels
        });

        registry.upgradeModule(moduleId, cuts);

        addedFacets.push(facetAddr);
        facetModule[facetAddr] = moduleId;
        for (uint256 i = 0; i < numSelectors; i++) {
            addedSelectors.push(sels[i]);
            facetSelectors[facetAddr].push(sels[i]);
            selectorFacet[sels[i]] = facetAddr;
        }
        actionCount++;
    }

    function removeFacetFromModule(uint256 facetIndex) external {
        if (addedFacets.length == 0) return;

        facetIndex = bound(facetIndex, 0, addedFacets.length - 1);
        address facetAddr = addedFacets[facetIndex];

        // Skip if already removed
        if (facetSelectors[facetAddr].length == 0) return;

        bytes32 moduleId = facetModule[facetAddr];

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: facetSelectors[facetAddr]
        });

        registry.upgradeModule(moduleId, cuts);

        // Clear selector tracking
        bytes4[] memory sels = facetSelectors[facetAddr];
        for (uint256 i = 0; i < sels.length; i++) {
            delete selectorFacet[sels[i]];
        }
        delete facetSelectors[facetAddr];
        delete facetModule[facetAddr];
        actionCount++;
    }

    function addGardenType(uint256 numModules) external {
        bytes32 gardenTypeId = keccak256(abi.encodePacked("handler_gt", _gardenTypeNonce++));

        numModules = bound(numModules, 0, registeredModules.length);

        bytes32[] memory modules = new bytes32[](numModules);
        for (uint256 i = 0; i < numModules; i++) {
            modules[i] = registeredModules[i];
        }

        registry.addGardenType(gardenTypeId, modules);

        registeredGardenTypes.push(gardenTypeId);
        gardenTypeExists[gardenTypeId] = true;
        for (uint256 i = 0; i < numModules; i++) {
            gardenTypeModules[gardenTypeId].push(modules[i]);
            gardenTypeModuleAllowed[gardenTypeId][modules[i]] = true;
        }
        actionCount++;
    }

    function addAllowedModule(uint256 gardenTypeIndex, uint256 moduleIndex) external {
        if (registeredGardenTypes.length == 0 || registeredModules.length == 0) return;

        gardenTypeIndex = bound(gardenTypeIndex, 0, registeredGardenTypes.length - 1);
        bytes32 gardenTypeId = registeredGardenTypes[gardenTypeIndex];

        // Find a module that isn't already allowed
        bool found;
        bytes32 moduleId;
        for (uint256 i = 0; i < registeredModules.length; i++) {
            uint256 idx = (moduleIndex + i) % registeredModules.length;
            if (!gardenTypeModuleAllowed[gardenTypeId][registeredModules[idx]]) {
                moduleId = registeredModules[idx];
                found = true;
                break;
            }
        }
        if (!found) return;

        registry.addAllowedModule(gardenTypeId, moduleId);
        gardenTypeModules[gardenTypeId].push(moduleId);
        gardenTypeModuleAllowed[gardenTypeId][moduleId] = true;
        actionCount++;
    }

    function removeAllowedModule(uint256 gardenTypeIndex, uint256 moduleIndex) external {
        if (registeredGardenTypes.length == 0) return;

        gardenTypeIndex = bound(gardenTypeIndex, 0, registeredGardenTypes.length - 1);
        bytes32 gardenTypeId = registeredGardenTypes[gardenTypeIndex];

        bytes32[] storage modules = gardenTypeModules[gardenTypeId];
        if (modules.length == 0) return;

        moduleIndex = bound(moduleIndex, 0, modules.length - 1);
        bytes32 moduleId = modules[moduleIndex];

        registry.removeAllowedModule(gardenTypeId, moduleId);

        // Swap and pop in our tracking
        modules[moduleIndex] = modules[modules.length - 1];
        modules.pop();
        gardenTypeModuleAllowed[gardenTypeId][moduleId] = false;
        actionCount++;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          GHOST GETTERS
    // ═══════════════════════════════════════════════════════════════════════

    function getRegisteredModulesCount() external view returns (uint256) {
        return registeredModules.length;
    }

    function getRegisteredGardenTypesCount() external view returns (uint256) {
        return registeredGardenTypes.length;
    }

    function getAddedFacetsCount() external view returns (uint256) {
        return addedFacets.length;
    }

    function getAddedSelectorsCount() external view returns (uint256) {
        return addedSelectors.length;
    }
}
