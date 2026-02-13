// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// Local Interfaces
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

// OpenZeppelin Standard Contracts
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// ========================================================================
//                              ERRORS
// ========================================================================

/// @notice Thrown when the facet address is not a contract
error FacetRegistry_FacetIsNotContract(address facetAddress);

/// @notice Thrown when the base facet address is zero
error FacetRegistry_BaseFacetAddressIsZero(address baseFacetAddress);

/// @notice Thrown when the function selector array is empty
error FacetRegistry_SelectorArrayEmpty();

/// @notice Thrown when an incorrect facet cut action is provided
error FacetRegistry_IncorrectFacetCutAction(IDiamondCut.FacetCutAction action);

/// @notice Thrown when the facet address is zero
error FacetRegistry_FacetAddressIsZero();

/// @notice Thrown when attempting to add a function selector that already exists
error FacetRegistry_CannotAddFunctionThatAlreadyExists(bytes4 selector);

/// @notice Thrown when attempting to replace a function with the same function
error FacetRegistry_CannotReplaceFunctionWithSameFunction(address facetAddress, bytes4 selector);

/// @notice Thrown when facet address must be zero for remove operations
error FacetRegistry_RemoveFacetAddressMustBeZero(address facetAddress);

/// @notice Thrown when attempting to remove a function that does not exist
error FacetRegistry_CannotRemoveFunctionThatDoesNotExist(address facetAddress, bytes4 selector);

/// @notice Thrown when attempting to remove an immutable function
error FacetRegistry_CannotRemoveImmutableFunction(address facetAddress, bytes4 selector);

/// @notice Thrown when the base facets array has incorrect length
error FacetRegistry_IncorrectBaseFacetsLength(uint256 length);

/// @notice Thrown when attempting to modify a base facet
error FacetRegistry_CannotModifyBaseFacet(address facetAddress);

/// @notice Thrown when module ID is zero
error FacetRegistry_ModuleIdIsZero();

/// @notice Thrown when module already exists
error FacetRegistry_ModuleAlreadyExists(bytes32 moduleId);

/// @notice Thrown when module does not exist
error FacetRegistry_ModuleDoesNotExist(bytes32 moduleId);

/// @notice Thrown when attempting to modify the BASE module
error FacetRegistry_CannotModifyBaseModule();

/// @notice Thrown when a facet belongs to a different module
error FacetRegistry_FacetBelongsToAnotherModule(address facetAddress, bytes32 moduleId);

/// @notice Thrown when a facet is not in the specified module
error FacetRegistry_FacetNotInModule(address facetAddress, bytes32 moduleId);

/// @notice Thrown when garden type ID is zero
error FacetRegistry_GardenTypeIdIsZero();

/// @notice Thrown when garden type already exists
error FacetRegistry_GardenTypeAlreadyExists(bytes32 gardenTypeId);

/// @notice Thrown when garden type does not exist
error FacetRegistry_GardenTypeDoesNotExist(bytes32 gardenTypeId);

/// @notice Thrown when module is already allowed for a garden type
error FacetRegistry_ModuleAlreadyAllowed(bytes32 gardenTypeId, bytes32 moduleId);

/// @notice Thrown when module is not allowed for a garden type
error FacetRegistry_ModuleNotAllowed(bytes32 gardenTypeId, bytes32 moduleId);

/// @notice Thrown when attempting to explicitly add or remove BASE_MODULE in a garden type
/// @dev BASE_MODULE is always implicitly included in every garden type
error FacetRegistry_CannotAddBaseModule(bytes32 gardenTypeId);

/// @notice Thrown when duplicate base facet addresses are provided in the constructor
error FacetRegistry_DuplicateBaseFacetAddress(address facetAddress);

/// @notice Thrown when version range parameters are invalid (startVersion == 0 or startVersion > endVersion)
error FacetRegistry_InvalidVersionRange(uint256 startVersion, uint256 endVersion);

/// @notice Thrown when the requested version exceeds the current version
error FacetRegistry_VersionOutOfBounds(uint256 version, uint256 currentVersion);

/// @notice Thrown when upgradeModule is called with an empty facetCuts array
error FacetRegistry_FacetCutsArrayEmpty();

/// @notice Thrown when a selector being replaced or removed is not registered
error FacetRegistry_SelectorNotRegistered(bytes4 selector);

/// @notice Thrown when renounceOwnership is called (disabled to prevent permanent lockout)
error FacetRegistry_CannotRenounceOwnership();

/// @notice Thrown when a base facet is provided with an empty selectors array in the constructor
error FacetRegistry_BaseFacetSelectorsEmpty(address facetAddress);

