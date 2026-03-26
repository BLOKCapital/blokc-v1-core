// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

// Core contracts
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { Garden } from "src/garden/Garden.sol";

// Base facets
import { DiamondCutFacet } from "src/garden/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/garden/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/garden/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";

// Interfaces
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

// ═══════════════════════════════════════════════════════════════════════
//                       MOCK PROTOCOL STATUS
// ═══════════════════════════════════════════════════════════════════════

contract MockProtocolStatus {
    IProtocolStatus.State private _status;

    constructor() {
        _status = IProtocolStatus.State.ACTIVE;
    }

    function getProtocolStatus() external view returns (IProtocolStatus.State) {
        return _status;
    }

    function setStatus(IProtocolStatus.State newStatus) external {
        _status = newStatus;
    }
}

// ═══════════════════════════════════════════════════════════════════════
//                          MODULE MOCK FACETS
// ═══════════════════════════════════════════════════════════════════════

contract ModuleFacetA {
    function modFuncA1() external pure returns (uint256) { return 1; }
    function modFuncA2() external pure returns (uint256) { return 2; }
}

contract ModuleFacetB {
    function modFuncB1() external pure returns (uint256) { return 1; }
    function modFuncB2() external pure returns (uint256) { return 2; }
}

contract ModuleFacetC {
    function modFuncC1() external pure returns (uint256) { return 1; }
    function modFuncC2() external pure returns (uint256) { return 2; }
}

contract ModuleFacetD {
    function modFuncD1() external pure returns (uint256) { return 1; }
    function modFuncD2() external pure returns (uint256) { return 2; }
}

/// @dev Replacement facet for A — same selectors, different address
contract ModuleFacetA2 {
    function modFuncA1() external pure returns (uint256) { return 10; }
    function modFuncA2() external pure returns (uint256) { return 20; }
}

/// @dev Replacement facet for B — same selectors, different address
contract ModuleFacetB2 {
    function modFuncB1() external pure returns (uint256) { return 10; }
    function modFuncB2() external pure returns (uint256) { return 20; }
}

/// @dev Extra facets for fuzz / complex tests
contract ModuleFacetE {
    function modFuncE1() external pure returns (uint256) { return 1; }
}

contract ModuleFacetF {
    function modFuncF1() external pure returns (uint256) { return 1; }
}

// ═══════════════════════════════════════════════════════════════════════
//                         BASE TEST CONTRACT
// ═══════════════════════════════════════════════════════════════════════

