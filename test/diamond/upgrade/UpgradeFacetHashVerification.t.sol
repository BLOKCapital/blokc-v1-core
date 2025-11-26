// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

contract UpgradeFacetHashVerificationTest is DiamondTestBase {
    bytes4 internal constant HASH_MISMATCH_SELECTOR = bytes4(keccak256("UpgradeFacet_HashMismatch()"));

    function _prepareUpgrade()
        internal
        view
        returns (IDiamondCut.FacetCut[] memory cuts, uint256 diamondVersion, uint256 registryVersion, bytes32 hashData)
    {
        return getDiamondUpgrade().upgradeDetails();
    }

    function _addFacetToRegistry(address facet, bytes4 selector) internal {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;

        vm.prank(owner);
        facetRegistry.addFunctions(facet, selectors);
    }

    function test_Upgrade_RevertsOnHashMismatch() public {
        MockUpgradeFacet facet = new MockUpgradeFacet();
        _addFacetToRegistry(address(facet), facet.ping.selector);

        (IDiamondCut.FacetCut[] memory cuts, uint256 diamondVersion, uint256 registryVersion, bytes32 hashData) =
            _prepareUpgrade();

        assertGt(cuts.length, 0);
        assertEq(diamondVersion, getDiamondUpgrade().getCurrentVersion());
        assertEq(registryVersion, facetRegistry.getCurrentVersion());

        bytes32 wrongHash = bytes32(uint256(hashData) ^ uint256(1));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(HASH_MISMATCH_SELECTOR));
        getDiamondUpgrade().upgrade(wrongHash);
    }

    function test_UpgradeDetails_ReturnsConsistentHash() public {
        MockUpgradeFacet facet = new MockUpgradeFacet();
        _addFacetToRegistry(address(facet), facet.ping.selector);

        (IDiamondCut.FacetCut[] memory cuts, uint256 diamondVersion, uint256 registryVersion, bytes32 hashData) =
            _prepareUpgrade();

        assertEq(diamondVersion, getDiamondUpgrade().getCurrentVersion());
        assertEq(registryVersion, facetRegistry.getCurrentVersion());
        assertTrue(hashData != bytes32(0));

        bytes32 computedHash = keccak256(abi.encode(cuts, diamondVersion, registryVersion));
        assertEq(hashData, computedHash);
    }

    function test_Upgrade_SucceedsWithCorrectHash() public {
        MockUpgradeFacet facet = new MockUpgradeFacet();
        _addFacetToRegistry(address(facet), facet.ping.selector);

        (IDiamondCut.FacetCut[] memory cuts, uint256 diamondVersion, uint256 registryVersion, bytes32 hashData) =
            _prepareUpgrade();

        bytes32 computedHash = keccak256(abi.encode(cuts, diamondVersion, registryVersion));
        assertEq(hashData, computedHash);

        vm.prank(owner);
        getDiamondUpgrade().upgrade(hashData);

        assertEq(getDiamondUpgrade().getCurrentVersion(), registryVersion);
        assertEq(getDiamondLoupe().facetAddress(facet.ping.selector), address(facet));
    }

    function test_Upgrade_RevertsWhenPlanStale() public {
        MockUpgradeFacet facet = new MockUpgradeFacet();
        _addFacetToRegistry(address(facet), facet.ping.selector);

        (,,, bytes32 hashData) = _prepareUpgrade();

        // Modify registry before executing upgrade
        MockUpgradeFacet secondFacet = new MockUpgradeFacet();
        _addFacetToRegistry(address(secondFacet), secondFacet.ping.selector);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(HASH_MISMATCH_SELECTOR));
        getDiamondUpgrade().upgrade(hashData);
    }
}

contract MockUpgradeFacet {
    function ping() external pure returns (uint256) {
        return 1;
    }
}
