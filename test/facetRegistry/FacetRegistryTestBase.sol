// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { DiamondCutFacet } from "src/diamond/facets/baseFacets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/diamond/facets/baseFacets/OwnershipFacet.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/UpgradeFacet.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";

/// @title Base test contract for FacetRegistry tests
abstract contract FacetRegistryTestBase is Test {
    FacetRegistry internal registry;
    ProxyAdmin internal registryProxyAdmin;
    FacetRegistry internal registryImpl;
    TransparentUpgradeableProxy internal registryProxy;

    address internal owner;
    address internal user1;
    address internal user2;

    // Base facets
    DiamondCutFacet internal diamondCutFacet;
    DiamondLoupeFacet internal diamondLoupeFacet;
    OwnershipFacet internal ownershipFacet;
    UpgradeFacet internal upgradeFacet;

    // Mock facets
    MockFacet internal mockFacet;
    MockFacetV2 internal mockFacetV2;

    // Function selectors for base facets
    bytes4[] internal diamondCutSelectors;
    bytes4[] internal diamondLoupeSelectors;
    bytes4[] internal ownershipSelectors;
    bytes4[] internal upgradeSelectors;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public virtual {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy implementation
        registryImpl = new FacetRegistry();

        // Deploy ProxyAdmin
        registryProxyAdmin = new ProxyAdmin(owner);

        // Deploy base facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        upgradeFacet = new UpgradeFacet();

        // Setup function selectors for base facets
        diamondCutSelectors = new bytes4[](1);
        diamondCutSelectors[0] = diamondCutFacet.diamondCut.selector;

        diamondLoupeSelectors = new bytes4[](5);
        diamondLoupeSelectors[0] = diamondLoupeFacet.facets.selector;
        diamondLoupeSelectors[1] = diamondLoupeFacet.facetFunctionSelectors.selector;
        diamondLoupeSelectors[2] = diamondLoupeFacet.facetAddresses.selector;
        diamondLoupeSelectors[3] = diamondLoupeFacet.facetAddress.selector;
        diamondLoupeSelectors[4] = IERC165.supportsInterface.selector;

        ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = ownershipFacet.owner.selector;
        ownershipSelectors[1] = ownershipFacet.transferOwnership.selector;

        upgradeSelectors = new bytes4[](2);
        upgradeSelectors[0] = upgradeFacet.upgrade.selector;
        upgradeSelectors[1] = upgradeFacet.upgradeDetails.selector;

        // Prepare base facets array and selectors
        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseSelectors = new bytes4[][](4);
        baseSelectors[0] = diamondCutSelectors;
        baseSelectors[1] = diamondLoupeSelectors;
        baseSelectors[2] = ownershipSelectors;
        baseSelectors[3] = upgradeSelectors;

        // Initialize the proxy with the implementation and initialization data
        bytes memory initData = abi.encodeWithSelector(
            FacetRegistry.initialize.selector,
            owner, // initialOwner
            baseFacets,
            baseSelectors
        );

        registryProxy = new TransparentUpgradeableProxy(address(registryImpl), address(registryProxyAdmin), initData);

        registry = FacetRegistry(payable(address(registryProxy)));

        // Deploy mock facets
        mockFacet = new MockFacet();
        mockFacetV2 = new MockFacetV2();
    }

    /// @notice Helper function to add a facet with selectors
    function addFacetWithSelectors(address facet, bytes4[] memory selectors) internal {
        vm.prank(owner);
        registry.addFunctions(facet, selectors);
    }

    /// @notice Helper function to replace a facet with selectors
    function replaceFacetWithSelectors(address facet, bytes4[] memory selectors) internal {
        vm.prank(owner);
        registry.replaceFunctions(facet, selectors);
    }

    /// @notice Helper function to remove selectors from registry
    function removeSelectors(bytes4[] memory selectors) internal {
        vm.prank(owner);
        registry.removeFunctions(address(0), selectors);
    }

    /// @notice Helper function to get selector for a function
    function getSelector(string memory funcSig) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(funcSig)));
    }

    // Error selector helpers - these match the file-level errors in FacetRegistry.sol
    function getErrorSelector_SelectorArrayEmpty() internal pure returns (bytes4) {
        return bytes4(keccak256("FacetRegistry_SelectorArrayEmpty()"));
    }

    function getErrorSelector_FacetAddressIsZero() internal pure returns (bytes4) {
        return bytes4(keccak256("FacetRegistry_FacetAddressIsZero()"));
    }

    function getErrorSelector_FacetIsNotContract() internal pure returns (bytes4) {
        return bytes4(keccak256("FacetRegistry_FacetIsNotContract(address)"));
    }

    function getErrorSelector_CannotAddFunctionThatAlreadyExists() internal pure returns (bytes4) {
        return bytes4(keccak256("FacetRegistry_CannotAddFunctionThatAlreadyExists(bytes4)"));
    }

    function getErrorSelector_CannotReplaceFunctionWithSameFunction() internal pure returns (bytes4) {
        return bytes4(keccak256("FacetRegistry_CannotReplaceFunctionWithSameFunction(address,bytes4)"));
    }

    function getErrorSelector_RemoveFacetAddressMustBeZero() internal pure returns (bytes4) {
        return bytes4(keccak256("FacetRegistry_RemoveFacetAddressMustBeZero(address)"));
    }

    function getErrorSelector_CannotRemoveFunctionThatDoesNotExist() internal pure returns (bytes4) {
        return bytes4(keccak256("FacetRegistry_CannotRemoveFunctionThatDoesNotExist(address,bytes4)"));
    }

    function getErrorSelector_CannotModifyBaseFacet() internal pure returns (bytes4) {
        return bytes4(keccak256("FacetRegistry_CannotModifyBaseFacet(address)"));
    }
}
