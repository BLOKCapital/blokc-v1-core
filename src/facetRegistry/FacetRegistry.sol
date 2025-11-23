// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title FacetRegistry
    @author BLOK Capital DAO
    @notice Registry contract that manages the registration and tracking of facets for Diamond proxy implementations.
    @dev FacetRegistry manages the registration and tracking of facets for a diamond proxy pattern implementation.
         Base facets cannot be modified once registered. The registry maintains version tracking for all modifications.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Upgradeable Contracts
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Local Interfaces
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when the facet address is not a contract
/// @param facetAddress The invalid facet address
error FacetRegistry_FacetIsNotContract(address facetAddress);

/// @notice Thrown when the function selector array is empty
error FacetRegistry_SelectorArrayEmpty();

/// @notice Thrown when an incorrect facet cut action is provided
/// @param action The incorrect facet cut action
error FacetRegistry_IncorrectFacetCutAction(IDiamondCut.FacetCutAction action);

/// @notice Thrown when the facet address is zero
error FacetRegistry_FacetAddressIsZero();

/// @notice Thrown when attempting to add a function selector that already exists
/// @param selector The function selector that already exists
error FacetRegistry_CannotAddFunctionThatAlreadyExists(bytes4 selector);

/// @notice Thrown when attempting to replace a function with the same function
/// @param facetAddress The facet address
/// @param selector The function selector
error FacetRegistry_CannotReplaceFunctionWithSameFunction(address facetAddress, bytes4 selector);

/// @notice Thrown when facet address must be zero for remove operations
/// @param facetAddress The non-zero facet address provided
error FacetRegistry_RemoveFacetAddressMustBeZero(address facetAddress);

/// @notice Thrown when attempting to remove a function that does not exist
/// @param facetAddress The facet address
/// @param selector The function selector that does not exist
error FacetRegistry_CannotRemoveFunctionThatDoesNotExist(address facetAddress, bytes4 selector);

/// @notice Thrown when attempting to remove an immutable function
/// @param facetAddress The facet address
/// @param selector The immutable function selector
error FacetRegistry_CannotRemoveImmutableFunction(address facetAddress, bytes4 selector);

/// @notice Thrown when the base facets array has incorrect length
/// @param length The incorrect length value
error FacetRegistry_IncorrectBaseFacetsLength(uint256 length);

/// @notice Thrown when attempting to modify a base facet
/// @param facetAddress The base facet address that cannot be modified
error FacetRegistry_CannotModifyBaseFacet(address facetAddress);

// ============================================================================
// FacetRegistry
// ============================================================================

/**
 * @title FacetRegistry
 * @notice Registry contract that manages the registration and tracking of facets for Diamond proxy implementations
 * @dev FacetRegistry manages the registration and tracking of facets for a diamond proxy pattern implementation.
 *      Base facets cannot be modified once registered. The registry maintains version tracking for all modifications.
 */
