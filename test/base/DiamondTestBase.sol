// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { BaseTest } from "./BaseTest.sol";

// ── Core contracts
// ───────────────────────────────────────────────────────
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { Garden } from "src/garden/Garden.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

// ── Base facets
// ──────────────────────────────────────────────────────────
import { DiamondCutFacet } from "src/garden/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/garden/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/garden/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";

// ── Interfaces
// ───────────────────────────────────────────────────────────
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

// ── Mocks
// ────────────────────────────────────────────────────────────────
import { MockProtocolStatus } from "../mock/MockProtocolStatus.sol";

// ═══════════════════════════════════════════════════════════════════════
//                       STUB MODULE FACETS
// ═══════════════════════════════════════════════════════════════════════
// Minimal contracts whose selectors can be registered in modules for
// upgrade / garden-type tests without importing real protocol facets.

contract StubFacetA {
    function stubA1() external pure returns (uint256) {
        return 1;
    }

    function stubA2() external pure returns (uint256) {
        return 2;
    }
}

contract StubFacetB {
    function stubB1() external pure returns (uint256) {
        return 1;
    }

    function stubB2() external pure returns (uint256) {
        return 2;
    }
}

contract StubFacetC {
    function stubC1() external pure returns (uint256) {
        return 1;
    }

    function stubC2() external pure returns (uint256) {
        return 2;
    }
}

contract StubFacetD {
    function stubD1() external pure returns (uint256) {
        return 1;
    }

    function stubD2() external pure returns (uint256) {
        return 2;
    }
}

/// @dev Replacement for StubFacetA (same selectors, different address)
contract StubFacetA2 {
    function stubA1() external pure returns (uint256) {
        return 10;
    }

    function stubA2() external pure returns (uint256) {
        return 20;
    }
}

/// @dev Replacement for StubFacetB (same selectors, different address)
contract StubFacetB2 {
    function stubB1() external pure returns (uint256) {
        return 10;
    }

    function stubB2() external pure returns (uint256) {
        return 20;
    }
}

// ═══════════════════════════════════════════════════════════════════════
//                     DIAMOND TEST BASE CONTRACT
// ═══════════════════════════════════════════════════════════════════════