abstract contract UpgradeTestBase is Test {
    // ── Core contracts
    FacetRegistry public registry;
    MockProtocolStatus public protocolStatus;

    // ── Base facet instances (real contracts)
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    UpgradeFacet public upgradeFacet;

    // ── Module facet instances
    ModuleFacetA public modFacetA;
    ModuleFacetB public modFacetB;
    ModuleFacetC public modFacetC;
    ModuleFacetD public modFacetD;
    ModuleFacetA2 public modFacetA2;
    ModuleFacetB2 public modFacetB2;
    ModuleFacetE public modFacetE;
    ModuleFacetF public modFacetF;

    // ── Base facet selectors
    bytes4[] public selsCut;
    bytes4[] public selsLoupe;
    bytes4[] public selsOwnership;
    bytes4[] public selsUpgrade;

    // ── Module facet selectors
    bytes4[] public selsModA;
    bytes4[] public selsModB;
    bytes4[] public selsModC;
    bytes4[] public selsModD;
    bytes4[] public selsModE;
    bytes4[] public selsModF;

    // ── Constants
    bytes32 public constant BASE_MODULE = keccak256("BASE");
    bytes32 public constant MODULE_1 = keccak256("MODULE_1");
    bytes32 public constant MODULE_2 = keccak256("MODULE_2");
    bytes32 public constant MODULE_3 = keccak256("MODULE_3");
    bytes32 public constant GARDEN_TYPE_1 = keccak256("GARDEN_TYPE_1");
    bytes32 public constant GARDEN_TYPE_2 = keccak256("GARDEN_TYPE_2");

    // ── Addresses
    address public gardenOwner = address(0xABCD);
    address public nonOwner = address(0xBEEF);

    function setUp() public virtual {
        // Deploy base facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        upgradeFacet = new UpgradeFacet();

        // Deploy module facets
        modFacetA = new ModuleFacetA();
        modFacetB = new ModuleFacetB();
        modFacetC = new ModuleFacetC();
        modFacetD = new ModuleFacetD();
        modFacetA2 = new ModuleFacetA2();
        modFacetB2 = new ModuleFacetB2();
        modFacetE = new ModuleFacetE();
        modFacetF = new ModuleFacetF();

        // Build base facet selector arrays
        selsCut = new bytes4[](1);
        selsCut[0] = IDiamondCut.diamondCut.selector;

        selsLoupe = new bytes4[](5);
        selsLoupe[0] = IDiamondLoupe.facets.selector;
        selsLoupe[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selsLoupe[2] = IDiamondLoupe.facetAddresses.selector;
        selsLoupe[3] = IDiamondLoupe.facetAddress.selector;
        selsLoupe[4] = IERC165.supportsInterface.selector;

        selsOwnership = new bytes4[](2);
        selsOwnership[0] = IERC173.transferOwnership.selector;
        selsOwnership[1] = IERC173.owner.selector;

        selsUpgrade = new bytes4[](3);
        selsUpgrade[0] = IUpgrade.upgrade.selector;
        selsUpgrade[1] = IUpgrade.upgradeDetails.selector;
        selsUpgrade[2] = IUpgrade.getModuleVersion.selector;

        // Build module facet selector arrays
        selsModA = new bytes4[](2);
        selsModA[0] = ModuleFacetA.modFuncA1.selector;
        selsModA[1] = ModuleFacetA.modFuncA2.selector;

        selsModB = new bytes4[](2);
        selsModB[0] = ModuleFacetB.modFuncB1.selector;
        selsModB[1] = ModuleFacetB.modFuncB2.selector;

        selsModC = new bytes4[](2);
        selsModC[0] = ModuleFacetC.modFuncC1.selector;
        selsModC[1] = ModuleFacetC.modFuncC2.selector;

        selsModD = new bytes4[](2);
        selsModD[0] = ModuleFacetD.modFuncD1.selector;
        selsModD[1] = ModuleFacetD.modFuncD2.selector;

        selsModE = new bytes4[](1);
        selsModE[0] = ModuleFacetE.modFuncE1.selector;

        selsModF = new bytes4[](1);
        selsModF[0] = ModuleFacetF.modFuncF1.selector;

        // Deploy FacetRegistry with real base facets
        address[4] memory baseFacets = [
            address(diamondCutFacet),
            address(diamondLoupeFacet),
            address(ownershipFacet),
            address(upgradeFacet)
        ];
        bytes4[][] memory baseFacetSelectors = new bytes4[][](4);
        baseFacetSelectors[0] = selsCut;
        baseFacetSelectors[1] = selsLoupe;
        baseFacetSelectors[2] = selsOwnership;
        baseFacetSelectors[3] = selsUpgrade;

        registry = new FacetRegistry(address(this), baseFacets, baseFacetSelectors);

        // Deploy mock protocol status
        protocolStatus = new MockProtocolStatus();
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        REGISTRY HELPERS
    // ═══════════════════════════════════════════════════════════════════

    function _registerModule(bytes32 moduleId) internal {
        registry.registerModule(moduleId);
    }

    function _addFacetToModule(bytes32 moduleId, address facet, bytes4[] memory sels) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sels
        });
        registry.upgradeModule(moduleId, cuts);
    }

    function _replaceFacetInModule(bytes32 moduleId, address newFacet, bytes4[] memory sels) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: newFacet,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: sels
        });
        registry.upgradeModule(moduleId, cuts);
    }

    function _removeFacetFromModule(bytes32 moduleId, bytes4[] memory sels) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: sels
        });
        registry.upgradeModule(moduleId, cuts);
    }

    function _addGardenType(bytes32 gardenTypeId, bytes32[] memory modules) internal {
        registry.addGardenType(gardenTypeId, modules);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        GARDEN HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Deploys a Garden diamond and returns the address
    function _deployGarden(bytes32 gardenType, address owner_) internal returns (address) {
        IDiamondCut.FacetCut[] memory baseCuts = registry.getBaseFacetCuts();
        Garden garden = new Garden(baseCuts, owner_, address(registry), address(protocolStatus), gardenType);
        return address(garden);
    }

    /// @notice Returns IUpgrade interface bound to a garden address
    function _upgradeOf(address garden) internal pure returns (IUpgrade) {
        return IUpgrade(garden);
    }

    /// @notice Performs upgrade on a garden: queries details then executes upgrade as the owner
    function _performUpgrade(address garden, address owner_) internal {
        IUpgrade iUpgrade = _upgradeOf(garden);
        (, bytes32 hashData) = iUpgrade.upgradeDetails();
        vm.prank(owner_);
        iUpgrade.upgrade(hashData);
    }

    /// @notice Sets up MODULE_1 with modFacetA, creates GARDEN_TYPE_1 with [MODULE_1], deploys garden
    function _setupSingleModuleGarden() internal returns (address garden) {
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
    }

    /// @notice Sets up MODULE_1 + MODULE_2, creates GARDEN_TYPE_1, deploys garden
    function _setupDualModuleGarden() internal returns (address garden) {
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);
        _addFacetToModule(MODULE_2, address(modFacetB), selsModB);

        bytes32[] memory modules = new bytes32[](2);
        modules[0] = MODULE_1;
        modules[1] = MODULE_2;
        _addGardenType(GARDEN_TYPE_1, modules);

        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
    }
}
