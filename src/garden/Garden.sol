// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

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

/// @notice Thrown when a function selector has no registered facet in the diamond or the registry.
/// @param selector The function selector that was attempted.
error Garden_InvalidCall(bytes4 selector);

/// @notice Thrown when facet registry address is not set or is zero
error Garden_FacetRegistryNotSet();

/// @notice Thrown when protocol status address is not set or is zero
error Garden_ProtocolStatusNotSet();

/// @notice Thrown when contract owner address is zero
error Garden_ContractOwnerIsZero();

/// @notice Thrown when a selector is registered in the FacetRegistry but not yet installed in this Garden.
/// @param selector The function selector that requires an upgrade to install.
error Garden_SelectorNotInGarden(bytes4 selector);

/// @notice Thrown when a selector exists in the Garden but was removed from the FacetRegistry.
/// @param selector The function selector that was removed.
error Garden_SelectorRemoved(bytes4 selector);

/// @notice Thrown when the Garden's facet for a selector differs from the registry's facet (needs upgrade).
/// @param selector The function selector whose facet mapping is stale.
error Garden_SelectorMoved(bytes4 selector);

/// @notice Thrown when upgrades are disabled
error Garden_UpgradesDisabled();

/// @notice Thrown when protocol is inactive
error Garden_ProtocolIsInactive();

/// @notice Thrown when the garden type is not registered
error Garden_GardenTypeNotRegistered();

/// @notice Thrown when a facet address has no deployed code at call time
/// @param facet The facet address that has no code
error Garden_FacetHasNoCode(address facet);

/// @notice Thrown when a selector's module is not allowed for the garden's type
/// @param selector The function selector whose module is not allowed
error Garden_ModuleNotAllowed(bytes4 selector);

/**
 * @title Garden
 * @author BLOK Capital DAO(EIP-2535 Diamond Proxy)
 * @notice The main Diamond contract for the garden, implementing the core proxy logic and enforcing access control.
 * This contract implements the Diamond proxy pattern, routing function calls to the appropriate facets based on
 * the function selector. It includes a constructor for initializing the diamond with initial facets and configuration
 * and a fallback function that performs the routing logic. The contract also includes comprehensive error handling
 * for various edge cases related to facet registration, protocol status, and access control.
 */
contract Garden is DiamondCutBase {
    // ========================================================================
    // Constructor
    // ========================================================================

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

    /// @notice Fallback function that routes calls to the appropriate facet based on the function selector
    /// @dev Validates protocol status, selector registration, facet mapping, and module allowance before
    ///      executing the call via delegatecall. Implements defense-in-depth checks for selector validity
    ///      and module permissions. Reverts with detailed errors for various failure cases.
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

        // Defense-in-depth: ensure the facet address still contains code.
        // Between facet installation and call time, a facet could lose its code
        // (e.g. via SELFDESTRUCT in a constructor before Cancun, or a misconfigured
        // upgrade). This check prevents silent success with empty return data.
        if (facet.code.length == 0) revert Garden_FacetHasNoCode(facet);

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
