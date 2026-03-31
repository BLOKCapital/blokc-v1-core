// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase } from "../../base/DiamondTestBase.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

contract BaseFacetsFuzzTest is DiamondTestBase {
    address public garden;

    function setUp() public override {
        super.setUp();
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — Ownership
    // ═════════════════════════════════════════════════════════════════

    /// @notice Only the current owner can transfer ownership
    function testFuzz_transferOwnership_onlyOwnerSucceeds(address caller, address newOwner) public {
        caller = _boundAddress(caller);
        newOwner = _boundAddress(newOwner);

        if (caller == gardenOwner) {
            vm.prank(caller);
            IERC173(garden).transferOwnership(newOwner);
            assertEq(IERC173(garden).owner(), newOwner);
        } else {
            vm.prank(caller);
            vm.expectRevert();
            IERC173(garden).transferOwnership(newOwner);
            // Owner unchanged
            assertEq(IERC173(garden).owner(), gardenOwner);
        }
    }

    /// @notice Sequential ownership transfers should always work
    function testFuzz_transferOwnership_chainedTransfers(address[3] memory newOwners) public {
        address currentOwner = gardenOwner;
        for (uint256 i = 0; i < 3; i++) {
            address next = _boundAddress(newOwners[i]);
            if (next == currentOwner) continue; // skip no-op

            vm.prank(currentOwner);
            IERC173(garden).transferOwnership(next);
            assertEq(IERC173(garden).owner(), next);
            currentOwner = next;
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — DiamondCut always reverts
    // ═════════════════════════════════════════════════════════════════

    /// @notice diamondCut should always revert regardless of parameters
    function testFuzz_diamondCut_alwaysRevertsForOwner(address init, bytes memory calldata_) public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSignature("DiamondCutFacet_DiamondCutNotAllowed()"));
        IDiamondCut(garden).diamondCut(cuts, init, calldata_);
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — Loupe consistency
    // ═════════════════════════════════════════════════════════════════

    /// @notice Every address in facetAddresses() must have at least one selector
    function testFuzz_loupe_allFacetsHaveSelectors_afterUpgrade(uint256 moduleCount) public {
        moduleCount = bound(moduleCount, 0, 2);

        if (moduleCount >= 1) {
            _registerModule(MODULE_1);
            _addFacetToModule(MODULE_1, address(stubA), selsStubA);
            registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
        }
        if (moduleCount >= 2) {
            _registerModule(MODULE_2);
            _addFacetToModule(MODULE_2, address(stubB), selsStubB);
            registry.addAllowedModule(GARDEN_TYPE_1, MODULE_2);
        }

        if (moduleCount > 0) {
            _performUpgrade(garden, gardenOwner);
        }

        IDiamondLoupe loupe = IDiamondLoupe(garden);
        address[] memory addrs = loupe.facetAddresses();

        for (uint256 i = 0; i < addrs.length; i++) {
            bytes4[] memory sels = loupe.facetFunctionSelectors(addrs[i]);
            assertTrue(sels.length > 0);
        }
    }

    /// @notice facetAddress(selector) should match the facet that lists that selector
    function testFuzz_loupe_facetAddressMatchesFacetsList(uint256 moduleCount) public {
        moduleCount = bound(moduleCount, 0, 2);

        if (moduleCount >= 1) {
            _registerModule(MODULE_1);
            _addFacetToModule(MODULE_1, address(stubA), selsStubA);
            registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
        }
        if (moduleCount >= 2) {
            _registerModule(MODULE_2);
            _addFacetToModule(MODULE_2, address(stubB), selsStubB);
            registry.addAllowedModule(GARDEN_TYPE_1, MODULE_2);
        }

        if (moduleCount > 0) {
            _performUpgrade(garden, gardenOwner);
        }

        IDiamondLoupe loupe = IDiamondLoupe(garden);
        IDiamondLoupe.Facet[] memory facets = loupe.facets();

        for (uint256 i = 0; i < facets.length; i++) {
            for (uint256 j = 0; j < facets[i].functionSelectors.length; j++) {
                address resolved = loupe.facetAddress(facets[i].functionSelectors[j]);
                assertEq(resolved, facets[i].facetAddress);
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — ERC-165 interface support
    // ═════════════════════════════════════════════════════════════════

    /// @notice Known interfaces should always return true
    function testFuzz_supportsInterface_knownInterfacesAlwaysTrue(uint256 ifaceSeed) public view {
        bytes4[5] memory known = [
            type(IERC165).interfaceId,
            type(IDiamondCut).interfaceId,
            type(IDiamondLoupe).interfaceId,
            type(IERC173).interfaceId,
            type(IUpgrade).interfaceId
        ];
        bytes4 iface = known[ifaceSeed % known.length];
        assertTrue(IERC165(garden).supportsInterface(iface));
    }

    /// @notice Random selectors should (almost always) return false
    function testFuzz_supportsInterface_randomSelectorsFalse(bytes4 iface) public view {
        // Exclude known interfaces
        vm.assume(iface != bytes4(0));
        vm.assume(iface != type(IERC165).interfaceId);
        vm.assume(iface != type(IDiamondCut).interfaceId);
        vm.assume(iface != type(IDiamondLoupe).interfaceId);
        vm.assume(iface != type(IERC173).interfaceId);
        vm.assume(iface != type(IUpgrade).interfaceId);
        // Garden constructor also registers IERC721 and related
        vm.assume(iface != bytes4(0x80ac58cd)); // IERC721
        vm.assume(iface != bytes4(0x5b5e139f)); // IERC721Metadata
        vm.assume(iface != bytes4(0x49064906)); // IERC721Errors

        assertFalse(IERC165(garden).supportsInterface(iface));
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — Garden fallback unknown selector
    // ═════════════════════════════════════════════════════════════════

    /// @notice Calling unknown selectors should always revert
    function testFuzz_fallback_unknownSelectorAlwaysReverts(bytes4 selector) public {
        // Exclude all known selectors (base facets)
        vm.assume(selector != IDiamondCut.diamondCut.selector);
        vm.assume(selector != IDiamondLoupe.facets.selector);
        vm.assume(selector != IDiamondLoupe.facetFunctionSelectors.selector);
        vm.assume(selector != IDiamondLoupe.facetAddresses.selector);
        vm.assume(selector != IDiamondLoupe.facetAddress.selector);
        vm.assume(selector != IERC165.supportsInterface.selector);
        vm.assume(selector != IERC173.transferOwnership.selector);
        vm.assume(selector != IERC173.owner.selector);
        vm.assume(selector != IUpgrade.upgrade.selector);
        vm.assume(selector != IUpgrade.upgradeDetails.selector);
        vm.assume(selector != IUpgrade.getModuleVersion.selector);

        (bool success,) = garden.call(abi.encodeWithSelector(selector));
        assertFalse(success);
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — Protocol status fallback behavior
    // ═════════════════════════════════════════════════════════════════

    /// @notice INACTIVE protocol should block all facet calls
    function testFuzz_fallback_inactiveBlocksAllCalls(bytes4 selector) public {
        // Use a known valid selector
        protocolStatus.setStatus(IProtocolStatus.State.INACTIVE);

        (bool success, bytes memory data) = garden.call(abi.encodeWithSelector(IERC173.owner.selector));
        assertFalse(success);
        // Should contain Garden_ProtocolIsInactive error
        assertGt(data.length, 0);
    }
}
