// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title LibDiamond
    @author BLOK Capital DAO (based on EIP-2535 by Nick Mudge)
    @notice Library for managing Diamond proxy storage and operations
    @dev This library implements the core Diamond proxy pattern following EIP-2535.
         It manages facet registration, function selector mapping, and diamond cuts.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

/**
 * @author Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 */

// OpenZeppelin Contracts
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

// Local Interfaces
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when an initialization function reverts
/// @param _initializationContractAddress The address of the initialization contract
/// @param _calldata The calldata that caused the revert
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

/// @notice Thrown when a facet address is not a contract
/// @param facetAddress The invalid facet address
error DiamondCut_FacetIsNotContract(address facetAddress);

/// @notice Thrown when the function selector array is empty
error DiamondCut_SelectorArrayEmpty();

/// @notice Thrown when the caller is not the contract owner
/// @param caller The address that attempted the operation
/// @param owner The address that owns the contract
error CallerNotOwner(address caller, address owner);

/// @notice Thrown when an incorrect facet cut action is provided
/// @param action The incorrect facet cut action
error DiamondCut_IncorrectFacetCutAction(IDiamondCut.FacetCutAction action);

/// @notice Thrown when the facet address is zero
error DiamondCut_FacetAddressIsZero();

/// @notice Thrown when attempting to add a function selector that already exists
/// @param selector The function selector that already exists
error DiamondCut_CannotAddFunctionThatAlreadyExists(bytes4 selector);

/// @notice Thrown when attempting to replace a function with the same function
/// @param facetAddress The facet address
/// @param selector The function selector
error DiamondCut_CannotReplaceFunctionWithSameFunction(address facetAddress, bytes4 selector);

/// @notice Thrown when facet address must be zero for remove operations
/// @param facetAddress The non-zero facet address provided
error DiamondCut_RemoveFacetAddressMustBeZero(address facetAddress);

/// @notice Thrown when attempting to remove a function that does not exist
/// @param facetAddress The facet address
/// @param selector The function selector that does not exist
error DiamondCut_CannotRemoveFunctionThatDoesNotExist(address facetAddress, bytes4 selector);

/// @notice Thrown when attempting to remove an immutable function
/// @param facetAddress The facet address
/// @param selector The immutable function selector
error DiamondCut_CannotRemoveImmutableFunction(address facetAddress, bytes4 selector);

/// @notice Thrown when the initialization contract is not a contract
/// @param init The invalid initialization contract address
error DiamondCut_InitIsNotContract(address init);

/// @notice Thrown when facet registry address is not set or is zero
error DiamondCut_FacetRegistryNotSet();

/// @notice Thrown when a facet is not registered in the FacetRegistry
/// @param facetAddress The unregistered facet address
error DiamondCut_FacetNotRegistered(address facetAddress);

/// @notice Thrown when a selector is not registered for a facet in the FacetRegistry
/// @param facetAddress The facet address
/// @param selector The unregistered function selector
error DiamondCut_SelectorNotRegistered(address facetAddress, bytes4 selector);

/// @notice Thrown when attempting to remove a selector that is still registered in the FacetRegistry
/// @param facetAddress The facet address
/// @param selector The registered function selector
error DiamondCut_SelectorRegisteredCannotRemove(address facetAddress, bytes4 selector);

// ============================================================================
// Library
// ============================================================================

