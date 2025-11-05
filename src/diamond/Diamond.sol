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

/**
 * @author Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 */

// Local Libraries
import { LibDiamond } from "./libraries/LibDiamond.sol";

// Local Interfaces
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/IDiamondLoupe.sol";
import { IUpgrade } from "src/interfaces/IUpgrade.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when a function call is made to an invalid facet or selector
/// @param facet The facet address that was attempted (may be address(0) if selector doesn't exist)
/// @param selector The function selector that was attempted
error Diamond_InvalidCallToDiamond(address facet, bytes4 selector);

/// @notice Thrown when facet registry address is not set or is zero
error Diamond_FacetRegistryNotSet();

/// @notice Thrown when protocol status address is not set or is zero
error Diamond_ProtocolStatusNotSet();

/// @notice Thrown when liquidity pool registry address is not set or is zero
error Diamond_LiquidityPoolRegistryNotSet();

/// @notice Thrown when contract owner address is zero
error Diamond_ContractOwnerIsZero();

/// @notice Thrown when selector exists in registry but not in diamond (upgrade required)
/// @param facet The facet address (address(0) when selector not in diamond)
/// @param selector The function selector that requires upgrade
error Diamond_SelectorNotInDiamond(address facet, bytes4 selector);

/// @notice Thrown when selector was removed from registry (upgrade required)
/// @param facet The facet address that was attempted
/// @param selector The function selector that was removed
error Diamond_SelectorRemoved(address facet, bytes4 selector);

/// @notice Thrown when selector moved to different facet in registry (upgrade required)
/// @param facet The facet address that was attempted
/// @param selector The function selector that was moved
error Diamond_SelectorMoved(address facet, bytes4 selector);

/// @notice Thrown when upgrades are disabled
error Diamond_UpgradesDisabled();

/// @notice Thrown when protocol is inactive
error Diamond_ProtocolIsInactive();

// ============================================================================
// Diamond
// ============================================================================

/**
 * @title Diamond
 * @notice Diamond proxy contract implementing EIP-2535 with additional registry validation
 * @dev This contract follows the EIP-2535 Diamond standard with custom additions:
 *      1. Registry validation on every function call to ensure only registered facets/selectors execute
 *      2. Validation of critical addresses during construction
 *      3. Enhanced error handling for better debugging
 *
 *      The fallback function:
 *      - Looks up the facet for the called function selector
 *      - Validates the selector exists in the diamond (facet != address(0))
 *      - Validates the selector is registered in the FacetRegistry
 *      - Executes the function via delegatecall to the facet
 */
contract Diamond {
    // ========================================================================
    // Constructor
    // ========================================================================

    /**
     * @notice Constructs the Diamond contract with initial facets and configuration
     * @dev Validates all critical addresses are non-zero and initializes the diamond with base facets.
     *      The facet registry validation during diamondCut ensures only registered facets can be added.
     * @param _diamondCut Array of facet cuts to apply during initialization
     * @param _contractOwner Address that will own the diamond contract
     * @param _protocolStatus Address of the ProtocolStatus contract (kill switch)
     * @param _facetRegistry Address of the FacetRegistry contract (must be non-zero)
     * @param _liquidityPoolRegistry Address of the LiquidityPoolRegistry contract
     */
    constructor(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _contractOwner,
        address _protocolStatus,
        address _facetRegistry,
        address _liquidityPoolRegistry
    )
        payable
    {
        // Validate critical addresses
        if (_contractOwner == address(0)) {
            revert Diamond_ContractOwnerIsZero();
        }
        if (_protocolStatus == address(0)) {
            revert Diamond_ProtocolStatusNotSet();
        }
        if (_facetRegistry == address(0)) {
            revert Diamond_FacetRegistryNotSet();
        }
        if (_liquidityPoolRegistry == address(0)) {
            revert Diamond_LiquidityPoolRegistryNotSet();
        }

        // Set contract owner
        LibDiamond.setContractOwner(_contractOwner);

        // Initialize diamond storage with registry addresses
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.facetRegistry = _facetRegistry;
        ds.liquidityPoolRegistry = _liquidityPoolRegistry;
        ds.protocolStatus = _protocolStatus;

        // Apply initial diamond cuts (validates against registry in LibDiamond)
        LibDiamond.diamondCut(_diamondCut, address(0), "");

        // Register supported interfaces for ERC165
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        ds.supportedInterfaces[type(IUpgrade).interfaceId] = true;
    }

    // ========================================================================
    // Fallback and Receive Functions
    // ========================================================================

    /**
     * @notice Fallback function that routes function calls to appropriate facets
     * @dev This function implements the core Diamond proxy pattern:
     *      1. Loads diamond storage from a fixed slot position
     *      2. Looks up the facet address for the called function selector
     *      3. Validates the selector exists in the diamond (facet != address(0))
     *      4. Validates the selector is registered in the FacetRegistry for security
     *      5. Executes the function call via delegatecall to the facet
     *
     *      The registry validation provides defense-in-depth by ensuring only registered
     *      facets can execute, even if the diamond's internal state becomes inconsistent.
     *
     *      Gas optimization note: The registry check adds external call overhead but provides
     *      important security guarantees. The check is performed after confirming the selector
     *      exists in the diamond to fail fast on non-existent selectors.
     */
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;

        // Get diamond storage using assembly for gas efficiency
        assembly {
            ds.slot := position
        }

        IProtocolStatus protocolStatus = IProtocolStatus(ds.protocolStatus);
        if (protocolStatus.getProtocolStatus() == IProtocolStatus.State.INACTIVE) {
            revert Diamond_ProtocolIsInactive();
        }
        if (protocolStatus.getProtocolStatus() == IProtocolStatus.State.UPGRADES_DISABLED) {
            if (msg.sig == IUpgrade.upgrade.selector) {
                revert Diamond_UpgradesDisabled();
            }
        }

        // Look up facet address for the called function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;

        // Validate facet registry is set
        if (ds.facetRegistry == address(0)) {
            revert Diamond_FacetRegistryNotSet();
        }

        IFacetRegistry facetRegistry = IFacetRegistry(ds.facetRegistry);

        // Validate selector exists in diamond (fast fail for non-existent selectors)
        if (facet == address(0)) {
            if (facetRegistry.isSelectorRegistered(msg.sig)) {
                revert Diamond_SelectorNotInDiamond(address(0), msg.sig);
            } else {
                revert Diamond_InvalidCallToDiamond(address(0), msg.sig);
            }
        } else {
            if (!facetRegistry.isSelectorRegistered(msg.sig)) {
                revert Diamond_SelectorRemoved(facet, msg.sig);
            }
            if (!facetRegistry.isSelectorRegisteredWithFacet(facet, msg.sig)) {
                revert Diamond_SelectorMoved(facet, msg.sig);
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

    /**
     * @notice Receive function to accept plain ETH transfers
     * @dev Allows the Diamond contract to receive ETH directly
     */
    receive() external payable { }
}