/// @title DiamondTestBase
/// @author BLOK Capital DAO
/// @notice Deploys a fully-functional Diamond environment:
///         - Real base facets (DiamondCut, Loupe, Ownership, Upgrade)
///         - FacetRegistry with base facets registered
///         - MockProtocolStatus (starts ACTIVE)
///         - Stub module facets for upgrade / garden-type tests
///
///         Provides helpers to:
///         - Deploy gardens from the registry
///         - Register modules and garden types
///         - Perform upgrades
///         - Deploy GardenFactory
abstract contract DiamondTestBase is BaseTest {
    // ── Core contracts
    // ───────────────────────────────────────────────
    FacetRegistry public registry;
    MockProtocolStatus public protocolStatus;

    // ── Base facet instances (real)
    // ──────────────────────────────────
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    UpgradeFacet public upgradeFacet;

    // ── Stub module facets
    // ──────────────────────────────────────────
    StubFacetA public stubA;
    StubFacetB public stubB;
    StubFacetC public stubC;
    StubFacetD public stubD;
    StubFacetA2 public stubA2;
    StubFacetB2 public stubB2;

    // ── Base facet selector arrays
    // ──────────────────────────────────
    bytes4[] public selsCut;
    bytes4[] public selsLoupe;
    bytes4[] public selsOwnership;
    bytes4[] public selsUpgrade;

    // ── Stub facet selector arrays
    // ──────────────────────────────────
    bytes4[] public selsStubA;
    bytes4[] public selsStubB;
    bytes4[] public selsStubC;
    bytes4[] public selsStubD;

    // ═══════════════════════════════════════════════════════════════════
    //                           SETUP
    // ═══════════════════════════════════════════════════════════════════

    function setUp() public virtual override {
        super.setUp();

        // ── Deploy base facets
        // ───────────────────────────────────────
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        upgradeFacet = new UpgradeFacet();

        // ── Deploy stub module facets
        // ────────────────────────────────
        stubA = new StubFacetA();
        stubB = new StubFacetB();
        stubC = new StubFacetC();
        stubD = new StubFacetD();
        stubA2 = new StubFacetA2();
        stubB2 = new StubFacetB2();

        // ── Build base facet selector arrays
        // ─────────────────────────
        selsCut = _singleSelector(IDiamondCut.diamondCut.selector);

        selsLoupe = new bytes4[](5);
        selsLoupe[0] = IDiamondLoupe.facets.selector;
        selsLoupe[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selsLoupe[2] = IDiamondLoupe.facetAddresses.selector;
        selsLoupe[3] = IDiamondLoupe.facetAddress.selector;
        selsLoupe[4] = IERC165.supportsInterface.selector;

        selsOwnership = _twoSelectors(IERC173.transferOwnership.selector, IERC173.owner.selector);

        selsUpgrade = new bytes4[](3);
        selsUpgrade[0] = IUpgrade.upgrade.selector;
        selsUpgrade[1] = IUpgrade.upgradeDetails.selector;
        selsUpgrade[2] = IUpgrade.getModuleVersion.selector;

        // ── Build stub selector arrays
        // ───────────────────────────────
        selsStubA = _twoSelectors(StubFacetA.stubA1.selector, StubFacetA.stubA2.selector);
        selsStubB = _twoSelectors(StubFacetB.stubB1.selector, StubFacetB.stubB2.selector);
        selsStubC = _twoSelectors(StubFacetC.stubC1.selector, StubFacetC.stubC2.selector);
        selsStubD = _twoSelectors(StubFacetD.stubD1.selector, StubFacetD.stubD2.selector);

        // ── Deploy FacetRegistry with real base facets ────────────────
        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];
        bytes4[][] memory baseFacetSelectors = new bytes4[][](4);
        baseFacetSelectors[0] = selsCut;
        baseFacetSelectors[1] = selsLoupe;
        baseFacetSelectors[2] = selsOwnership;
        baseFacetSelectors[3] = selsUpgrade;

        registry = new FacetRegistry(address(this), baseFacets, baseFacetSelectors);

        // ── Deploy mock protocol status (ACTIVE) ─────────────────────
        protocolStatus = new MockProtocolStatus();
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     REGISTRY HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Register a new module in the FacetRegistry
    function _registerModule(bytes32 moduleId) internal {
        registry.registerModule(moduleId);
    }

    /// @notice Add a facet to a module via upgradeModule (Add action)
    function _addFacetToModule(bytes32 moduleId, address facet, bytes4[] memory sels) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: sels
        });
        registry.upgradeModule(moduleId, cuts);
    }

    /// @notice Replace a facet in a module via upgradeModule (Replace action)
    function _replaceFacetInModule(bytes32 moduleId, address newFacet, bytes4[] memory sels) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: newFacet, action: IDiamondCut.FacetCutAction.Replace, functionSelectors: sels
        });
        registry.upgradeModule(moduleId, cuts);
    }

    /// @notice Remove selectors from a module via upgradeModule (Remove action)
    function _removeFacetFromModule(bytes32 moduleId, bytes4[] memory sels) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: sels
        });
        registry.upgradeModule(moduleId, cuts);
    }

    /// @notice Add a garden type with allowed modules
    function _addGardenType(bytes32 gardenTypeId, bytes32[] memory modules) internal {
        registry.addGardenType(gardenTypeId, modules);
    }

    /// @notice Add a garden type with no extra modules (just BASE)
    function _addGardenTypeEmpty(bytes32 gardenTypeId) internal {
        registry.addGardenType(gardenTypeId, _noModules());
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     GARDEN HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Deploy a Garden diamond via constructor (bypasses factory)
    function _deployGarden(bytes32 gardenType, address gardenOwner_) internal returns (address) {
        IDiamondCut.FacetCut[] memory baseCuts = registry.getBaseFacetCuts();
        Garden garden = new Garden(baseCuts, gardenOwner_, address(registry), address(protocolStatus), gardenType);
        return address(garden);
    }

    /// @notice Deploy a GardenFactory pointing at registry + protocolStatus
    function _deployFactory(address factoryOwner) internal returns (GardenFactory) {
        return new GardenFactory(factoryOwner, address(registry), address(protocolStatus));
    }

    /// @notice Get IUpgrade interface for a garden address
    function _upgradeOf(address garden) internal pure returns (IUpgrade) {
        return IUpgrade(garden);
    }

    /// @notice Query upgradeDetails and execute upgrade as owner
    function _performUpgrade(address garden, address gardenOwner_) internal {
        IUpgrade iUpgrade = _upgradeOf(garden);
        (, bytes32 hashData) = iUpgrade.upgradeDetails();
        vm.prank(gardenOwner_);
        iUpgrade.upgrade(hashData);
    }

    /// @notice Register MODULE_1 with stubA, create GARDEN_TYPE_1 with [MODULE_1], deploy garden
    function _setupSingleModuleGarden() internal returns (address garden) {
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(stubA), selsStubA);

        _addGardenType(GARDEN_TYPE_1, _singleModule(MODULE_1));

        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
    }

    /// @notice Register MODULE_1 + MODULE_2, create GARDEN_TYPE_1, deploy garden
    function _setupDualModuleGarden() internal returns (address garden) {
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        _addFacetToModule(MODULE_1, address(stubA), selsStubA);
        _addFacetToModule(MODULE_2, address(stubB), selsStubB);

        _addGardenType(GARDEN_TYPE_1, _twoModules(MODULE_1, MODULE_2));

        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
    }
}