library LibDiamond {
    // 32 bytes keccak hash of a string to use as a diamond storage location.
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
        // Registry of facets and selectors allowed to be added to the Diamond
        address facetRegistry;
        // Registry of the Liquidity Pools
        address liquidityPoolRegistry;
        // Kill switch
        address protocolStatus;
        // Version
        uint256 currentVersion;
    }

    // ========================================================================
    // Storage Access
    // ========================================================================

    /**
     * @notice Returns the diamond storage struct at the fixed storage position
     * @return ds The diamond storage struct
     */
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        // assigns struct storage slot to the storage position
        assembly {
            ds.slot := position
        }
    }

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when ownership is transferred
    /// @param previousOwner The previous owner address
    /// @param newOwner The new owner address
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when a diamond cut is performed
    /// @param _diamondCut Array of facet cuts applied
    /// @param _init The initialization contract address
    /// @param _calldata The initialization calldata
    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    // ========================================================================
    // Owner Management
    // ========================================================================

    /**
     * @notice Sets the contract owner
     * @param _newOwner The new owner address
     */
    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @notice Returns the contract owner
     * @return contractOwner_ The current contract owner address
     */
    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    /**
     * @notice Reverts if the caller is not the contract owner
     */
    function enforceIsContractOwner() internal view {
        address owner = diamondStorage().contractOwner;
        if (msg.sender != owner) {
            revert CallerNotOwner(msg.sender, owner);
        }
    }

    // ========================================================================
    // Registry Accessors
    // ========================================================================

    /**
     * @notice Returns the facet registry address
     * @return facetRegistry_ The facet registry address
     */
    function facetRegistry() internal view returns (address facetRegistry_) {
        facetRegistry_ = diamondStorage().facetRegistry;
    }

    /**
     * @notice Returns the liquidity pool registry address
     * @return liquidityPoolRegistry_ The liquidity pool registry address
     */
    function liquidityPoolRegistry() internal view returns (address liquidityPoolRegistry_) {
        liquidityPoolRegistry_ = diamondStorage().liquidityPoolRegistry;
    }

    /**
     * @notice Returns the current version
     * @return currentVersion_ The current version number
     */
    function currentVersion() internal view returns (uint256 currentVersion_) {
        currentVersion_ = diamondStorage().currentVersion;
    }

    /**
     * @notice Sets the current version
     * @param _newVersion The new version number
     */
    function setCurrentVersion(uint256 _newVersion) internal {
        DiamondStorage storage ds = diamondStorage();
        ds.currentVersion = _newVersion;
    }

    // ========================================================================
    // Diamond Cut Operations
    // ========================================================================

    /**
     * @notice Internal function version of diamondCut that applies facet cuts
     * @dev Applies add, replace, and remove operations in sequence, then initializes if needed
     * @param _diamondCut Array of facet cuts to apply
     * @param _init The initialization contract address (optional)
     * @param _calldata The initialization calldata (optional)
     */
    function diamondCut(IDiamondCut.FacetCut[] memory _diamondCut, address _init, bytes memory _calldata) internal {
        // Apply all facet cuts
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert DiamondCut_IncorrectFacetCutAction(action);
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    // ========================================================================
    // Add Functions
    // ========================================================================

    /**
     * @notice Adds new functions to the diamond from a facet
     * @dev Validates the facet and selectors are registered, checks for duplicates,
     *      and adds them to the diamond storage
     * @param _facetAddress The address of the facet contract
     * @param _functionSelectors Array of function selectors to add
     */
    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert DiamondCut_SelectorArrayEmpty();
        }
        DiamondStorage storage ds = diamondStorage();
        if (_facetAddress == address(0)) {
            revert DiamondCut_FacetAddressIsZero();
        }
        address registry = facetRegistry();
        if (registry == address(0)) {
            revert DiamondCut_FacetRegistryNotSet();
        }

        // Ensure facet is registered in the FacetRegistry
        if (!IFacetRegistry(registry).isFacetRegistered(_facetAddress)) {
            revert DiamondCut_FacetNotRegistered(_facetAddress);
        }

        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // Add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        // Check for duplicate selectors within the input array
        for (uint256 i; i < _functionSelectors.length; i++) {
            for (uint256 j = i + 1; j < _functionSelectors.length; j++) {
                if (_functionSelectors[i] == _functionSelectors[j]) {
                    revert DiamondCut_CannotAddFunctionThatAlreadyExists(_functionSelectors[i]);
                }
            }
        }

        // Process each selector
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];

            // Ensure selector is registered for the facet in the FacetRegistry
            if (!IFacetRegistry(registry).isSelectorRegisteredWithFacet(_facetAddress, selector)) {
                revert DiamondCut_SelectorNotRegistered(_facetAddress, selector);
            }

            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert DiamondCut_CannotAddFunctionThatAlreadyExists(selector);
            }

            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    // ========================================================================
    // Replace Functions
    // ========================================================================

    /**
     * @notice Replaces existing functions in the diamond with new implementations
     * @dev Validates the facet and selectors are registered, checks for duplicates,
     *      and replaces selectors with new facet implementations
     * @param _facetAddress The address of the new facet contract
     * @param _functionSelectors Array of function selectors to replace
     */
    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert DiamondCut_SelectorArrayEmpty();
        }
        DiamondStorage storage ds = diamondStorage();

        if (_facetAddress == address(0)) {
            revert DiamondCut_FacetAddressIsZero();
        }
        address registry = facetRegistry();
        if (registry == address(0)) {
            revert DiamondCut_FacetRegistryNotSet();
        }

        // Ensure facet is registered in the FacetRegistry
        if (!IFacetRegistry(registry).isFacetRegistered(_facetAddress)) {
            revert DiamondCut_FacetNotRegistered(_facetAddress);
        }

        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // Add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        // Check for duplicate selectors within the input array
        for (uint256 i; i < _functionSelectors.length; i++) {
            for (uint256 j = i + 1; j < _functionSelectors.length; j++) {
                if (_functionSelectors[i] == _functionSelectors[j]) {
                    revert DiamondCut_CannotReplaceFunctionWithSameFunction(_facetAddress, _functionSelectors[i]);
                }
            }
        }

        // Process each selector
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];

            // Ensure selector is registered for the facet in the FacetRegistry
            if (!IFacetRegistry(registry).isSelectorRegisteredWithFacet(_facetAddress, selector)) {
                revert DiamondCut_SelectorNotRegistered(_facetAddress, selector);
            }

            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == _facetAddress) {
                revert DiamondCut_CannotReplaceFunctionWithSameFunction(oldFacetAddress, selector);
            }

            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    // ========================================================================
    // Remove Functions
    // ========================================================================

    /**
     * @notice Removes functions from the diamond
     * @dev For remove operations, facet address must be zero. Validates selectors
     *      are not registered in the FacetRegistry before removal.
     * @param _facetAddress Must be address(0) for remove operations
     * @param _functionSelectors Array of function selectors to remove
     */
    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert DiamondCut_SelectorArrayEmpty();
        }
        DiamondStorage storage ds = diamondStorage();

        // For remove operations, facet address must be zero
        if (_facetAddress != address(0)) {
            revert DiamondCut_RemoveFacetAddressMustBeZero(_facetAddress);
        }

        // Process each selector
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    // ========================================================================
    // Internal Helper Functions
    // ========================================================================

    /**
     * @notice Adds a new facet address to the diamond storage
     * @dev Validates the facet is a contract and adds it to the facet addresses array
     * @param ds The diamond storage struct
     * @param _facetAddress The address of the facet contract
     */
    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        if (_facetAddress.code.length == 0) {
            revert DiamondCut_FacetIsNotContract(_facetAddress);
        }
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }

    /**
     * @notice Adds a function selector to a facet in the diamond storage
     * @param ds The diamond storage struct
     * @param _selector The function selector to add
     * @param _selectorPosition The position in the facet's selector array
     * @param _facetAddress The address of the facet contract
     */
    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    )
        internal
    {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    /**
     * @notice Removes a function selector from a facet in the diamond storage
     * @dev Uses swap-and-pop pattern for efficient removal. Removes the facet address
     *      if it has no more selectors remaining.
     * @param ds The diamond storage struct
     * @param _facetAddress The address of the facet contract
     * @param _selector The function selector to remove
     */
    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {
        if (_facetAddress == address(0)) {
            revert DiamondCut_CannotRemoveFunctionThatDoesNotExist(_facetAddress, _selector);
        }
        // An immutable function is a function defined directly in a diamond
        if (_facetAddress == address(this)) {
            revert DiamondCut_CannotRemoveImmutableFunction(_facetAddress, _selector);
        }

        address registry = facetRegistry();
        if (registry == address(0)) {
            revert DiamondCut_FacetRegistryNotSet();
        }

        // Ensure selector is NOT registered in the FacetRegistry (can only remove unregistered selectors)
        if (IFacetRegistry(registry).isSelectorRegisteredWithFacet(_facetAddress, _selector)) {
            revert DiamondCut_SelectorRegisteredCannotRemove(_facetAddress, _selector);
        }

        // Replace selector with last selector, then delete last selector (swap-and-pop pattern)
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;

        // If not the same position, swap with last selector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }

        // Remove the last selector
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // If no more selectors for facet address, remove the facet address
        if (ds.facetFunctionSelectors[_facetAddress].functionSelectors.length == 0) {
            // Replace facet address with last facet address and delete last facet address (swap-and-pop)
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    /**
     * @notice Initializes the diamond after a cut operation
     * @dev Uses delegatecall to execute initialization logic. The initialization contract
     *      runs in the context of the diamond, allowing it to set state variables.
     * @param init The initialization contract address (optional, can be address(0))
     * @param initData The initialization calldata (optional, can be empty)
     */
    function initializeDiamondCut(address init, bytes memory initData) internal {
        // If no init provided, nothing to do
        if (init == address(0)) {
            return;
        }

        // Init must be a contract
        if (init.code.length == 0) {
            revert DiamondCut_InitIsNotContract(init);
        }

        // Delegatecall into init contract with provided calldata
        // This runs the init contract's code in the diamond's context
        // OpenZeppelin's Address.functionDelegateCall handles revert reasons properly
        Address.functionDelegateCall(init, initData);
    }
}
