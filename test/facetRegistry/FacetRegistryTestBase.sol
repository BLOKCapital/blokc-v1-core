// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { Test } from "forge-std/Test.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

// ═══════════════════════════════════════════════════════════════════════
//                          MOCK FACETS
// ═══════════════════════════════════════════════════════════════════════

contract MockFacetA {
    function funcA1() external pure returns (uint256) { return 1; }
    function funcA2() external pure returns (uint256) { return 2; }
}

contract MockFacetB {
    function funcB1() external pure returns (uint256) { return 1; }
    function funcB2() external pure returns (uint256) { return 2; }
}

contract MockFacetC {
    function funcC1() external pure returns (uint256) { return 1; }
    function funcC2() external pure returns (uint256) { return 2; }
}

contract MockFacetD {
    function funcD1() external pure returns (uint256) { return 1; }
    function funcD2() external pure returns (uint256) { return 2; }
}

contract MockFacetE {
    function funcE1() external pure returns (uint256) { return 1; }
    function funcE2() external pure returns (uint256) { return 2; }
}

contract MockFacetF {
    function funcF1() external pure returns (uint256) { return 1; }
    function funcF2() external pure returns (uint256) { return 2; }
}

contract MockFacetG {
    function funcG1() external pure returns (uint256) { return 1; }
}

contract MockFacetH {
    function funcH1() external pure returns (uint256) { return 1; }
}

// ═══════════════════════════════════════════════════════════════════════
//                         BASE TEST CONTRACT
// ═══════════════════════════════════════════════════════════════════════

abstract contract FacetRegistryTestBase is Test {
    FacetRegistry public registry;

    address public owner = address(this);
    address public nonOwner = address(0xBEEF);

    // Base facet instances
    MockFacetA public facetA;
    MockFacetB public facetB;
    MockFacetC public facetC;
    MockFacetD public facetD;

    // Extra facets for module upgrades
    MockFacetE public facetE;
    MockFacetF public facetF;
    MockFacetG public facetG;
    MockFacetH public facetH;

    // Selectors
    bytes4[] public selectorsA;
    bytes4[] public selectorsB;
    bytes4[] public selectorsC;
    bytes4[] public selectorsD;
    bytes4[] public selectorsE;
    bytes4[] public selectorsF;
    bytes4[] public selectorsG;
    bytes4[] public selectorsH;

    // Module IDs
    bytes32 public constant BASE_MODULE = keccak256("BASE");
    bytes32 public constant MODULE_1 = keccak256("MODULE_1");
    bytes32 public constant MODULE_2 = keccak256("MODULE_2");
    bytes32 public constant MODULE_3 = keccak256("MODULE_3");

    // Garden type IDs
    bytes32 public constant GARDEN_TYPE_1 = keccak256("GARDEN_TYPE_1");
    bytes32 public constant GARDEN_TYPE_2 = keccak256("GARDEN_TYPE_2");

    function setUp() public virtual {
        // Deploy mock facets
        facetA = new MockFacetA();
        facetB = new MockFacetB();
        facetC = new MockFacetC();
        facetD = new MockFacetD();
        facetE = new MockFacetE();
        facetF = new MockFacetF();
        facetG = new MockFacetG();
        facetH = new MockFacetH();

        // Build selector arrays
        selectorsA = new bytes4[](2);
        selectorsA[0] = MockFacetA.funcA1.selector;
        selectorsA[1] = MockFacetA.funcA2.selector;

        selectorsB = new bytes4[](2);
        selectorsB[0] = MockFacetB.funcB1.selector;
        selectorsB[1] = MockFacetB.funcB2.selector;

        selectorsC = new bytes4[](2);
        selectorsC[0] = MockFacetC.funcC1.selector;
        selectorsC[1] = MockFacetC.funcC2.selector;

        selectorsD = new bytes4[](2);
        selectorsD[0] = MockFacetD.funcD1.selector;
        selectorsD[1] = MockFacetD.funcD2.selector;

        selectorsE = new bytes4[](2);
        selectorsE[0] = MockFacetE.funcE1.selector;
        selectorsE[1] = MockFacetE.funcE2.selector;

        selectorsF = new bytes4[](2);
        selectorsF[0] = MockFacetF.funcF1.selector;
        selectorsF[1] = MockFacetF.funcF2.selector;

        selectorsG = new bytes4[](1);
        selectorsG[0] = MockFacetG.funcG1.selector;

        selectorsH = new bytes4[](1);
        selectorsH[0] = MockFacetH.funcH1.selector;

        // Deploy registry with 4 base facets
        registry = _deployRegistry(owner);
    }

    function _deployRegistry(address _owner) internal returns (FacetRegistry) {
        address[4] memory baseFacets =
            [address(facetA), address(facetB), address(facetC), address(facetD)];

        bytes4[][] memory baseFacetSelectors = new bytes4[][](4);
        baseFacetSelectors[0] = selectorsA;
        baseFacetSelectors[1] = selectorsB;
        baseFacetSelectors[2] = selectorsC;
        baseFacetSelectors[3] = selectorsD;

        return new FacetRegistry(_owner, baseFacets, baseFacetSelectors);
    }

    // ── Helpers ──────────────────────────────────────────────────────────

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

    function _addGardenTypeEmpty(bytes32 gardenTypeId) internal {
        bytes32[] memory empty = new bytes32[](0);
        registry.addGardenType(gardenTypeId, empty);
    }
}
