// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title Diamond
    @author BLOK Capital DAO (based on EIP-2535 by Nick Mudge)
    @notice Implementation of a Diamond proxy following EIP-2535 Diamonds standard
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
import { OwnershipStorage } from "src/diamond/facets/baseFacets/ownership/OwnershipStorage.sol";
import { DiamondCutStorage } from "src/diamond/facets/baseFacets/cut/DiamondCutStorage.sol";
import { DiamondCutBase } from "src/diamond/facets/baseFacets/cut/DiamondCutBase.sol";
import { DiamondLoupeStorage } from "src/diamond/facets/baseFacets/loupe/DiamondLoupeStorage.sol";
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

// Local Interfaces
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IUpgrade } from "src/diamond/facets/baseFacets/upgrade/IUpgrade.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

// ============================================================================
// Errors
// ============================================================================

/// @param selector The function selector that was attempted
error Diamond_InvalidCallToDiamond(bytes4 selector);

/// @notice Thrown when facet registry address is not set or is zero
error Diamond_FacetRegistryNotSet();

/// @notice Thrown when protocol status address is not set or is zero
error Diamond_ProtocolStatusNotSet();

/// @notice Thrown when contract owner address is zero
error Diamond_ContractOwnerIsZero();

/// @param selector The function selector that requires upgrade
error Diamond_SelectorNotInDiamond(bytes4 selector);

/// @param selector The function selector that was removed
error Diamond_SelectorRemoved(bytes4 selector);

/// @param selector The function selector that was moved
error Diamond_SelectorMoved(bytes4 selector);

/// @notice Thrown when upgrades are disabled
error Diamond_UpgradesDisabled();

/// @notice Thrown when protocol is inactive
error Diamond_ProtocolIsInactive();

contract Diamond is DiamondCutBase {
    // ========================================================================
    // Constructor
    // ========================================================================

    /// @notice Constructs the Diamond contract with initial facets and configuration
    /// @dev Validates all critical addresses are non-zero and initializes the diamond with base facets.
    ///      The facet registry validation during diamondCut ensures only registered facets can be added.
    /// @param _diamondCut Array of facet cuts to apply during initialization
    /// @param _contractOwner Address that will own the diamond contract
    constructor(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _contractOwner,
        address _facetRegistry,
        address _protocolStatus
    )
        payable
    {
        // Validate critical addresses
        if (_contractOwner == address(0)) {
            revert Diamond_ContractOwnerIsZero();
        }
        if (_facetRegistry == address(0)) {
            revert Diamond_FacetRegistryNotSet();
        }
        if (_protocolStatus == address(0)) {
            revert Diamond_ProtocolStatusNotSet();
        }

        // Set contract owner
        OwnershipStorage.layout().owner = _contractOwner;

        LibDiamond.Layout storage ld = LibDiamond.layout();
        // Initialize diamond storage with registry addresses
        ld.facetRegistry = _facetRegistry;
        ld.protocolStatus = _protocolStatus;
        // Apply initial diamond cuts (validates against registry)
        _applyDiamondCut(_diamondCut, address(0), "");

        DiamondLoupeStorage.Layout storage ls = DiamondLoupeStorage.layout();
        ls.supportedInterfaces[type(IERC165).interfaceId] = true;
        ls.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ls.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ls.supportedInterfaces[type(IERC173).interfaceId] = true;
        ls.supportedInterfaces[type(IUpgrade).interfaceId] = true;
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

        IProtocolStatus protocolStatus = IProtocolStatus(ld.protocolStatus);
        if (protocolStatus.getProtocolStatus() == IProtocolStatus.State.INACTIVE) {
            revert Diamond_ProtocolIsInactive();
        }
        if (protocolStatus.getProtocolStatus() == IProtocolStatus.State.UPGRADES_DISABLED) {
            if (msg.sig == IUpgrade.upgrade.selector) {
                revert Diamond_UpgradesDisabled();
            }
        }

        // Load diamond cut storage
        DiamondCutStorage.Layout storage ds = DiamondCutStorage.layout();

        // Load facet address for the called function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;

        // Load facet registry
        IFacetRegistry facetRegistry = IFacetRegistry(ld.facetRegistry);

        // Validate selector exists in diamond (fast fail for non-existent selectors)
        if (facet == address(0)) {
            if (facetRegistry.isSelectorRegistered(msg.sig)) {
                revert Diamond_SelectorNotInDiamond(msg.sig);
            } else {
                revert Diamond_InvalidCallToDiamond(msg.sig);
            }
        } else {
            if (!facetRegistry.isSelectorRegistered(msg.sig)) {
                revert Diamond_SelectorRemoved(msg.sig);
            }
            if (!facetRegistry.isSelectorRegisteredWithFacet(facet, msg.sig)) {
                revert Diamond_SelectorMoved(msg.sig);
            }
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
