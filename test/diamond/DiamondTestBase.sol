// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { DiamondCutFacet } from "src/diamond/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/diamond/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IUpgrade } from "src/diamond/facets/baseFacets/upgrade/IUpgrade.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @dev Simple forwarding contract to handle hardcoded addresses in Diamond/LibDiamond
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

    receive() external payable { }
}

/// @title Base test contract for Diamond tests
/// @notice Provides common setup and helper functions for all Diamond test suites
abstract contract DiamondTestBase is Test {
    // Contracts
    Diamond internal diamond;
    FacetRegistry internal facetRegistry;
    ProtocolStatus internal protocolStatus;

    // Base Facets
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    OwnershipFacet internal ownershipFacet;
    UpgradeFacet internal upgradeFacet;

    // Registry proxy components
    FacetRegistry internal registryImpl;
    ProxyAdmin internal registryProxyAdmin;
    TransparentUpgradeableProxy internal registryProxy;

    // Addresses
    address internal owner;
    address internal user1;
    address internal user2;
    address internal nonOwner;

    // Facet selectors
    bytes4[] internal cutSelectors;
    bytes4[] internal loupeSelectors;
    bytes4[] internal ownershipSelectors;
    bytes4[] internal upgradeSelectors;

    // ========================================================================
    // Setup
    // ========================================================================

    function setUp() public virtual {
        // Setup addresses
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        nonOwner = makeAddr("nonOwner");

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Deploy base facets
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        upgradeFacet = new UpgradeFacet();

        // Setup selectors for each facet
        _setupSelectors();

        // Deploy FacetRegistry with proxy
        _deployFacetRegistry();

        // Deploy ProtocolStatus
        _deployProtocolStatus();

        // Mock hardcoded addresses in LibDiamond
        _mockHardcodedAddresses();

        // Deploy Diamond with base facets
        _deployDiamond();
    }

    // ========================================================================
    // Internal Setup Functions
    // ========================================================================

    function _setupSelectors() internal {
        // DiamondCutFacet selectors
        cutSelectors = new bytes4[](1);
        cutSelectors[0] = cutFacet.diamondCut.selector;

        // DiamondLoupeFacet selectors
        loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = loupeFacet.facets.selector;
        loupeSelectors[1] = loupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = loupeFacet.facetAddresses.selector;
        loupeSelectors[3] = loupeFacet.facetAddress.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;

        // OwnershipFacet selectors
        ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = ownershipFacet.owner.selector;
        ownershipSelectors[1] = ownershipFacet.transferOwnership.selector;

        // UpgradeFacet selectors (includes DiamondLoupeFacet as it inherits from it)
        upgradeSelectors = new bytes4[](3);
        upgradeSelectors[0] = upgradeFacet.upgrade.selector;
        upgradeSelectors[1] = upgradeFacet.getCurrentVersion.selector;
        upgradeSelectors[2] = upgradeFacet.upgradeDetails.selector;
    }

    function _deployFacetRegistry() internal {
        // Deploy implementation
        registryImpl = new FacetRegistry();

        // Deploy ProxyAdmin
        registryProxyAdmin = new ProxyAdmin(owner);

        // Prepare initialization data
        address[4] memory baseFacets =
            [address(cutFacet), address(loupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseFacetSelectors = new bytes4[][](4);
        baseFacetSelectors[0] = cutSelectors;
        baseFacetSelectors[1] = loupeSelectors;
        baseFacetSelectors[2] = ownershipSelectors;
        baseFacetSelectors[3] = upgradeSelectors;

        bytes memory initData =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, owner, baseFacets, baseFacetSelectors);

        // Deploy proxy
        registryProxy = new TransparentUpgradeableProxy(address(registryImpl), address(registryProxyAdmin), initData);

        facetRegistry = FacetRegistry(address(registryProxy));
    }

    function _deployProtocolStatus() internal {
        IProtocolStatus.ENSMember[] memory initialMembers = new IProtocolStatus.ENSMember[](1);

        initialMembers[0] = IProtocolStatus.ENSMember({
            namehash: keccak256(abi.encodePacked("chintan.eth")),
            ensName: "chintan.eth",
            resolvedAddress: makeAddr("securityCouncil1"),
            previousAddress: address(0),
            expiryTimestamp: block.timestamp + 365 days,
            status: IProtocolStatus.SCMStatus.ACTIVE
        });

        protocolStatus = new ProtocolStatus(initialMembers, owner);

        // Activate protocol
        vm.prank(owner);
        protocolStatus.activateProtocol();
    }

    function _mockHardcodedAddresses() internal {
        // Mock FACET_REGISTRY_ADDRESS (0x1234567890123456789012345678901234567890)
        address facetRegistryMockAddress = 0x1234567890123456789012345678901234567890;
        Forwarder facetRegistryForwarder = new Forwarder(address(facetRegistry));
        vm.etch(facetRegistryMockAddress, address(facetRegistryForwarder).code);

        // Mock PROTOCOL_STATUS_ADDRESS (0xabCDEF1234567890ABcDEF1234567890aBCDeF12)
        address protocolStatusMockAddress = 0xabCDEF1234567890ABcDEF1234567890aBCDeF12;
        Forwarder protocolStatusForwarder = new Forwarder(address(protocolStatus));
        vm.etch(protocolStatusMockAddress, address(protocolStatusForwarder).code);
    }

    function _deployDiamond() internal virtual {
        // Prepare diamond cuts for initialization
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(cutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(upgradeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: upgradeSelectors
        });

        // Deploy diamond
        diamond = new Diamond(cuts, owner, address(facetRegistry), address(protocolStatus));
    }

    // ========================================================================
    // Helper Functions
    // ========================================================================

    /// @notice Get Diamond as IDiamondCut interface
    function getDiamondCut() internal view returns (IDiamondCut) {
        return IDiamondCut(address(diamond));
    }

    /// @notice Get Diamond as IDiamondLoupe interface
    function getDiamondLoupe() internal view returns (IDiamondLoupe) {
        return IDiamondLoupe(address(diamond));
    }

    /// @notice Get Diamond as IERC173 interface
    function getDiamondOwnership() internal view returns (IERC173) {
        return IERC173(address(diamond));
    }

    /// @notice Get Diamond as IUpgrade interface
    function getDiamondUpgrade() internal view returns (IUpgrade) {
        return IUpgrade(address(diamond));
    }

    /// @notice Get Diamond as IERC165 interface
    function getDiamondERC165() internal view returns (IERC165) {
        return IERC165(address(diamond));
    }

    /// @notice Helper to create a simple facet cut for adding
    function createAddCut(
        address facet,
        bytes4[] memory selectors
    )
        internal
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    /// @notice Helper to create a simple facet cut for replacing
    function createReplaceCut(
        address facet,
        bytes4[] memory selectors
    )
        internal
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
    }

    /// @notice Helper to create a simple facet cut for removing
    function createRemoveCut(bytes4[] memory selectors) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });
    }
}
