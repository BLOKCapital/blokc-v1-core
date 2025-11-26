// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { DiamondCutFacet } from "src/diamond/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/diamond/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Tests for FacetRegistry initialization
contract FacetRegistryInitTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // INITIALIZATION TESTS
    // =============================================================

    /// @notice Test proper initialization of the registry
    function test_InitializeSuccessfully() public view {
        assertEq(registry.owner(), owner);
        assertEq(registry.getCurrentVersion(), 0);

        address[4] memory baseFacets = registry.getBaseFacets();
        assertEq(baseFacets[0], address(diamondCutFacet));
        assertEq(baseFacets[1], address(diamondLoupeFacet));
        assertEq(baseFacets[2], address(ownershipFacet));
        assertEq(baseFacets[3], address(upgradeFacet));

        // Verify all base facets are registered
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        assertEq(facets.length, 4);

        // Verify selectors are correctly registered
        bytes4[] memory cutSelectors = registry.getFacetFunctionSelectors(address(diamondCutFacet));
        assertEq(cutSelectors.length, 1);
        assertEq(cutSelectors[0], diamondCutSelectors[0]);

        bytes4[] memory loupeSelectors = registry.getFacetFunctionSelectors(address(diamondLoupeFacet));
        assertEq(loupeSelectors.length, 5);

        bytes4[] memory ownSelectors = registry.getFacetFunctionSelectors(address(ownershipFacet));
        assertEq(ownSelectors.length, 2);

        bytes4[] memory upgSelectors = registry.getFacetFunctionSelectors(address(upgradeFacet));
        assertEq(upgSelectors.length, 3);
    }

    /// @notice Test initialization with different owner
    function test_InitializeWithDifferentOwner() public {
        address newOwner = makeAddr("newOwner");

        FacetRegistry newImpl = new FacetRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseSelectors = new bytes4[][](4);
        baseSelectors[0] = diamondCutSelectors;
        baseSelectors[1] = diamondLoupeSelectors;
        baseSelectors[2] = ownershipSelectors;
        baseSelectors[3] = upgradeSelectors;

        bytes memory initData =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, newOwner, baseFacets, baseSelectors);

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);

        FacetRegistry newRegistry = FacetRegistry(payable(address(newProxy)));
        assertEq(newRegistry.owner(), newOwner);
    }

    /// @notice Test initialization rejects zero address facet
    function test_RevertInitializeWithZeroFacet() public {
        FacetRegistry newImpl = new FacetRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        address[4] memory baseFacets = [
            address(diamondCutFacet),
            address(0), // Zero address - should revert
            address(ownershipFacet),
            address(upgradeFacet)
        ];

        bytes4[][] memory baseSelectors = new bytes4[][](4);
        baseSelectors[0] = diamondCutSelectors;
        baseSelectors[1] = diamondLoupeSelectors;
        baseSelectors[2] = ownershipSelectors;
        baseSelectors[3] = upgradeSelectors;

        bytes memory initData =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, owner, baseFacets, baseSelectors);

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_FacetAddressIsZero()));
        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);
    }

    /// @notice Test initialization rejects non-contract facet
    function test_RevertInitializeWithNonContractFacet() public {
        FacetRegistry newImpl = new FacetRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        address[4] memory baseFacets = [
            address(diamondCutFacet),
            address(makeAddr("nonContract")), // Non-contract address
            address(ownershipFacet),
            address(upgradeFacet)
        ];

        bytes4[][] memory baseSelectors = new bytes4[][](4);
        baseSelectors[0] = diamondCutSelectors;
        baseSelectors[1] = diamondLoupeSelectors;
        baseSelectors[2] = ownershipSelectors;
        baseSelectors[3] = upgradeSelectors;

        bytes memory initData =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, owner, baseFacets, baseSelectors);

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_FacetIsNotContract(), baseFacets[1]));
        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);
    }

    /// @notice Test that implementation cannot be initialized directly
    function test_RevertDirectImplementationInitialization() public {
        FacetRegistry directImpl = new FacetRegistry();
        ProxyAdmin admin = new ProxyAdmin(address(this));

        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseSelectors = new bytes4[][](4);
        baseSelectors[0] = diamondCutSelectors;
        baseSelectors[1] = diamondLoupeSelectors;
        baseSelectors[2] = ownershipSelectors;
        baseSelectors[3] = upgradeSelectors;

        vm.expectRevert();
        directImpl.initialize(owner, baseFacets, baseSelectors);
    }

    /// @notice Test that initialization cannot be called twice
    function test_RevertReinitializeProxy() public {
        FacetRegistry newImpl = new FacetRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseSelectors = new bytes4[][](4);
        baseSelectors[0] = diamondCutSelectors;
        baseSelectors[1] = diamondLoupeSelectors;
        baseSelectors[2] = ownershipSelectors;
        baseSelectors[3] = upgradeSelectors;

        bytes memory initData =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, owner, baseFacets, baseSelectors);

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);

        FacetRegistry newRegistry = FacetRegistry(payable(address(newProxy)));

        // Try to initialize again - should fail
        vm.expectRevert();
        newRegistry.initialize(owner, baseFacets, baseSelectors);
    }

    /// @notice Test owner is set correctly on initialization
    function test_OwnerSetOnInitialization() public view {
        assertEq(registry.owner(), owner);
    }

    /// @notice Test base facets are registered on initialization
    function test_BaseFacetsRegisteredOnInitialization() public view {
        address[4] memory baseFacets = registry.getBaseFacets();
        assertNotEq(baseFacets[0], address(0));
        assertNotEq(baseFacets[1], address(0));
        assertNotEq(baseFacets[2], address(0));
        assertNotEq(baseFacets[3], address(0));
    }

    /// @notice Test all base facet selectors are registered
    function test_BaseFacetSelectorsRegistered() public view {
        // DiamondCutFacet
        assertTrue(registry.isSelectorRegisteredWithFacet(address(diamondCutFacet), diamondCutSelectors[0]));

        // DiamondLoupeFacet
        for (uint256 i = 0; i < diamondLoupeSelectors.length; i++) {
            assertTrue(registry.isSelectorRegisteredWithFacet(address(diamondLoupeFacet), diamondLoupeSelectors[i]));
        }

        // OwnershipFacet
        for (uint256 i = 0; i < ownershipSelectors.length; i++) {
            assertTrue(registry.isSelectorRegisteredWithFacet(address(ownershipFacet), ownershipSelectors[i]));
        }

        // UpgradeFacet
        for (uint256 i = 0; i < upgradeSelectors.length; i++) {
            assertTrue(registry.isSelectorRegisteredWithFacet(address(upgradeFacet), upgradeSelectors[i]));
        }
    }

    /// @notice Test initial version is zero
    function test_InitialVersionIsZero() public view {
        assertEq(registry.getCurrentVersion(), 0);
    }

    /// @notice Test that facets array length is correct after initialization
    function test_FacetsArrayLengthAfterInit() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        assertEq(facets.length, 4);
    }

    /// @notice Test that facet addresses array is correct after initialization
    function test_FacetAddressesAfterInit() public view {
        address[] memory addresses = registry.getFacetAddresses();
        assertEq(addresses.length, 4);
        assertEq(addresses[0], address(diamondCutFacet));
        assertEq(addresses[1], address(diamondLoupeFacet));
        assertEq(addresses[2], address(ownershipFacet));
        assertEq(addresses[3], address(upgradeFacet));
    }
}
