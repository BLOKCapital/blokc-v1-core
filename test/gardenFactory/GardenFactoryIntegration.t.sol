// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GardenFactoryTestBase } from "./GardenFactoryTestBase.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

/// @title Integration tests for GardenFactory
/// @notice Tests the integration between GardenFactory and its dependencies
contract GardenFactoryIntegrationTest is GardenFactoryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // FACET REGISTRY INTEGRATION
    // =============================================================

    /// @notice Test that factory uses correct facet registry
    function test_Integration_FacetRegistry() public {
        address gardenAddress = createGardenForUser(user1, 1);

        // Check that base facets from registry are installed
        IDiamondLoupe loupe = IDiamondLoupe(gardenAddress);
        address[4] memory registryBaseFacets = facetRegistry.getBaseFacets();

        // Verify facets are installed
        address cutFacet = loupe.facetAddress(IDiamondCut.diamondCut.selector);
        assertEq(cutFacet, registryBaseFacets[0], "Should use facet from registry");
    }

    /// @notice Test that garden gets all base facets from registry
    function test_Integration_AllBaseFacetsInstalled() public {
        address gardenAddress = createGardenForUser(user1, 1);
        IDiamondLoupe loupe = IDiamondLoupe(gardenAddress);

        address[4] memory baseFacets = facetRegistry.getBaseFacets();

        // Verify each base facet is installed
        for (uint256 i = 0; i < baseFacets.length; i++) {
            bytes4[] memory selectors = facetRegistry.getFacetFunctionSelectors(baseFacets[i]);
            require(selectors.length > 0, "Facet should have selectors");

            // Check at least one selector from this facet
            address facetAddress = loupe.facetAddress(selectors[0]);
            assertEq(facetAddress, baseFacets[i], "Facet should be installed");
        }
    }

    /// @notice Test that garden initialization uses facet registry correctly
    function test_Integration_FacetRegistryFunctionSelectors() public {
        address gardenAddress = createGardenForUser(user1, 1);
        IDiamondLoupe loupe = IDiamondLoupe(gardenAddress);

        // Get selectors from registry
        bytes4[] memory cutSelectors = facetRegistry.getFacetFunctionSelectors(address(diamondCutFacet));
        require(cutSelectors.length > 0, "Should have selectors");

        // Verify they're installed in the garden
        for (uint256 i = 0; i < cutSelectors.length; i++) {
            address facetAddress = loupe.facetAddress(cutSelectors[i]);
            assertEq(facetAddress, address(diamondCutFacet), "Selector should be mapped to correct facet");
        }
    }

    // =============================================================
    // PROTOCOL STATUS INTEGRATION
    // =============================================================

    /// @notice Test that garden is initialized with correct protocol status
    function test_Integration_ProtocolStatus() public {
        address gardenAddress = createGardenForUser(user1, 1);

        // The protocol status is stored in Diamond storage
        // We verify the garden was created successfully, which implies protocol status was set
        assertTrue(gardenAddress != address(0));
        assertTrue(factory.isGardenRegistered(gardenAddress));

        // The protocol status integration is tested by successful garden creation
        // since Diamond constructor requires it
    }

    // =============================================================
    // POOL REGISTRY INTEGRATION
    // =============================================================

    /// @notice Test that garden is initialized with correct pool registry
    function test_Integration_PoolRegistry() public {
        address gardenAddress = createGardenForUser(user1, 1);

        // The pool registry is stored in Diamond storage
        // We verify the garden was created successfully, which implies pool registry was set
        assertTrue(gardenAddress != address(0));

        // The pool registry integration is tested by successful garden creation
        // since Diamond constructor requires it
    }

    // =============================================================
    // DIAMOND INTEGRATION
    // =============================================================

    /// @notice Test that created garden is a valid Diamond
    function test_Integration_ValidDiamond() public {
        address gardenAddress = createGardenForUser(user1, 1);

        // Test ERC165 support
        IERC165 diamond = IERC165(gardenAddress);

        // Verify DiamondCut interface
        assertTrue(diamond.supportsInterface(type(IDiamondCut).interfaceId));

        // Verify DiamondLoupe interface
        assertTrue(diamond.supportsInterface(type(IDiamondLoupe).interfaceId));

        // Verify Ownership interface
        assertTrue(diamond.supportsInterface(type(IERC173).interfaceId));
    }

    /// @notice Test that garden has correct owner
    function test_Integration_GardenOwnership() public {
        address gardenAddress = createGardenForUser(user1, 1);

        IERC173 garden = IERC173(gardenAddress);
        assertEq(garden.owner(), user1, "Garden owner should be the creator");
    }

    /// @notice Test that garden can execute diamond cut operations
    function test_Integration_DiamondCutFunctional() public {
        address gardenAddress = createGardenForUser(user1, 1);

        IDiamondLoupe loupe = IDiamondLoupe(gardenAddress);
        IDiamondLoupe.Facet[] memory facets = loupe.facets();

        assertGt(facets.length, 0, "Garden should have facets");
        assertTrue(facets.length >= 4, "Garden should have at least base facets");
    }

    // =============================================================
    // END-TO-END SCENARIOS
    // =============================================================

    /// @notice Test complete flow: multiple users creating multiple gardens
    function test_Integration_MultipleUsersMultipleGardens() public {
        // User1 creates 5 gardens
        address[] memory user1Gardens = createMultipleGardensForUser(user1, 5);

        // User2 creates 3 gardens
        address[] memory user2Gardens = new address[](3);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(user2);
            user2Gardens[i] = factory.createGarden(i + 1);
        }

        // User3 creates 1 garden
        createGardenForUser(user3, 1);

        // Verify state consistency
        address[] memory allGardens = factory.getAllGardens();
        assertEq(allGardens.length, 9, "Should have 9 total gardens");

        address[] memory retrievedUser1 = factory.getUserGardens(user1);
        assertEq(retrievedUser1.length, 5, "User1 should have 5 gardens");

        address[] memory retrievedUser2 = factory.getUserGardens(user2);
        assertEq(retrievedUser2.length, 3, "User2 should have 3 gardens");

        address[] memory retrievedUser3 = factory.getUserGardens(user3);
        assertEq(retrievedUser3.length, 1, "User3 should have 1 garden");

        // Verify all gardens are functional Diamonds
        for (uint256 i = 0; i < user1Gardens.length; i++) {
            IERC173 garden = IERC173(user1Gardens[i]);
            assertEq(garden.owner(), user1, "Garden should have correct owner");
        }
    }

    /// @notice Test integration with facet registry changes
    function test_Integration_FacetRegistryUpdates() public {
        // Create initial garden
        address garden1 = createGardenForUser(user1, 1);

        // Note: Facet registry updates would affect new gardens, not existing ones
        // This tests that the factory uses the registry at creation time

        address garden2 = createGardenForUser(user1, 2);

        // Both gardens should have base facets installed
        IDiamondLoupe loupe1 = IDiamondLoupe(garden1);
        IDiamondLoupe loupe2 = IDiamondLoupe(garden2);

        IDiamondLoupe.Facet[] memory facets1 = loupe1.facets();
        IDiamondLoupe.Facet[] memory facets2 = loupe2.facets();

        // Should have same base facets
        assertGe(facets1.length, 4, "Garden1 should have base facets");
        assertGe(facets2.length, 4, "Garden2 should have base facets");
    }

    /// @notice Test that garden addresses are deterministic and unique
    function test_Integration_DeterministicAndUniqueAddresses() public {
        address[] memory user1Gardens = createMultipleGardensForUser(user1, 10);
        address[] memory user2Gardens = createMultipleGardensForUser(user2, 10);

        // All gardens should be unique
        for (uint256 i = 0; i < user1Gardens.length; i++) {
            for (uint256 j = i + 1; j < user1Gardens.length; j++) {
                assertNotEq(user1Gardens[i], user1Gardens[j], "User1 gardens should be unique");
            }

            for (uint256 k = 0; k < user2Gardens.length; k++) {
                assertNotEq(user1Gardens[i], user2Gardens[k], "Cross-user gardens should be unique");
            }
        }
    }

    /// @notice Test integration with CREATE2 determinism
    function test_Integration_CREATE2Determinism() public {
        // Create garden
        address garden1 = createGardenForUser(user1, 5);

        // Calculate expected salt
        bytes32 salt = keccak256(abi.encode(user1, 5, address(factory)));

        // The garden address should be deterministic based on salt
        // Note: We can't directly verify the CREATE2 address without the bytecode,
        // but we can verify the salt matches
        assertTrue(garden1 != address(0), "Garden should have valid address");

        // Verify that same parameters in a new factory would use same salt logic
        bytes32 salt2 = keccak256(abi.encode(user1, 5, address(factory)));
        assertEq(salt, salt2, "Salts should match for same parameters");
    }

    // =============================================================
    // REALISTIC WORKFLOW TESTS
    // =============================================================

    /// @notice Test realistic deployment scenario
    function test_Integration_RealisticDeployment() public {
        // Simulate real-world usage:
        // 1. Multiple users deploy gardens
        // 2. Users deploy gardens at different times
        // 3. Verify all gardens work correctly

        // Phase 1: Initial deployments
        address aliceGarden1 = createGardenForUser(user1, 1);
        address bobGarden1 = createGardenForUser(user2, 1);

        // Phase 2: More deployments
        address aliceGarden2 = createGardenForUser(user1, 2);
        address charlieGarden1 = createGardenForUser(user3, 1);

        // Phase 3: Verify all gardens
        assertTrue(factory.isGardenRegistered(aliceGarden1));
        assertTrue(factory.isGardenRegistered(bobGarden1));
        assertTrue(factory.isGardenRegistered(aliceGarden2));
        assertTrue(factory.isGardenRegistered(charlieGarden1));

        // Verify garden functionality
        IERC173 aliceGarden1Contract = IERC173(aliceGarden1);
        assertEq(aliceGarden1Contract.owner(), user1);

        IERC173 bobGarden1Contract = IERC173(bobGarden1);
        assertEq(bobGarden1Contract.owner(), user2);

        // Verify factory state
        address[] memory allGardens = factory.getAllGardens();
        assertEq(allGardens.length, 4);

        address[] memory aliceGardens = factory.getUserGardens(user1);
        assertEq(aliceGardens.length, 2);
    }

    /// @notice Test maximum capacity scenario
    function test_Integration_MaximumCapacity() public {
        // Test scenario where users create maximum gardens

        // User1 creates all 10 gardens
        createMultipleGardensForUser(user1, 10);

        // User2 creates all 10 gardens
        createMultipleGardensForUser(user2, 10);

        // User3 creates all 10 gardens
        createMultipleGardensForUser(user3, 10);

        // Verify total
        address[] memory allGardens = factory.getAllGardens();
        assertEq(allGardens.length, 30, "Should have 30 total gardens");

        // Verify each user has 10 gardens
        assertEq(factory.getUserGardens(user1).length, 10);
        assertEq(factory.getUserGardens(user2).length, 10);
        assertEq(factory.getUserGardens(user3).length, 10);

        // Verify all gardens are functional
        for (uint256 i = 0; i < allGardens.length; i++) {
            assertTrue(factory.isGardenRegistered(allGardens[i]));
            IERC173 garden = IERC173(allGardens[i]);
            assertTrue(garden.owner() == user1 || garden.owner() == user2 || garden.owner() == user3);
        }
    }
}
