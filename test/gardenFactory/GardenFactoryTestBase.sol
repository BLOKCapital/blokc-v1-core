// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { IGardenFactory } from "src/interfaces/IGardenFactory.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { DiamondCutFacet } from "src/diamond/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/diamond/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

/// @dev Simple forwarding contract to handle hardcoded addresses
contract Forwarder {
    address public immutable target;

    constructor(address _target) {
        target = _target;
    }

    fallback() external payable {
        address _target = target;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := staticcall(gas(), _target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/// @title Base test contract for GardenFactory tests
/// @notice Provides common setup and helper functions for all GardenFactory test suites
abstract contract GardenFactoryTestBase is Test {
    // Factory contracts
    GardenFactory internal factory;
    GardenFactory internal factoryImpl;
    ProxyAdmin internal factoryProxyAdmin;
    TransparentUpgradeableProxy internal factoryProxy;

    // Dependencies
    FacetRegistry internal facetRegistry;
    FacetRegistry internal registryImpl;
    ProxyAdmin internal registryProxyAdmin;
    TransparentUpgradeableProxy internal registryProxy;

    PoolRegistry internal poolRegistry;
    PoolRegistry internal poolRegistryImpl;
    ProxyAdmin internal poolRegistryProxyAdmin;
    TransparentUpgradeableProxy internal poolRegistryProxy;

    ProtocolStatus internal protocolStatus;

    // Base facets
    DiamondCutFacet internal diamondCutFacet;
    DiamondLoupeFacet internal diamondLoupeFacet;
    OwnershipFacet internal ownershipFacet;
    UpgradeFacet internal upgradeFacet;

    // Function selectors for base facets
    bytes4[] internal diamondCutSelectors;
    bytes4[] internal diamondLoupeSelectors;
    bytes4[] internal ownershipSelectors;
    bytes4[] internal upgradeSelectors;

    // Test addresses
    address internal owner;
    address internal user1;
    address internal user2;
    address internal user3;

    // Events
    event GardenCreated(address indexed garden, address indexed owner, uint256 indexed index);
    event FactoryInitialized(address indexed initialOwner);

    function setUp() public virtual {
        // Setup test addresses
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

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

        // Deploy FacetRegistry
        registryImpl = new FacetRegistry();
        registryProxyAdmin = new ProxyAdmin(owner);

        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseSelectors = new bytes4[][](4);
        baseSelectors[0] = diamondCutSelectors;
        baseSelectors[1] = diamondLoupeSelectors;
        baseSelectors[2] = ownershipSelectors;
        baseSelectors[3] = upgradeSelectors;

        bytes memory initRegistry =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, owner, baseFacets, baseSelectors);

        registryProxy =
            new TransparentUpgradeableProxy(address(registryImpl), address(registryProxyAdmin), initRegistry);

        facetRegistry = FacetRegistry(payable(address(registryProxy)));

        // Deploy PoolRegistry
        poolRegistryImpl = new PoolRegistry();
        poolRegistryProxyAdmin = new ProxyAdmin(owner);

        bytes memory initPoolRegistry = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner);
        poolRegistryProxy = new TransparentUpgradeableProxy(
            address(poolRegistryImpl), address(poolRegistryProxyAdmin), initPoolRegistry
        );

        poolRegistry = PoolRegistry(payable(address(poolRegistryProxy)));

        // Deploy ProtocolStatus (no proxy needed)
        // ProtocolStatus requires at least one Security Council member
        IProtocolStatus.SecurityCouncilMember[] memory initialMembers = new IProtocolStatus.SecurityCouncilMember[](1);
        initialMembers[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: makeAddr("securityCouncil1"),
            name: "Security Council Member 1"
        });
        protocolStatus = new ProtocolStatus(initialMembers, owner);

        // Mock the hardcoded FACET_REGISTRY_ADDRESS in GardenFactory and LibDiamond
        // The address 0x1234567890123456789012345678901234567890 is hardcoded in both places
        // Deploy a forwarder at that address that redirects calls to the real FacetRegistry
        address facetRegistryMockAddress = 0x1234567890123456789012345678901234567890;

        Forwarder facetRegistryForwarder = new Forwarder(address(facetRegistry));
        // The forwarder's bytecode already has the target address embedded as an immutable
        vm.etch(facetRegistryMockAddress, address(facetRegistryForwarder).code);

        // Mock the hardcoded PROTOCOL_STATUS_ADDRESS in LibDiamond
        // The address 0xabCDEF1234567890ABcDEF1234567890aBCDeF12 is hardcoded in LibDiamond
        address protocolStatusMockAddress = 0xabCDEF1234567890ABcDEF1234567890aBCDeF12;

        Forwarder protocolStatusForwarder = new Forwarder(address(protocolStatus));
        vm.etch(protocolStatusMockAddress, address(protocolStatusForwarder).code);

        // Activate the protocol status so diamonds can function
        vm.prank(owner);
        protocolStatus.activateProtocol();

        // Deploy GardenFactory
        factoryImpl = new GardenFactory();

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector, owner, address(facetRegistry), address(protocolStatus)
        );

        // In OZ v5, TransparentUpgradeableProxy creates its own ProxyAdmin
        // Pass owner directly as initialOwner (not a ProxyAdmin address)
        factoryProxy = new TransparentUpgradeableProxy(
            address(factoryImpl),
            owner, // initialOwner - the proxy will create a ProxyAdmin with this owner
            factoryInitData
        );

        factory = GardenFactory(payable(address(factoryProxy)));

        // Get reference to the ProxyAdmin that was created by the proxy
        bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address admin = address(uint160(uint256(vm.load(address(factoryProxy), ADMIN_SLOT))));
        factoryProxyAdmin = ProxyAdmin(admin);
    }

    /// @notice Helper function to create a garden for a user
    /// @param user The user address to create the garden for
    /// @param index The index (1-10) to use for the garden
    /// @return gardenAddress The address of the created garden
    function createGardenForUser(address user, uint256 index) internal returns (address gardenAddress) {
        vm.prank(user);
        gardenAddress = factory.createGarden(index);
    }

    /// @notice Helper function to create multiple gardens for a user
    /// @param user The user address to create gardens for
    /// @param count The number of gardens to create (max 10)
    /// @return gardens Array of garden addresses
    function createMultipleGardensForUser(address user, uint256 count) internal returns (address[] memory gardens) {
        require(count > 0 && count <= 10, "Invalid count");
        gardens = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            vm.prank(user);
            gardens[i] = factory.createGarden(i + 1);
        }
    }

    /// @notice Helper function to calculate the expected CREATE2 address
    /// @param bytecode The bytecode to deploy
    /// @param salt The salt used for CREATE2
    /// @return The expected address
    function calculateCreate2Address(bytes memory bytecode, bytes32 salt) internal view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    /// @notice Helper to assert that a garden was created correctly
    /// @param gardenAddress The address of the garden
    /// @param expectedOwner The expected owner of the garden
    function assertGardenCreated(address gardenAddress, address expectedOwner) internal view {
        assertTrue(gardenAddress != address(0), "Garden address should not be zero");
        assertTrue(factory.isGardenRegistered(gardenAddress), "Garden should be registered");

        address[] memory userGardens = factory.getUserGardens(expectedOwner);
        bool found = false;
        for (uint256 i = 0; i < userGardens.length; i++) {
            if (userGardens[i] == gardenAddress) {
                found = true;
                break;
            }
        }
        assertTrue(found, "Garden should be in user's garden list");
    }
}
