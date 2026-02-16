// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title Garden
    @author BLOK Capital DAO (based on EIP-2535 by Nick Mudge)
    @notice Implementation of a Garden contract(Diamond Proxy) that manages a collection of facets
    @dev This contract implements the Diamond proxy pattern with additional validation
         logic to ensure all function calls are validated against the FacetRegistry.
         The registry validation provides defense-in-depth security by ensuring only
         registered facets and selectors can be executed.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Libraries
import { OwnershipStorage } from "src/garden/facets/baseFacets/ownership/OwnershipStorage.sol";
import { DiamondCutStorage } from "src/garden/facets/baseFacets/cut/DiamondCutStorage.sol";
import { DiamondCutBase } from "src/garden/facets/baseFacets/cut/DiamondCutBase.sol";
import { DiamondLoupeStorage } from "src/garden/facets/baseFacets/loupe/DiamondLoupeStorage.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

// Local Interfaces
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

// ============================================================================
// Errors
// ============================================================================

/// @param selector The function selector that was attempted
error Garden_InvalidCall(bytes4 selector);

/// @notice Thrown when facet registry address is not set or is zero
error Garden_FacetRegistryNotSet();

/// @notice Thrown when protocol status address is not set or is zero
error Garden_ProtocolStatusNotSet();

/// @notice Thrown when contract owner address is zero
error Garden_ContractOwnerIsZero();

/// @param selector The function selector that requires upgrade
error Garden_SelectorNotInGarden(bytes4 selector);

/// @param selector The function selector that was removed
error Garden_SelectorRemoved(bytes4 selector);

/// @param selector The function selector that was moved
error Garden_SelectorMoved(bytes4 selector);

/// @notice Thrown when upgrades are disabled
error Garden_UpgradesDisabled();

/// @notice Thrown when protocol is inactive
error Garden_ProtocolIsInactive();

/// @notice Thrown when the garden type is not registered
error Garden_GardenTypeNotRegistered();

/// @notice Thrown when a selector's module is not allowed for the garden's type
/// @param selector The function selector whose module is not allowed
error Garden_ModuleNotAllowed(bytes4 selector);

contract Garden is DiamondCutBase {
    // ========================================================================
    // Constructor
    // ========================================================================

    /// @notice The BASE module identifier (matches FacetRegistry.BASE_MODULE)
    bytes32 private constant BASE_MODULE = keccak256("BASE");

    /// @notice Constructs the Diamond contract with initial facets and configuration
    /// @dev Validates all critical addresses are non-zero and initializes the diamond with
    ///      facets for the specified garden type. Module versions are synced at deployment.
    /// @param _diamondCut Array of facet cuts to apply during initialization
    /// @param _contractOwner Address that will own the diamond contract
    /// @param _facetRegistry Address of the FacetRegistry contract
    /// @param _protocolStatus Address of the ProtocolStatus contract
    /// @param _gardenType The garden type identifier (determines allowed modules)
    constructor(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _contractOwner,
        address _facetRegistry,
        address _protocolStatus,
        bytes32 _gardenType
    )
        payable {
        // Validate critical addresses
        if (_contractOwner == address(0)) {
            revert Garden_ContractOwnerIsZero();
        }
        if (_facetRegistry == address(0)) {
            revert Garden_FacetRegistryNotSet();
        }
        if (_protocolStatus == address(0)) {
            revert Garden_ProtocolStatusNotSet();
        }

        IFacetRegistry registry = IFacetRegistry(_facetRegistry);

        // Validate garden type is registered
        if (!registry.isGardenTypeRegistered(_gardenType)) {
            revert Garden_GardenTypeNotRegistered();
        }

        // Set contract owner
        OwnershipStorage.layout().owner = _contractOwner;

        LibDiamond.Layout storage ld = LibDiamond.layout();
        // Initialize diamond storage with registry addresses and garden type
        ld.facetRegistry = _facetRegistry;
        ld.protocolStatus = _protocolStatus;
        ld.gardenType = _gardenType;

        // Apply initial diamond cuts (BASE facets only - utility modules installed via upgrade())
        _applyDiamondCut(_diamondCut, address(0), "");

        DiamondLoupeStorage.Layout storage ls = DiamondLoupeStorage.layout();
        ls.supportedInterfaces[type(IERC165).interfaceId] = true;
        ls.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ls.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ls.supportedInterfaces[type(IERC173).interfaceId] = true;
        ls.supportedInterfaces[type(IUpgrade).interfaceId] = true;
        ls.supportedInterfaces[type(IERC721).interfaceId] = true;
        ls.supportedInterfaces[type(IERC721Metadata).interfaceId] = true;
        ls.supportedInterfaces[type(IERC721Errors).interfaceId] = true;
    }

    // ========================================================================
    // Fallback and Receive Functions
    // ========================================================================

    /// @notice Fallback function that routes function calls to appropriate facets
    /// @dev Implements the core Diamond proxy pattern:
    ///      1. Loads diamond storage from a fixed slot position
    ///      2. Looks up the facet address for the called function selector
    ///      3. Validates the selector exists in the diamond (facet != address(0))
    ///      4. Validates the selector is registered in the FacetRegistry for security
    ///      5. Executes the function call via delegatecall to the facet
    ///
    ///      The registry validation provides defense-in-depth by ensuring only registered
    ///      facets can execute, even if the diamond's internal state becomes inconsistent.
    fallback() external payable {
        LibDiamond.Layout storage ld = LibDiamond.layout();

        IProtocolStatus.State status = IProtocolStatus(ld.protocolStatus).getProtocolStatus();
        if (status == IProtocolStatus.State.INACTIVE) {
            revert Garden_ProtocolIsInactive();
        }
        if (status == IProtocolStatus.State.UPGRADES_DISABLED) {
            if (msg.sig == IUpgrade.upgrade.selector) {
                revert Garden_UpgradesDisabled();
            }
        }

        // Load diamond cut storage
        DiamondCutStorage.Layout storage ds = DiamondCutStorage.layout();

        // Load facet address for the called function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;

        // Single external call: validate selector registration, facet mapping, and module allowance
        (address registeredFacet, bool moduleAllowed) =
            IFacetRegistry(ld.facetRegistry).validateSelector(msg.sig, ld.gardenType);

        // Validate selector exists in diamond (fast fail for non-existent selectors)
        if (facet == address(0)) {
            if (registeredFacet != address(0)) {
                revert Garden_SelectorNotInGarden(msg.sig);
            } else {
                revert Garden_InvalidCall(msg.sig);
            }
        } else {
            if (registeredFacet == address(0)) {
                revert Garden_SelectorRemoved(msg.sig);
            }
            if (registeredFacet != facet) {
                revert Garden_SelectorMoved(msg.sig);
            }
        }

        // Defense-in-depth: validate the selector's module is allowed for this garden type
        if (ld.gardenType != bytes32(0) && !moduleAllowed) {
            revert Garden_ModuleNotAllowed(msg.sig);
        }

        // Execute external function from facet using delegatecall and return any value
        assembly {
            // Copy function selector and any arguments to memory at position 0
            calldatacopy(0, 0, calldatasize())

            // Execute function call using delegatecall to the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)

            // Get any return value from the delegatecall
            returndatacopy(0, 0, returndatasize())

            // Return any return value or error back to the caller
            switch result
            case 0 { revert(0, returndatasize()) }
            // If delegatecall failed, revert with returned error
            default { return(0, returndatasize()) } // If delegatecall succeeded, return the result
        }
    }

    /// @notice Receive function to accept plain ETH transfers
    /// @dev Allows the Diamond contract to receive ETH directly
    receive() external payable { }
}
