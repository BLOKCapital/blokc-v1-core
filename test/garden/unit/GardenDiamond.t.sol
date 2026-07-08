// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase, StubFacetA } from "../../base/DiamondTestBase.sol";
import { Garden } from "src/garden/Garden.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

contract GardenDiamondTest is DiamondTestBase {
    // ═════════════════════════════════════════════════════════════════
    //                     CONSTRUCTOR — SUCCESS
    // ═════════════════════════════════════════════════════════════════

    function test_constructor_deploysSuccessfully() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        assertTrue(garden != address(0));
        assertTrue(garden.code.length > 0);
    }

    function test_constructor_acceptsETH() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        IDiamondCut.FacetCut[] memory baseCuts = registry.getBaseFacetCuts();
        Garden garden = new Garden{ value: 1 ether }(
            baseCuts, gardenOwner, address(registry), address(protocolStatus), GARDEN_TYPE_1
        );
        assertEq(address(garden).balance, 1 ether);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     CONSTRUCTOR — REVERTS
    // ═════════════════════════════════════════════════════════════════

    function test_constructor_revertsOnZeroOwner() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        IDiamondCut.FacetCut[] memory baseCuts = registry.getBaseFacetCuts();
        vm.expectRevert(abi.encodeWithSignature("Garden_ContractOwnerIsZero()"));
        new Garden(baseCuts, address(0), address(registry), address(protocolStatus), GARDEN_TYPE_1);
    }

    function test_constructor_revertsOnZeroFacetRegistry() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        IDiamondCut.FacetCut[] memory baseCuts = registry.getBaseFacetCuts();
        vm.expectRevert(abi.encodeWithSignature("Garden_FacetRegistryNotSet()"));
        new Garden(baseCuts, gardenOwner, address(0), address(protocolStatus), GARDEN_TYPE_1);
    }

    function test_constructor_revertsOnZeroProtocolStatus() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        IDiamondCut.FacetCut[] memory baseCuts = registry.getBaseFacetCuts();
        vm.expectRevert(abi.encodeWithSignature("Garden_ProtocolStatusNotSet()"));
        new Garden(baseCuts, gardenOwner, address(registry), address(0), GARDEN_TYPE_1);
    }

    function test_constructor_revertsOnUnregisteredGardenType() public {
        IDiamondCut.FacetCut[] memory baseCuts = registry.getBaseFacetCuts();
        vm.expectRevert(abi.encodeWithSignature("Garden_GardenTypeNotRegistered()"));
        new Garden(baseCuts, gardenOwner, address(registry), address(protocolStatus), keccak256("UNREGISTERED"));
    }

    // ═════════════════════════════════════════════════════════════════
    //                     FALLBACK — PROTOCOL STATUS CHECKS
    // ═════════════════════════════════════════════════════════════════

    function test_fallback_revertsWhenProtocolInactive() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        protocolStatus.setStatus(IProtocolStatus.State.INACTIVE);

        // Any call to the garden should revert
        vm.expectRevert(abi.encodeWithSignature("Garden_ProtocolIsInactive()"));
        IUpgrade(garden).upgradeDetails();
    }

    function test_fallback_blocksUpgradeWhenUpgradesDisabled() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        protocolStatus.setStatus(IProtocolStatus.State.UPGRADES_DISABLED);

        // upgrade() specifically should revert
        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSignature("Garden_UpgradesDisabled()"));
        IUpgrade(garden).upgrade(bytes32(0));
    }

    function test_fallback_allowsNonUpgradeCallsWhenUpgradesDisabled() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        protocolStatus.setStatus(IProtocolStatus.State.UPGRADES_DISABLED);

        // owner() is not upgrade(), should still work
        address o = IERC173(garden).owner();
        assertEq(o, gardenOwner);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     FALLBACK — INVALID SELECTOR
    // ═════════════════════════════════════════════════════════════════

    function test_fallback_revertsOnUnknownSelector() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        bytes memory callData = abi.encodeWithSelector(bytes4(0xDEADBEEF));
        (bool success,) = garden.call(callData);
        assertFalse(success);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     FALLBACK — SELECTOR NOT IN GARDEN
    // ═════════════════════════════════════════════════════════════════

    function test_fallback_revertsForRegisteredButNotInstalledSelector() public {
        // Register a module with a selector in the registry
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(stubA), selsStubA);

        // Create garden type WITH the module, deploy garden, but DON'T upgrade
        _addGardenType(GARDEN_TYPE_1, _singleModule(MODULE_1));
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        // Call stubA1 — it's in the registry but not yet installed in the garden
        bytes memory callData = abi.encodeWithSelector(StubFacetA.stubA1.selector);
        (bool success,) = garden.call(callData);
        assertFalse(success);
    }

    function test_fallback_succeedsAfterUpgradeInstallsSelector() public {
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(stubA), selsStubA);
        _addGardenType(GARDEN_TYPE_1, _singleModule(MODULE_1));
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        // Upgrade to install MODULE_1
        _performUpgrade(garden, gardenOwner);

        // Now the call should succeed
        (bool success, bytes memory ret) = garden.call(abi.encodeWithSelector(StubFacetA.stubA1.selector));
        assertTrue(success);
        assertEq(abi.decode(ret, (uint256)), 1);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     RECEIVE — ETH
    // ═════════════════════════════════════════════════════════════════

    function test_receive_revertsOnPlainETHTransfer() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        vm.expectRevert(bytes("Garden: ETH not accepted"));
        garden.call{ value: 1 ether }("");
    }
}