/**
 * @title FacetRegistry
 * @author BLOK Capital DAO
 * @notice Modular facet registry supporting multiple garden types and modules
 * @dev Supports modules, garden types, content based versioning, and cross chain
 *      consistency via identical bytecode deployment (CREATE2 compatible).
 */
contract FacetRegistry is IFacetRegistry, Ownable {
    // ========================================================================
    //                              CONSTANTS
    // ========================================================================

    /// @notice The BASE module identifier, immutable after deployment
    bytes32 public constant BASE_MODULE = keccak256("BASE");

    // ========================================================================
    //                         GLOBAL STORAGE
    // ========================================================================

    /// @notice Current global version of the registry (increments with each modification)
    uint256 private _currentVersion;

    /// @notice Array of all registered facet addresses
    address[] private _facetAddresses;

    /// @notice Array of 4 base facet addresses
    address[4] private _baseFacets;

    /// @notice Mapping from function selector to facet address and position
    mapping(bytes4 => FacetAddressAndPosition) private _selectorToFacetAndPosition;

    /// @notice Mapping from facet address to its function selectors
    mapping(address => FacetFunctionSelectors) private _facetFunctionSelectors;

    /// @notice Global facet cut history indexed by global version
    mapping(uint256 version => IDiamondCut.FacetCut facetCut) private _facetCutByVersion;

    // ========================================================================
    //                         MODULE STORAGE
    // ========================================================================

    /// @notice Array of all registered module IDs
    bytes32[] private _moduleIds;

    /// @notice Whether a module has been registered
    mapping(bytes32 => bool) private _moduleExists;

    /// @notice Per-module version counter
    mapping(bytes32 => uint256) private _moduleVersion;

    /// @notice Facet addresses belonging to a module
    mapping(bytes32 => address[]) private _moduleFacetAddresses;

    /// @notice 1-based index of a facet within a module's facet array, 0 means absent
    mapping(bytes32 => mapping(address => uint256)) private _moduleFacetIndex;

    /// @notice Per-module facet cut history indexed by module version
    mapping(bytes32 => mapping(uint256 => IDiamondCut.FacetCut)) private _moduleFacetCutByVersion;

    /// @notice Which module a facet belongs to, each facet belongs to exactly one module
    mapping(address => bytes32) private _facetToModule;

    // ========================================================================
    //                        GARDEN TYPE STORAGE
    // ========================================================================

    /// @notice Array of all registered garden type IDs
    bytes32[] private _gardenTypeIds;

    /// @notice Whether a garden type has been registered
    mapping(bytes32 => bool) private _gardenTypeExists;

    /// @notice Ordered list of allowed module IDs for a garden type
    mapping(bytes32 => bytes32[]) private _gardenTypeModules;

    /// @notice 1-based index of a module within a garden type's modules array, 0 means absent
    mapping(bytes32 => mapping(bytes32 => uint256)) private _gardenTypeModuleIndex;

    // ========================================================================
    //                              EVENTS
    // ========================================================================

    /// @notice Emitted when a new module is registered
    event ModuleRegistered(bytes32 indexed moduleId);

    /// @notice Emitted when functions are added to a module
    event ModuleFunctionsAdded(bytes32 indexed moduleId, address indexed facetAddress, bytes4[] functionSelectors);

    /// @notice Emitted when functions are removed from a module
    event ModuleFunctionsRemoved(bytes32 indexed moduleId, bytes4[] functionSelectors);

    /// @notice Emitted when functions are replaced within a module
    event ModuleFunctionsReplaced(bytes32 indexed moduleId, address indexed facetAddress, bytes4[] functionSelectors);

    /// @notice Emitted when a new garden type is added
    event GardenTypeAdded(bytes32 indexed gardenTypeId, bytes32[] allowedModules);

    /// @notice Emitted when a module is added to a garden type
    event AllowedModuleAdded(bytes32 indexed gardenTypeId, bytes32 indexed moduleId);

    /// @notice Emitted when a module is removed from a garden type
    event AllowedModuleRemoved(bytes32 indexed gardenTypeId, bytes32 indexed moduleId);

    // ========================================================================
    //                            CONSTRUCTOR
    // ========================================================================

    /// @notice Initializes the registry with base facets under the BASE module
    /// @param initialOwner The address that will own this registry
    /// @param baseFacets Array of 4 base facet addresses
    /// @param functionSelectors 2D array of function selectors for each base facet
    constructor(
        address initialOwner,
        address[4] memory baseFacets,
        bytes4[][] memory functionSelectors
    )
        Ownable(initialOwner)
    {
        if (functionSelectors.length != baseFacets.length) {
            revert FacetRegistry_IncorrectBaseFacetsLength(functionSelectors.length);
        }

        _moduleExists[BASE_MODULE] = true;
        _moduleIds.push(BASE_MODULE);

        for (uint8 i = 0; i < baseFacets.length; i++) {
            if (baseFacets[i] == address(0)) {
                revert FacetRegistry_BaseFacetAddressIsZero(baseFacets[i]);
            }
            for (uint8 j = 0; j < i; j++) {
                if (baseFacets[i] == baseFacets[j]) {
                    revert FacetRegistry_DuplicateBaseFacetAddress(baseFacets[i]);
                }
            }
        }

        for (uint8 i = 0; i < baseFacets.length; i++) {
            if (functionSelectors[i].length == 0) {
                revert FacetRegistry_BaseFacetSelectorsEmpty(baseFacets[i]);
            }

            _baseFacets[i] = baseFacets[i];
            _addBaseFacet(baseFacets[i], functionSelectors[i]);

            _currentVersion++;
            _moduleVersion[BASE_MODULE]++;

            IDiamondCut.FacetCut memory cut = IDiamondCut.FacetCut({
                facetAddress: baseFacets[i],
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors[i]
            });
            _facetCutByVersion[_currentVersion] = cut;
            _moduleFacetCutByVersion[BASE_MODULE][_moduleVersion[BASE_MODULE]] = cut;
        }
    }

    // ========================================================================
    //                      EXTERNAL (MODULE MANAGEMENT)
    // ========================================================================

    /// @inheritdoc IFacetRegistry
    function registerModule(bytes32 moduleId) external onlyOwner {
        if (moduleId == bytes32(0)) revert FacetRegistry_ModuleIdIsZero();
        if (_moduleExists[moduleId]) revert FacetRegistry_ModuleAlreadyExists(moduleId);

        _moduleExists[moduleId] = true;
        _moduleIds.push(moduleId);

        emit ModuleRegistered(moduleId);
    }

    /// @inheritdoc IFacetRegistry
    function upgradeModule(bytes32 moduleId, IDiamondCut.FacetCut[] memory facetCuts) external onlyOwner {
        if (!_moduleExists[moduleId]) revert FacetRegistry_ModuleDoesNotExist(moduleId);
        if (moduleId == BASE_MODULE) revert FacetRegistry_CannotModifyBaseModule();
        if (facetCuts.length == 0) revert FacetRegistry_FacetCutsArrayEmpty();

        for (uint256 i = 0; i < facetCuts.length; i++) {
            IDiamondCut.FacetCutAction action = facetCuts[i].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                _addModuleFunctions(moduleId, facetCuts[i].facetAddress, facetCuts[i].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                _replaceModuleFunctions(moduleId, facetCuts[i].facetAddress, facetCuts[i].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                _removeModuleFunctions(moduleId, facetCuts[i].facetAddress, facetCuts[i].functionSelectors);
            } else {
                revert FacetRegistry_IncorrectFacetCutAction(action);
            }
        }
    }

    // ========================================================================
    //                    EXTERNAL (GARDEN TYPE MANAGEMENT)
    // ========================================================================

    /// @inheritdoc IFacetRegistry
    function addGardenType(bytes32 gardenTypeId, bytes32[] memory allowedModules) external onlyOwner {
        if (gardenTypeId == bytes32(0)) revert FacetRegistry_GardenTypeIdIsZero();
        if (_gardenTypeExists[gardenTypeId]) revert FacetRegistry_GardenTypeAlreadyExists(gardenTypeId);

        _gardenTypeExists[gardenTypeId] = true;
        _gardenTypeIds.push(gardenTypeId);

        for (uint256 i = 0; i < allowedModules.length; i++) {
            bytes32 modId = allowedModules[i];
            if (modId == BASE_MODULE) revert FacetRegistry_CannotAddBaseModule(gardenTypeId);
            if (!_moduleExists[modId]) revert FacetRegistry_ModuleDoesNotExist(modId);
            if (_gardenTypeModuleIndex[gardenTypeId][modId] != 0) {
                revert FacetRegistry_ModuleAlreadyAllowed(gardenTypeId, modId);
            }
            _gardenTypeModules[gardenTypeId].push(modId);
            _gardenTypeModuleIndex[gardenTypeId][modId] = _gardenTypeModules[gardenTypeId].length;
        }

        emit GardenTypeAdded(gardenTypeId, allowedModules);
    }

    /// @inheritdoc IFacetRegistry
    function addAllowedModule(bytes32 gardenTypeId, bytes32 moduleId) external onlyOwner {
        if (!_gardenTypeExists[gardenTypeId]) revert FacetRegistry_GardenTypeDoesNotExist(gardenTypeId);
        if (moduleId == BASE_MODULE) revert FacetRegistry_CannotAddBaseModule(gardenTypeId);
        if (!_moduleExists[moduleId]) revert FacetRegistry_ModuleDoesNotExist(moduleId);
        if (_gardenTypeModuleIndex[gardenTypeId][moduleId] != 0) {
            revert FacetRegistry_ModuleAlreadyAllowed(gardenTypeId, moduleId);
        }

        _gardenTypeModules[gardenTypeId].push(moduleId);
        _gardenTypeModuleIndex[gardenTypeId][moduleId] = _gardenTypeModules[gardenTypeId].length;

        emit AllowedModuleAdded(gardenTypeId, moduleId);
    }

    /// @inheritdoc IFacetRegistry
    function removeAllowedModule(bytes32 gardenTypeId, bytes32 moduleId) external onlyOwner {
        if (!_gardenTypeExists[gardenTypeId]) revert FacetRegistry_GardenTypeDoesNotExist(gardenTypeId);

        uint256 index1Based = _gardenTypeModuleIndex[gardenTypeId][moduleId];
        if (index1Based == 0) revert FacetRegistry_ModuleNotAllowed(gardenTypeId, moduleId);

        uint256 lastIndex = _gardenTypeModules[gardenTypeId].length - 1;
        uint256 index = index1Based - 1;

        if (index != lastIndex) {
            bytes32 lastModuleId = _gardenTypeModules[gardenTypeId][lastIndex];
            _gardenTypeModules[gardenTypeId][index] = lastModuleId;
            _gardenTypeModuleIndex[gardenTypeId][lastModuleId] = index1Based;
        }

        _gardenTypeModules[gardenTypeId].pop();
        delete _gardenTypeModuleIndex[gardenTypeId][moduleId];

        emit AllowedModuleRemoved(gardenTypeId, moduleId);
    }

    // ========================================================================
    //                         RENOUNCE OWNERSHIP
    // ========================================================================

    /// @inheritdoc Ownable
    function renounceOwnership() public pure override {
        revert FacetRegistry_CannotRenounceOwnership();
    }

    // ========================================================================
    //                       EXTERNAL MODULE VIEWS
    // ========================================================================

    /// @inheritdoc IFacetRegistry
    function getModuleFacets(bytes32 moduleId) external view returns (Facet[] memory facets_) {
        if (!_moduleExists[moduleId]) revert FacetRegistry_ModuleDoesNotExist(moduleId);
        address[] storage facets = _moduleFacetAddresses[moduleId];
        uint256 numFacets = facets.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i = 0; i < numFacets; i++) {
            address facetAddress = facets[i];
            facets_[i].facetAddress = facetAddress;
            facets_[i].functionSelectors = _facetFunctionSelectors[facetAddress].functionSelectors;
        }
    }

    /// @inheritdoc IFacetRegistry
    function getModuleFacetAddresses(bytes32 moduleId) external view returns (address[] memory facetAddresses_) {
        if (!_moduleExists[moduleId]) revert FacetRegistry_ModuleDoesNotExist(moduleId);
        facetAddresses_ = _moduleFacetAddresses[moduleId];
    }

    /// @inheritdoc IFacetRegistry
    function getModuleFacetCutsByVersionRange(
        bytes32 moduleId,
        uint256 startVersion,
        uint256 endVersion
    )
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts)
    {
        if (!_moduleExists[moduleId]) revert FacetRegistry_ModuleDoesNotExist(moduleId);
        if (startVersion == 0 || startVersion > endVersion) {
            revert FacetRegistry_InvalidVersionRange(startVersion, endVersion);
        }
        if (endVersion > _moduleVersion[moduleId]) {
            revert FacetRegistry_VersionOutOfBounds(endVersion, _moduleVersion[moduleId]);
        }

        facetCuts = new IDiamondCut.FacetCut[](endVersion - startVersion + 1);
        for (uint256 i = startVersion; i <= endVersion; i++) {
            facetCuts[i - startVersion] = _moduleFacetCutByVersion[moduleId][i];
        }
    }

    /// @inheritdoc IFacetRegistry
    function getModuleVersion(bytes32 moduleId) external view returns (uint256) {
        if (!_moduleExists[moduleId]) revert FacetRegistry_ModuleDoesNotExist(moduleId);
        return _moduleVersion[moduleId];
    }

    /// @inheritdoc IFacetRegistry
    function getAllModuleIds() external view returns (bytes32[] memory) {
        return _moduleIds;
    }

    /// @inheritdoc IFacetRegistry
    function getFacetModule(address facetAddress) external view returns (bytes32) {
        return _facetToModule[facetAddress];
    }

    /// @inheritdoc IFacetRegistry
    function isModuleRegistered(bytes32 moduleId) external view returns (bool) {
        return _moduleExists[moduleId];
    }

    /// @inheritdoc IFacetRegistry
    function getModuleIdBySelector(bytes4 selector) external view returns (bytes32) {
        address facetAddress = _selectorToFacetAndPosition[selector].facetAddress;
        if (facetAddress == address(0)) {
            revert FacetRegistry_SelectorNotRegistered(selector);
        }
        return _facetToModule[facetAddress];
    }

    // ========================================================================
    //                     EXTERNAL GARDEN TYPE VIEWS
    // ========================================================================

    /// @inheritdoc IFacetRegistry
    function getGardenTypeModules(bytes32 gardenTypeId) external view returns (bytes32[] memory) {
        if (!_gardenTypeExists[gardenTypeId]) revert FacetRegistry_GardenTypeDoesNotExist(gardenTypeId);
        return _gardenTypeModules[gardenTypeId];
    }

    /// @inheritdoc IFacetRegistry
    function isModuleAllowedForGardenType(bytes32 gardenTypeId, bytes32 moduleId) external view returns (bool) {
        if (!_gardenTypeExists[gardenTypeId]) revert FacetRegistry_GardenTypeDoesNotExist(gardenTypeId);
        if (moduleId == BASE_MODULE) return true;
        return _gardenTypeModuleIndex[gardenTypeId][moduleId] != 0;
    }

    /// @inheritdoc IFacetRegistry
    function getAllGardenTypeIds() external view returns (bytes32[] memory) {
        return _gardenTypeIds;
    }

    /// @inheritdoc IFacetRegistry
    function isGardenTypeRegistered(bytes32 gardenTypeId) external view returns (bool) {
        return _gardenTypeExists[gardenTypeId];
    }

    /// @inheritdoc IFacetRegistry
    function getGardenTypeFacetCuts(bytes32 gardenTypeId)
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts)
    {
        if (!_gardenTypeExists[gardenTypeId]) revert FacetRegistry_GardenTypeDoesNotExist(gardenTypeId);

        bytes32[] storage modules = _gardenTypeModules[gardenTypeId];
        address[] storage baseFacetAddresses = _moduleFacetAddresses[BASE_MODULE];

        uint256 totalFacets = baseFacetAddresses.length;
        for (uint256 i = 0; i < modules.length; i++) {
            totalFacets += _moduleFacetAddresses[modules[i]].length;
        }

        facetCuts = new IDiamondCut.FacetCut[](totalFacets);
        uint256 index = 0;

        for (uint256 i = 0; i < baseFacetAddresses.length; i++) {
            facetCuts[index] = IDiamondCut.FacetCut({
                facetAddress: baseFacetAddresses[i],
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: _facetFunctionSelectors[baseFacetAddresses[i]].functionSelectors
            });
            index++;
        }

        for (uint256 i = 0; i < modules.length; i++) {
            address[] storage facetAddresses = _moduleFacetAddresses[modules[i]];
            for (uint256 j = 0; j < facetAddresses.length; j++) {
                facetCuts[index] = IDiamondCut.FacetCut({
                    facetAddress: facetAddresses[j],
                    action: IDiamondCut.FacetCutAction.Add,
                    functionSelectors: _facetFunctionSelectors[facetAddresses[j]].functionSelectors
                });
                index++;
            }
        }
    }

    /// @inheritdoc IFacetRegistry
    function getGardenTypeFacets(bytes32 gardenTypeId) external view returns (Facet[] memory facets_) {
        if (!_gardenTypeExists[gardenTypeId]) revert FacetRegistry_GardenTypeDoesNotExist(gardenTypeId);

        bytes32[] storage modules = _gardenTypeModules[gardenTypeId];
        address[] storage baseFacetAddresses = _moduleFacetAddresses[BASE_MODULE];

        uint256 totalFacets = baseFacetAddresses.length;
        for (uint256 i = 0; i < modules.length; i++) {
            totalFacets += _moduleFacetAddresses[modules[i]].length;
        }

        facets_ = new Facet[](totalFacets);
        uint256 index = 0;

        for (uint256 i = 0; i < baseFacetAddresses.length; i++) {
            address facetAddress = baseFacetAddresses[i];
            facets_[i].facetAddress = facetAddress;
            facets_[i].functionSelectors = _facetFunctionSelectors[facetAddress].functionSelectors;
            index++;
        }

        for (uint256 i = 0; i < modules.length; i++) {
            address[] storage facetAddresses = _moduleFacetAddresses[modules[i]];
            for (uint256 j = 0; j < facetAddresses.length; j++) {
                address facetAddress = facetAddresses[j];
                facets_[index].facetAddress = facetAddress;
                facets_[index].functionSelectors = _facetFunctionSelectors[facetAddress].functionSelectors;
                index++;
            }
        }
    }

    // ========================================================================
    //                  EXTERNAL FACET VIEWS
    // ========================================================================

    /// @inheritdoc IFacetRegistry
    function getFacets() external view returns (Facet[] memory facets_) {
        uint256 numFacets = _facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i = 0; i < numFacets; i++) {
            address facetAddress_ = _facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = _facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @inheritdoc IFacetRegistry
    function getFacetFunctionSelectors(address _facet) external view returns (bytes4[] memory selectors) {
        selectors = _facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @inheritdoc IFacetRegistry
    function getFacetAddresses() external view returns (address[] memory facetAddresses_) {
        facetAddresses_ = _facetAddresses;
    }

    /// @inheritdoc IFacetRegistry
    function getFacetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {
        facetAddress_ = _selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    /// @inheritdoc IFacetRegistry
    function getBaseFacets() external view returns (address[4] memory baseFacets_) {
        baseFacets_ = _baseFacets;
    }

    /// @inheritdoc IFacetRegistry
    function getFacetCutsByVersionRange(
        uint256 _startVersion,
        uint256 _endVersion
    )
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts)
    {
        if (_startVersion == 0 || _startVersion > _endVersion) {
            revert FacetRegistry_InvalidVersionRange(_startVersion, _endVersion);
        }
        if (_endVersion > _currentVersion) {
            revert FacetRegistry_VersionOutOfBounds(_endVersion, _currentVersion);
        }

        facetCuts = new IDiamondCut.FacetCut[](_endVersion - _startVersion + 1);
        for (uint256 i = _startVersion; i <= _endVersion; i++) {
            facetCuts[i - _startVersion] = _facetCutByVersion[i];
        }
    }

    /// @inheritdoc IFacetRegistry
    function isFacetRegistered(address _facet) external view returns (bool) {
        return _facetFunctionSelectors[_facet].functionSelectors.length > 0;
    }

    /// @inheritdoc IFacetRegistry
    function isSelectorRegistered(bytes4 _functionSelector) external view returns (bool) {
        return _selectorToFacetAndPosition[_functionSelector].facetAddress != address(0);
    }

    /// @inheritdoc IFacetRegistry
    function isSelectorRegisteredWithFacet(address _facet, bytes4 _functionSelector) external view returns (bool) {
        if (_facet == address(0)) {
            revert FacetRegistry_FacetAddressIsZero();
        }
        address facetAddress_ = _selectorToFacetAndPosition[_functionSelector].facetAddress;
        return facetAddress_ == _facet;
    }

    /// @inheritdoc IFacetRegistry
    function getCurrentVersion() external view returns (uint256) {
        return _currentVersion;
    }

    /// @inheritdoc IFacetRegistry
    function validateSelector(
        bytes4 selector,
        bytes32 gardenType
    )
        external
        view
        returns (address registeredFacet, bool moduleAllowed)
    {
        registeredFacet = _selectorToFacetAndPosition[selector].facetAddress;
        if (registeredFacet == address(0)) {
            return (address(0), false);
        }

        bytes32 moduleId = _facetToModule[registeredFacet];
        if (moduleId == BASE_MODULE) {
            moduleAllowed = true;
        } else if (gardenType != bytes32(0) && _gardenTypeExists[gardenType]) {
            moduleAllowed = _gardenTypeModuleIndex[gardenType][moduleId] != 0;
        } else {
            moduleAllowed = true;
        }
    }

    // ========================================================================
    //                       INTERNAL MODULE HELPERS
    // ========================================================================

    /// @notice Adds functions to a module
    /// @dev Each selector must be globally unique, no two modules can share the same selector
    /// @param moduleId The module to add to
    /// @param facetAddress The facet contract address
    /// @param functionSelectors The selectors to add
    function _addModuleFunctions(bytes32 moduleId, address facetAddress, bytes4[] memory functionSelectors) internal {
        if (functionSelectors.length == 0) revert FacetRegistry_SelectorArrayEmpty();
        if (facetAddress == address(0)) revert FacetRegistry_FacetAddressIsZero();

        bytes32 existingModule = _facetToModule[facetAddress];
        if (existingModule != bytes32(0) && existingModule != moduleId) {
            revert FacetRegistry_FacetBelongsToAnotherModule(facetAddress, existingModule);
        }

        uint96 selectorPosition = uint96(_facetFunctionSelectors[facetAddress].functionSelectors.length);
        if (selectorPosition == 0) {
            _addFacet(facetAddress);
            _facetToModule[facetAddress] = moduleId;
            _moduleFacetAddresses[moduleId].push(facetAddress);
            _moduleFacetIndex[moduleId][facetAddress] = _moduleFacetAddresses[moduleId].length;
        }

        for (uint256 i = 0; i < functionSelectors.length; i++) {
            bytes4 selector = functionSelectors[i];
            address oldFacet = _selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacet != address(0)) {
                revert FacetRegistry_CannotAddFunctionThatAlreadyExists(selector);
            }
            _addFunction(selector, selectorPosition, facetAddress);
            selectorPosition++;
        }

        _currentVersion++;
        _moduleVersion[moduleId]++;

        IDiamondCut.FacetCut memory cut = IDiamondCut.FacetCut({
            facetAddress: facetAddress, action: IDiamondCut.FacetCutAction.Add, functionSelectors: functionSelectors
        });
        _moduleFacetCutByVersion[moduleId][_moduleVersion[moduleId]] = cut;
        _facetCutByVersion[_currentVersion] = cut;

        emit ModuleFunctionsAdded(moduleId, facetAddress, functionSelectors);
    }

    /// @notice Replaces functions within a module
    /// @param moduleId The module context
    /// @param facetAddress The new facet address
    /// @param functionSelectors The selectors to replace
    function _replaceModuleFunctions(
        bytes32 moduleId,
        address facetAddress,
        bytes4[] memory functionSelectors
    )
        internal
    {
        if (functionSelectors.length == 0) revert FacetRegistry_SelectorArrayEmpty();
        if (facetAddress == address(0)) revert FacetRegistry_FacetAddressIsZero();

        bytes32 existingModule = _facetToModule[facetAddress];
        if (existingModule != bytes32(0) && existingModule != moduleId) {
            revert FacetRegistry_FacetBelongsToAnotherModule(facetAddress, existingModule);
        }

        uint96 selectorPosition = uint96(_facetFunctionSelectors[facetAddress].functionSelectors.length);
        if (selectorPosition == 0) {
            _addFacet(facetAddress);
            _facetToModule[facetAddress] = moduleId;
            _moduleFacetAddresses[moduleId].push(facetAddress);
            _moduleFacetIndex[moduleId][facetAddress] = _moduleFacetAddresses[moduleId].length;
        }

        for (uint256 i = 0; i < functionSelectors.length; i++) {
            bytes4 selector = functionSelectors[i];
            address oldFacetAddress = _selectorToFacetAndPosition[selector].facetAddress;

            if (oldFacetAddress == address(0)) {
                revert FacetRegistry_SelectorNotRegistered(selector);
            }

            if (oldFacetAddress == facetAddress) {
                revert FacetRegistry_CannotReplaceFunctionWithSameFunction(oldFacetAddress, selector);
            }

            if (_facetToModule[oldFacetAddress] != moduleId) {
                revert FacetRegistry_FacetNotInModule(oldFacetAddress, moduleId);
            }

            _removeFunction(oldFacetAddress, selector);

            if (_facetFunctionSelectors[oldFacetAddress].functionSelectors.length == 0) {
                _removeFacetFromModule(moduleId, oldFacetAddress);
                delete _facetToModule[oldFacetAddress];
            }

            _addFunction(selector, selectorPosition, facetAddress);
            selectorPosition++;
        }

        _currentVersion++;
        _moduleVersion[moduleId]++;

        IDiamondCut.FacetCut memory cut = IDiamondCut.FacetCut({
            facetAddress: facetAddress, action: IDiamondCut.FacetCutAction.Replace, functionSelectors: functionSelectors
        });
        _moduleFacetCutByVersion[moduleId][_moduleVersion[moduleId]] = cut;
        _facetCutByVersion[_currentVersion] = cut;

        emit ModuleFunctionsReplaced(moduleId, facetAddress, functionSelectors);
    }

    /// @notice Removes functions from a module
    /// @param moduleId The module context
    /// @param facetAddress Must be address(0) per diamond cut convention
    /// @param functionSelectors The selectors to remove
    function _removeModuleFunctions(
        bytes32 moduleId,
        address facetAddress,
        bytes4[] memory functionSelectors
    )
        internal
    {
        if (functionSelectors.length == 0) revert FacetRegistry_SelectorArrayEmpty();
        if (facetAddress != address(0)) revert FacetRegistry_RemoveFacetAddressMustBeZero(facetAddress);

        for (uint256 i = 0; i < functionSelectors.length; i++) {
            bytes4 selector = functionSelectors[i];
            address oldFacetAddress = _selectorToFacetAndPosition[selector].facetAddress;

            if (oldFacetAddress == address(0)) {
                revert FacetRegistry_SelectorNotRegistered(selector);
            }

            if (_facetToModule[oldFacetAddress] != moduleId) {
                revert FacetRegistry_FacetNotInModule(oldFacetAddress, moduleId);
            }

            _removeFunction(oldFacetAddress, selector);

            if (_facetFunctionSelectors[oldFacetAddress].functionSelectors.length == 0) {
                _removeFacetFromModule(moduleId, oldFacetAddress);
                delete _facetToModule[oldFacetAddress];
            }
        }

        _currentVersion++;
        _moduleVersion[moduleId]++;

        IDiamondCut.FacetCut memory cut = IDiamondCut.FacetCut({
            facetAddress: facetAddress, action: IDiamondCut.FacetCutAction.Remove, functionSelectors: functionSelectors
        });
        _moduleFacetCutByVersion[moduleId][_moduleVersion[moduleId]] = cut;
        _facetCutByVersion[_currentVersion] = cut;

        emit ModuleFunctionsRemoved(moduleId, functionSelectors);
    }

    /// @notice Removes a facet from a module's facet array
    /// @param moduleId The module to remove from
    /// @param facetAddress The facet to remove
    function _removeFacetFromModule(bytes32 moduleId, address facetAddress) internal {
        uint256 index1Based = _moduleFacetIndex[moduleId][facetAddress];
        if (index1Based == 0) return;

        uint256 lastIndex = _moduleFacetAddresses[moduleId].length - 1;
        uint256 index = index1Based - 1;

        if (index != lastIndex) {
            address lastFacet = _moduleFacetAddresses[moduleId][lastIndex];
            _moduleFacetAddresses[moduleId][index] = lastFacet;
            _moduleFacetIndex[moduleId][lastFacet] = index1Based;
        }

        _moduleFacetAddresses[moduleId].pop();
        delete _moduleFacetIndex[moduleId][facetAddress];
    }

    // ========================================================================
    //                     INTERNAL CORE HELPERS
    // ========================================================================

    /// @notice Adds a base facet with its function selectors during construction
    /// @param _facetAddress The base facet contract address
    /// @param _functionSelectors Function selectors for the base facet
    function _addBaseFacet(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_facetAddress.code.length == 0) {
            revert FacetRegistry_FacetIsNotContract(_facetAddress);
        }

        _facetFunctionSelectors[_facetAddress].facetAddressPosition = _facetAddresses.length;
        _facetAddresses.push(_facetAddress);

        _facetToModule[_facetAddress] = BASE_MODULE;
        _moduleFacetAddresses[BASE_MODULE].push(_facetAddress);
        _moduleFacetIndex[BASE_MODULE][_facetAddress] = _moduleFacetAddresses[BASE_MODULE].length;

        for (uint256 selectorIndex = 0; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            if (_selectorToFacetAndPosition[selector].facetAddress != address(0)) {
                revert FacetRegistry_CannotAddFunctionThatAlreadyExists(selector);
            }
            _addFunction(selector, uint96(selectorIndex), _facetAddress);
        }
    }

    /// @notice Adds a new facet address to the global registry
    /// @param _facetAddress The facet contract address
    function _addFacet(address _facetAddress) internal {
        if (_facetAddress.code.length == 0) {
            revert FacetRegistry_FacetIsNotContract(_facetAddress);
        }

        _facetFunctionSelectors[_facetAddress].facetAddressPosition = _facetAddresses.length;
        _facetAddresses.push(_facetAddress);
    }

    /// @notice Adds a function selector to a facet in global tracking
    /// @param _selector The function selector
    /// @param _selectorPosition The position in the facet's selector array
    /// @param _facetAddress The facet address
    function _addFunction(bytes4 _selector, uint96 _selectorPosition, address _facetAddress) internal {
        _selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        _facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        _selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    /// @notice Removes a function selector from a facet in global tracking
    /// @param _facetAddress The facet address
    /// @param _selector The function selector to remove
    function _removeFunction(address _facetAddress, bytes4 _selector) internal {
        if (_facetAddress == address(0)) {
            revert FacetRegistry_CannotRemoveFunctionThatDoesNotExist(_facetAddress, _selector);
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
