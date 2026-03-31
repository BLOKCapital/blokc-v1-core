// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { GardenFactoryTestBase } from "../GardenFactoryTestBase.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

contract GardenFactoryConstructorTest is GardenFactoryTestBase {
    // ═══════════════════════════════════════════════════════════════════
    //                     SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════════

    function test_constructor_setsFacetRegistry() public view {
        assertEq(factory.getFacetRegistry(), address(registry));
    }

    function test_constructor_setsProtocolStatus() public view {
        assertEq(factory.getProtocolStatus(), address(protocolStatus));
    }

    function test_constructor_setsOwner() public view {
        assertEq(factory.owner(), owner);
    }

    function test_constructor_startsWithZeroGardens() public view {
        assertEq(factory.getTotalGardens(), 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     REVERT CASES
    // ═══════════════════════════════════════════════════════════════════

    function test_constructor_revertsWhenFacetRegistryIsZero() public {
        vm.expectRevert(abi.encodeWithSignature("GardenFactory_FacetRegistryNotSet()"));
        new GardenFactory(owner, address(0), address(protocolStatus));
    }

    function test_constructor_revertsWhenProtocolStatusIsZero() public {
        vm.expectRevert(abi.encodeWithSignature("GardenFactory_ProtocolStatusNotSet()"));
        new GardenFactory(owner, address(registry), address(0));
    }

    function test_constructor_revertsWhenInitialOwnerIsZero() public {
        // OZ Ownable reverts with OwnableInvalidOwner(address(0))
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableInvalidOwner(address)")), address(0)));
        new GardenFactory(address(0), address(registry), address(protocolStatus));
    }
}
