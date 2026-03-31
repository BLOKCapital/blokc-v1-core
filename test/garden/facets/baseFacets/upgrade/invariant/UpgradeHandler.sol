// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

// ═══════════════════════════════════════════════════════════════════════
//                 HANDLER-SPECIFIC MOCK FACETS
// ═══════════════════════════════════════════════════════════════════════

contract HandlerFacet0 {
    uint256 public state0;

    function hFunc0a() external pure returns (uint256) { return 0; }
    function hFunc0b() external pure returns (uint256) { return 0; }
}

contract HandlerFacet1 {
    uint256 public state1;

    function hFunc1a() external pure returns (uint256) { return 1; }
    function hFunc1b() external pure returns (uint256) { return 1; }
}

contract HandlerFacet0Replace {
    uint256 public state0r;

    function hFunc0a() external pure returns (uint256) { return 10; }
    function hFunc0b() external pure returns (uint256) { return 10; }
}

contract HandlerFacet1Replace {
    uint256 public state1r;

    function hFunc1a() external pure returns (uint256) { return 11; }
    function hFunc1b() external pure returns (uint256) { return 11; }
}

// ═══════════════════════════════════════════════════════════════════════
//                        UPGRADE HANDLER
// ═══════════════════════════════════════════════════════════════════════

contract UpgradeHandler is Test {
    FacetRegistry public registry;
    address public garden;
    address public gardenOwner;
    bytes32 public moduleId;

    HandlerFacet0 public facet0;
    HandlerFacet1 public facet1;
    HandlerFacet0Replace public facet0r;
    HandlerFacet1Replace public facet1r;

    bytes4[] public sels0;
    bytes4[] public sels1;

    // ── Ghost variables for tracking state
    bool public facet0Added;
    bool public facet1Added;
    bool public facet0Replaced;
    bool public facet1Replaced;
    bool public facet0Removed;
    bool public facet1Removed;
    uint256 public upgradeCount;
    uint256 public actionCount;

    constructor(
        FacetRegistry _registry,
        address _garden,
        address _gardenOwner,
        bytes32 _moduleId
    ) {
        registry = _registry;
        garden = _garden;
        gardenOwner = _gardenOwner;
        moduleId = _moduleId;

        facet0 = new HandlerFacet0();
        facet1 = new HandlerFacet1();
        facet0r = new HandlerFacet0Replace();
        facet1r = new HandlerFacet1Replace();

        sels0 = new bytes4[](2);
        sels0[0] = HandlerFacet0.hFunc0a.selector;
        sels0[1] = HandlerFacet0.hFunc0b.selector;

        sels1 = new bytes4[](2);
        sels1[0] = HandlerFacet1.hFunc1a.selector;
        sels1[1] = HandlerFacet1.hFunc1b.selector;
    }

    // ── Actions ─────────────────────────────────────────────────────

    function addFacet0() external {
        if (facet0Added || facet0Replaced) return;
        actionCount++;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet0),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sels0
        });
        registry.upgradeModule(moduleId, cuts);
        facet0Added = true;
        facet0Removed = false;
    }

    function addFacet1() external {
        if (facet1Added || facet1Replaced) return;
        actionCount++;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet1),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sels1
        });
        registry.upgradeModule(moduleId, cuts);
        facet1Added = true;
        facet1Removed = false;
    }

    function replaceFacet0() external {
        if (!facet0Added || facet0Removed) return;
        if (facet0Replaced) return; // already replaced
        actionCount++;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet0r),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: sels0
        });
        registry.upgradeModule(moduleId, cuts);
        facet0Replaced = true;
    }

    function replaceFacet1() external {
        if (!facet1Added || facet1Removed) return;
        if (facet1Replaced) return;
        actionCount++;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet1r),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: sels1
        });
        registry.upgradeModule(moduleId, cuts);
        facet1Replaced = true;
    }

    function removeFacet0() external {
        if (!facet0Added && !facet0Replaced) return;
        if (facet0Removed) return;
        actionCount++;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: sels0
        });
        registry.upgradeModule(moduleId, cuts);
        facet0Added = false;
        facet0Replaced = false;
        facet0Removed = true;
    }

    function removeFacet1() external {
        if (!facet1Added && !facet1Replaced) return;
        if (facet1Removed) return;
        actionCount++;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: sels1
        });
        registry.upgradeModule(moduleId, cuts);
        facet1Added = false;
        facet1Replaced = false;
        facet1Removed = true;
    }

    function performUpgrade() external {
        IUpgrade iUpgrade = IUpgrade(garden);

        try iUpgrade.upgradeDetails() returns (IDiamondCut.FacetCut[] memory, bytes32 hashData) {
            vm.prank(gardenOwner);
            iUpgrade.upgrade(hashData);
            upgradeCount++;
        } catch {
            // No upgrades available — that's fine
        }
    }
}