contract FacetRegistry is Initializable, OwnableUpgradeable, IFacetRegistry {
    // ========================================================================
    // State Variables
    // ========================================================================

    /// @notice Current version of the registry (increments with each modification)
    uint256 private _currentVersion;

    /// @notice Array of all registered facet addresses
    address[] private _facetAddresses;

    /// @notice Array of 4 base facet addresses that cannot be modified
    address[4] private _baseFacets;

    /// @notice Mapping from function selector to facet address and position
    mapping(bytes4 => FacetAddressAndPosition) private _selectorToFacetAndPosition;

    /// @notice Mapping from facet address to its function selectors
    mapping(address => FacetFunctionSelectors) private _facetFunctionSelectors;

    mapping(uint256 version => IDiamondCut.FacetCut facetCut) private _facetCutByVersion;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when the registry is initialized
    /// @param owner The owner of the registry
    /// @param baseFacets The base facets that were registered
    /// @param functionSelectors The function selectors that were registered
    event FacetRegistryInitialized(address indexed owner, address[4] indexed baseFacets, bytes4[][] functionSelectors);

    /// @notice Emitted when a facet is added, removed, or replaced
    /// @param facetAddress The address of the facet that had function selectors added
    /// @param oldVersion The version of the registry when the function selectors were added
    /// @param newVersion The version of the registry when the function selectors were added
    /// @param functionSelectors The function selectors that were added
    event FacetRegistryFunctionsAdded(
        address indexed facetAddress, uint256 indexed oldVersion, uint256 indexed newVersion, bytes4[] functionSelectors
    );

    /// @notice Emitted when function selectors are removed from a facet
    /// @param facetAddress The address of the facet that had function selectors removed
    /// @param oldVersion The version of the registry when the function selectors were removed
    /// @param newVersion The version of the registry when the function selectors were removed
    /// @param functionSelectors The function selectors that were removed
    event FacetRegistryFunctionsRemoved(
        address indexed facetAddress, uint256 indexed oldVersion, uint256 indexed newVersion, bytes4[] functionSelectors
    );

    /// @notice Emitted when function selectors are replaced from one facet to another
    /// @param oldVersion The version of the registry when the function selectors were replaced
    /// @param newVersion The version of the registry when the function selectors were replaced
    /// @param facetAddress The address of the facet that had function selectors replaced
    /// @param functionSelectors The function selectors that were replaced
    event FacetRegistryFunctionsReplaced(
        uint256 indexed oldVersion, uint256 indexed newVersion, address indexed facetAddress, bytes4[] functionSelectors
    );

    // ========================================================================
    // Constructor
    // ========================================================================

    /// @notice Disables initialization of the implementation contract
    /// @dev This prevents the implementation from being initialized directly
    constructor() {
        _disableInitializers();
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    /**
     * @notice Initializes the registry contract
     * @dev This function should be called during proxy deployment via the proxy's initialization mechanism
     * @param initialOwner The address that will be the owner of this registry
     * @param baseFacets Array of 4 base facet addresses
     * @param functionSelectors 2D array of function selectors corresponding to each base facet
     */
    function initialize(
        address initialOwner,
        address[4] memory baseFacets,
        bytes4[][] memory functionSelectors
    )
        public
        initializer
    {
        __Ownable_init(initialOwner);

        for (uint8 i = 0; i < baseFacets.length; i++) {
            if (baseFacets[i] == address(0)) {
                revert FacetRegistry_FacetAddressIsZero();
            }
            _baseFacets[i] = baseFacets[i];
            _addBaseFacet(baseFacets[i], functionSelectors[i]);
        }

        emit FacetRegistryInitialized(initialOwner, baseFacets, functionSelectors);
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /**
     * @notice Adds function selectors to a facet
     * @dev If the facet is new, it will be added to the registry. Cannot add functions to base facets.
     * @param _facetAddress The address of the facet contract
     * @param _functionSelectors Array of function selectors to add
     */
    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external onlyOwner {
        if (_functionSelectors.length == 0) {
            revert FacetRegistry_SelectorArrayEmpty();
        }
        if (_facetAddress == address(0)) {
            revert FacetRegistry_FacetAddressIsZero();
        }

        // Prevent modification of base facets
        for (uint256 i = 0; i < _baseFacets.length; i++) {
            if (_facetAddress == _baseFacets[i]) {
                revert FacetRegistry_CannotModifyBaseFacet(_facetAddress);
            }
        }

        uint96 selectorPosition = uint96(_facetFunctionSelectors[_facetAddress].functionSelectors.length);
        if (selectorPosition == 0) {
            _addFacet(_facetAddress);
        }

        for (uint256 selectorIndex = 0; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = _selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert FacetRegistry_CannotAddFunctionThatAlreadyExists(selector);
            }
            _addFunction(selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
        _currentVersion++;
        _facetCutByVersion[_currentVersion] = IDiamondCut.FacetCut({
            facetAddress: _facetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _functionSelectors
        });
        emit FacetRegistryFunctionsAdded(_facetAddress, _currentVersion - 1, _currentVersion, _functionSelectors);
    }

    /**
     * @notice Replaces function selectors from old facet to new facet
     * @dev Cannot replace functions in base facets. If the new facet is not registered, it will be added.
     * @param _facetAddress The address of the destination facet contract
     * @param _functionSelectors Array of function selectors to replace
     */
    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external onlyOwner {
        if (_functionSelectors.length == 0) {
            revert FacetRegistry_SelectorArrayEmpty();
        }
        if (_facetAddress == address(0)) {
            revert FacetRegistry_FacetAddressIsZero();
        }

        // Prevent modification of base facets
        for (uint256 i = 0; i < _baseFacets.length; i++) {
            if (_facetAddress == _baseFacets[i]) {
                revert FacetRegistry_CannotModifyBaseFacet(_facetAddress);
            }
        }

        uint96 selectorPosition = uint96(_facetFunctionSelectors[_facetAddress].functionSelectors.length);
        if (selectorPosition == 0) {
            _addFacet(_facetAddress);
        }

        for (uint256 selectorIndex = 0; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = _selectorToFacetAndPosition[selector].facetAddress;

            if (oldFacetAddress == _facetAddress) {
                revert FacetRegistry_CannotReplaceFunctionWithSameFunction(oldFacetAddress, selector);
            }

            // Prevent modification of base facets
            for (uint256 j = 0; j < _baseFacets.length; j++) {
                if (oldFacetAddress == _baseFacets[j]) {
                    revert FacetRegistry_CannotModifyBaseFacet(oldFacetAddress);
                }
            }

            _removeFunction(oldFacetAddress, selector);
            _addFunction(selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }

        _currentVersion++;
        _facetCutByVersion[_currentVersion] = IDiamondCut.FacetCut({
            facetAddress: _facetAddress,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: _functionSelectors
        });
        emit FacetRegistryFunctionsReplaced(_currentVersion - 1, _currentVersion, _facetAddress, _functionSelectors);
    }

    /**
     * @notice Removes function selectors from the registry
     * @dev The _facetAddress parameter must be address(0) for remove operations. Cannot remove functions from base
     * facets.
     * @param _facetAddress Must be address(0) for remove operations
     * @param _functionSelectors Array of function selectors to remove
     */
    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external onlyOwner {
        if (_functionSelectors.length == 0) {
            revert FacetRegistry_SelectorArrayEmpty();
        }
        if (_facetAddress != address(0)) {
            revert FacetRegistry_RemoveFacetAddressMustBeZero(_facetAddress);
        }

        for (uint256 selectorIndex = 0; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = _selectorToFacetAndPosition[selector].facetAddress;

            // Prevent modification of base facets
            for (uint256 i = 0; i < _baseFacets.length; i++) {
                if (oldFacetAddress == _baseFacets[i]) {
                    revert FacetRegistry_CannotModifyBaseFacet(oldFacetAddress);
                }
            }

            _removeFunction(oldFacetAddress, selector);
        }

        _currentVersion++;
        _facetCutByVersion[_currentVersion] = IDiamondCut.FacetCut({
            facetAddress: _facetAddress,
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: _functionSelectors
        });
        emit FacetRegistryFunctionsRemoved(_facetAddress, _currentVersion - 1, _currentVersion, _functionSelectors);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /**
     * @notice Returns all registered facets with their function selectors
     * @return facets_ Array of facet structs containing addresses and selectors
     */
    function getFacets() external view returns (Facet[] memory facets_) {
        uint256 numFacets = _facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i = 0; i < numFacets; i++) {
            address facetAddress_ = _facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = _facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /**
     * @notice Returns all function selectors for a specific facet
     * @param _facet The address of the facet contract
     * @return selectors Array of function selectors for the facet
     */
    function getFacetFunctionSelectors(address _facet) external view returns (bytes4[] memory selectors) {
        selectors = _facetFunctionSelectors[_facet].functionSelectors;
    }

    /**
     * @notice Returns all registered facet addresses
     * @return facetAddresses_ Array of facet addresses
     */
    function getFacetAddresses() external view returns (address[] memory facetAddresses_) {
        facetAddresses_ = _facetAddresses;
    }

    /**
     * @notice Returns the facet address for a specific function selector
     * @param _functionSelector The function selector to look up
     * @return facetAddress_ The address of the facet implementing this selector
     */
    function getFacetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {
        facetAddress_ = _selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    /**
     * @notice Returns all base facet addresses
     * @return baseFacets_ Array of 4 base facet addresses
     */
    function getBaseFacets() external view returns (address[4] memory baseFacets_) {
        baseFacets_ = _baseFacets;
    }

    /**
     * @notice Returns the facet cuts for the version range
     * @param _startVersion The start version
     * @param _endVersion The end version
     * @return facetCuts The facet cuts for the version range
     */
    function getFacetCutsByVersionRange(
        uint256 _startVersion,
        uint256 _endVersion
    )
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts)
    {
        facetCuts = new IDiamondCut.FacetCut[](_endVersion - _startVersion + 1);
        for (uint256 i = _startVersion; i <= _endVersion; i++) {
            facetCuts[i - _startVersion] = _facetCutByVersion[i];
        }
    }

    /**
     * @notice Checks if a facet address is registered
     * @param _facet The address of the facet to check
     * @return True if the facet is registered, false otherwise
     */
    function isFacetRegistered(address _facet) external view returns (bool) {
        uint256 numFacets = _facetAddresses.length;
        for (uint256 i = 0; i < numFacets; i++) {
            if (_facet == _facetAddresses[i]) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Checks if a function selector is registered
     * @param _functionSelector The function selector to check
     * @return True if the selector is registered, false otherwise
     */
    function isSelectorRegistered(bytes4 _functionSelector) external view returns (bool) {
        return _selectorToFacetAndPosition[_functionSelector].facetAddress != address(0);
    }

    /**
     * @notice Checks if a function selector is registered for a specific facet
     * @param _facet The address of the facet to check
     * @param _functionSelector The function selector to check
     * @return True if the selector is registered for the facet, false otherwise
     */
    function isSelectorRegisteredWithFacet(address _facet, bytes4 _functionSelector) external view returns (bool) {
        if (_facet == address(0)) {
            revert FacetRegistry_FacetAddressIsZero();
        }
        address facetAddress_ = _selectorToFacetAndPosition[_functionSelector].facetAddress;
        return facetAddress_ == _facet;
    }

    /**
     * @notice Returns the current version of the registry
     * @return The current version number
     */
    function getCurrentVersion() external view returns (uint256) {
        return _currentVersion;
    }

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /**
     * @notice Adds a base facet with its function selectors
     * @dev Called during initialization to register base facets
     * @param _facetAddress The address of the base facet contract
     * @param _functionSelectors Array of function selectors for the base facet
     */
    function _addBaseFacet(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_facetAddress.code.length == 0) {
            revert FacetRegistry_FacetIsNotContract(_facetAddress);
        }

        _facetFunctionSelectors[_facetAddress].facetAddressPosition = _facetAddresses.length;
        _facetAddresses.push(_facetAddress);

        for (uint256 selectorIndex = 0; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            _addFunction(selector, uint96(selectorIndex), _facetAddress);
        }
    }

    /**
     * @notice Adds a new facet address to the registry
     * @param _facetAddress The address of the facet contract to add
     */
    function _addFacet(address _facetAddress) internal {
        if (_facetAddress.code.length == 0) {
            revert FacetRegistry_FacetIsNotContract(_facetAddress);
        }

        _facetFunctionSelectors[_facetAddress].facetAddressPosition = _facetAddresses.length;
        _facetAddresses.push(_facetAddress);
    }

    /**
     * @notice Adds a function selector to a facet
     * @param _selector The function selector to add
     * @param _selectorPosition The position in the facet's selector array
     * @param _facetAddress The address of the facet contract
     */
    function _addFunction(bytes4 _selector, uint96 _selectorPosition, address _facetAddress) internal {
        _selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        _facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        _selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    /**
     * @notice Removes a function selector from a facet
     * @param _facetAddress The address of the facet contract
     * @param _selector The function selector to remove
     */
    function _removeFunction(address _facetAddress, bytes4 _selector) internal {
        if (_facetAddress == address(0)) {
            revert FacetRegistry_CannotRemoveFunctionThatDoesNotExist(_facetAddress, _selector);
        }
        if (_facetAddress == address(this)) {
            revert FacetRegistry_CannotRemoveImmutableFunction(_facetAddress, _selector);
        }

        uint256 selectorPosition = _selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = _facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;

        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = _facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            _facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            _selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }

        _facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete _selectorToFacetAndPosition[_selector];

        // Remove facet if it has no more selectors
        if (_facetFunctionSelectors[_facetAddress].functionSelectors.length == 0) {
            uint256 lastFacetAddressPosition = _facetAddresses.length - 1;
            uint256 facetAddressPosition = _facetFunctionSelectors[_facetAddress].facetAddressPosition;

            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = _facetAddresses[lastFacetAddressPosition];
                _facetAddresses[facetAddressPosition] = lastFacetAddress;
                _facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }

            _facetAddresses.pop();
            delete _facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }
}
