//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { DiamondCutStorage } from "src/garden/facets/baseFacets/cut/DiamondCutStorage.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

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
error DiamondCut_CannotRemoveImmutableFunction(address facetAddress);

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

/// @notice Thrown when initialization is not allowed
error DiamondCut_InitializationNotAllowed();

/// @notice Thrown when an initialization function reverts
/// @param _initializationContractAddress The address of the initialization contract
/// @param _calldata The calldata that caused the revert
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

/// @notice Thrown when a facet address is not a contract
/// @param facetAddress The invalid facet address
error DiamondCut_FacetIsNotContract(address facetAddress);

/// @notice Thrown when a facet's module is not allowed for the garden's type
/// @param gardenType The garden type identifier
/// @param moduleId The module that is not allowed
error DiamondCut_ModuleNotAllowedForGardenType(bytes32 gardenType, bytes32 moduleId);

/// @notice Thrown when the function selector array is empty
error DiamondCut_SelectorArrayEmpty();

/**
 * @title DiamondCutBase
 * @notice Base contract that implements internal functions for adding, replacing, and removing facet functions
 * according to the EIP-2535 Diamond Standard. This contract is intended to be inherited by a DiamondCutFacet that
 * exposes the diamondCut function with appropriate access control and restrictions.
 */
contract DiamondCutBase {
    /// @notice Emitted when functions are added to a facet
    /// @param facetAddress The address of the facet
    /// @param functionSelectors The function selectors that were added
    event DiamondCutFunctionsAdded(address indexed facetAddress, bytes4[] functionSelectors);
    /// @notice Emitted when functions are replaced in a facet
    /// @param facetAddress The address of the facet
    /// @param functionSelectors The function selectors that were replaced
    event DiamondCutFunctionsReplaced(address indexed facetAddress, bytes4[] functionSelectors);
    /// @notice Emitted when functions are removed from a facet
    /// @param facetAddress The address of the facet
    /// @param functionSelectors The function selectors that were removed
    event DiamondCutFunctionsRemoved(address indexed facetAddress, bytes4[] functionSelectors);

    /**
     * @notice Internal function version of diamondCut that applies facet cuts
     * @dev Applies add, replace, and remove operations in sequence, then initializes if needed
     * @param _diamondCut Array of facet cuts to apply
     * @param _init The initialization contract address (optional)
     * @param _calldata The initialization calldata (optional)
     */
    function _applyDiamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    )
        internal
    {
        if (_init != address(0) || _calldata.length > 0) {
            revert DiamondCut_InitializationNotAllowed();
        }

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

        // Emit EIP-2535 standard event
        emit IDiamondCut.DiamondCut(_diamondCut, _init, _calldata);
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
        DiamondCutStorage.Layout storage ds = DiamondCutStorage.layout();
        if (_facetAddress == address(0)) {
            revert DiamondCut_FacetAddressIsZero();
        }

        LibDiamond.Layout storage ld = LibDiamond.layout();
        address facetRegistry = ld.facetRegistry;
        // Ensure facet is registered in the FacetRegistry
        if (!IFacetRegistry(facetRegistry).isFacetRegistered(_facetAddress)) {
            revert DiamondCut_FacetNotRegistered(_facetAddress);
        }

        // Ensure facet's module is allowed for this garden's type
        bytes32 gardenType = ld.gardenType;
        if (gardenType != bytes32(0)) {
            bytes32 moduleId = IFacetRegistry(facetRegistry).getFacetModule(_facetAddress);
            if (!IFacetRegistry(facetRegistry).isModuleAllowedForGardenType(gardenType, moduleId)) {
                revert DiamondCut_ModuleNotAllowedForGardenType(gardenType, moduleId);
            }
        }

        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // Add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];

            // Ensure selector is registered for the facet in the FacetRegistry
            if (!IFacetRegistry(facetRegistry).isSelectorRegisteredWithFacet(_facetAddress, selector)) {
                revert DiamondCut_SelectorNotRegistered(_facetAddress, selector);
            }

            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert DiamondCut_CannotAddFunctionThatAlreadyExists(selector);
            }

            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
        emit DiamondCutFunctionsAdded(_facetAddress, _functionSelectors);
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
        DiamondCutStorage.Layout storage ds = DiamondCutStorage.layout();
        LibDiamond.Layout storage ld = LibDiamond.layout();
        address facetRegistry = ld.facetRegistry;
        if (_facetAddress == address(0)) {
            revert DiamondCut_FacetAddressIsZero();
        }
        // Ensure facet is registered in the FacetRegistry
        if (!IFacetRegistry(facetRegistry).isFacetRegistered(_facetAddress)) {
            revert DiamondCut_FacetNotRegistered(_facetAddress);
        }

        // Ensure facet's module is allowed for this garden's type
        bytes32 gardenType = ld.gardenType;
        if (gardenType != bytes32(0)) {
            bytes32 moduleId = IFacetRegistry(facetRegistry).getFacetModule(_facetAddress);
            if (!IFacetRegistry(facetRegistry).isModuleAllowedForGardenType(gardenType, moduleId)) {
                revert DiamondCut_ModuleNotAllowedForGardenType(gardenType, moduleId);
            }
        }

        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // Add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];

            // Ensure selector is registered for the facet in the FacetRegistry
            if (!IFacetRegistry(facetRegistry).isSelectorRegisteredWithFacet(_facetAddress, selector)) {
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
        emit DiamondCutFunctionsReplaced(_facetAddress, _functionSelectors);
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
        DiamondCutStorage.Layout storage ds = DiamondCutStorage.layout();
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
        emit DiamondCutFunctionsRemoved(_facetAddress, _functionSelectors);
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
    function addFacet(DiamondCutStorage.Layout storage ds, address _facetAddress) internal {
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
        DiamondCutStorage.Layout storage ds,
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
    function removeFunction(DiamondCutStorage.Layout storage ds, address _facetAddress, bytes4 _selector) internal {
        LibDiamond.Layout storage ld = LibDiamond.layout();
        if (_facetAddress == address(0)) {
            revert DiamondCut_CannotRemoveFunctionThatDoesNotExist(_facetAddress, _selector);
        }

        // Ensure selector is NOT registered in the FacetRegistry (can only remove unregistered selectors)
        if (IFacetRegistry(ld.facetRegistry).isSelectorRegisteredWithFacet(_facetAddress, _selector)) {
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
}
