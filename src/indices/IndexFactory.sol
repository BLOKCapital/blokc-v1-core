//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

/*###############################################################################

    @title IndexFactory
    @author BLOK Capital DAO
    @notice Factory for deploying and managing Index contracts
    @dev Creates new Index instances with validated calculation strategies and components.
         Maintains a registry of all deployed indices for tracking and governance.
         Enforces maximum component limits and validates against calculation/component registries.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Index } from "src/indices/Index.sol";
import { IndexCalculationRegistry } from "src/indices/IndexCalculationRegistry.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when initial owner address is zero
/// @param owner The invalid owner address
error IndexFactory_InvalidInitialOwner(address owner);

/// @notice Thrown when index address is invalid or name is empty
/// @param indexAddress The invalid index address
error IndexFactory_InvalidIndexAddress(address indexAddress);

/// @notice Thrown when attempting to register an already registered index
/// @param indexAddress The already registered index address
error IndexFactory_IndexAlreadyRegistered(address indexAddress);

/// @notice Thrown when attempting to operate on an unregistered index
/// @param indexAddress The unregistered index address
error IndexFactory_IndexNotRegistered(address indexAddress);

/// @notice Thrown when calculation strategy is not registered in IndexCalculationRegistry
/// @param indexCalculationAddress The unregistered calculation address
error IndexFactory_IndexCalculationNotRegistered(address indexCalculationAddress);

/// @notice Thrown when calculation strategy is already registered
/// @param indexCalculationAddress The already registered calculation address
error IndexFactory_IndexCalculationAlreadyRegistered(address indexCalculationAddress);

/// @notice Thrown when component is not registered in IndexComponentRegistry
/// @param symbol The unregistered component symbol
error IndexFactory_ComponentNotRegistered(string symbol);

/// @notice Thrown when IndexCalculationRegistry address is zero during construction
/// @param indexCalculationRegistryAddress The invalid registry address
error IndexFactory_InvalidIndexCalculationRegistryAddress(address indexCalculationRegistryAddress);

/// @notice Thrown when IndexComponentRegistry address is zero during construction
/// @param componentRegistryAddress The invalid registry address
error IndexFactory_InvalidComponentRegistryAddress(address componentRegistryAddress);

/// @notice Thrown when garden is already connected to index
/// @param garden The garden address
/// @param indexAddress The index address
error IndexFactory_GardenAlreadyConnectedToIndex(address garden, address indexAddress);

/// @notice Thrown when garden is not connected to index
/// @param garden The garden address
/// @param indexAddress The index address
error IndexFactory_GardenNotConnectedToIndex(address garden, address indexAddress);

/// @notice Thrown when attempting to create index with too many or zero components
/// @param componentCount The attempted component count
/// @param maxComponents The maximum allowed components
error IndexFactory_TooManyComponents(uint256 componentCount, uint256 maxComponents);

contract IndexFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Maximum number of components allowed in a single index
    /// @dev Set to 250 to balance diversification with gas costs and complexity
    uint256 public constant MAX_COMPONENTS_PER_INDEX = 250;

    /// @notice Emitted when a garden connects to an index
    /// @param garden Address of the garden
    /// @param indexAddress Address of the index
    event GardenConnectedToIndex(address indexed garden, address indexed indexAddress);

    /// @notice Emitted when a garden disconnects from an index
    /// @param garden Address of the garden
    /// @param indexAddress Address of the index
    event GardenDisconnectedFromIndex(address indexed garden, address indexed indexAddress);

    /// @notice Metadata for a deployed index
    /// @param name Human-readable name of the index
    /// @param id Unique identifier assigned during deployment
    /// @param symbols Array of component symbols in the index
    /// @param indexAddress Address of the deployed Index contract
    /// @param indexCalculationAddress Address of the calculation strategy used
    /// @param createdAt Block timestamp when the index was created
    struct IndexInfo {
        string name;
        uint256 id;
        string[] symbols;
        address indexAddress;
        address indexCalculationAddress;
        uint256 createdAt;
    }

    /// @notice Reference to the IndexCalculationRegistry for validation
    /// @dev Immutable to ensure consistent validation logic
    address private immutable INDEX_CALCULATION_REGISTRY;

    /// @notice Reference to the IndexComponentRegistry for validation
    /// @dev Immutable to ensure consistent component validation
    address private immutable COMPONENT_REGISTRY;

    /// @notice Counter for assigning unique IDs to deployed indices
    /// @dev Incremented for each new index deployment
    uint256 private _indexIdCounter;

    /// @notice Mapping of index addresses to their metadata
    /// @dev Stores complete information about each deployed index
    mapping(address indexAddress => IndexInfo indexInfo) private _indexInfo;

    /// @notice Set of all deployed index addresses
    /// @dev Provides efficient lookup and iteration
    EnumerableSet.AddressSet private _indexAddresses;

    /// @notice Constructs the IndexFactory
    /// @param initialOwner Address of the contract owner
    /// @param indexCalculationRegistry Address of the IndexCalculationRegistry
    /// @param componentRegistry Address of the IndexComponentRegistry
    /// @dev Validates all addresses are not zero
    constructor(
        address initialOwner,
        address indexCalculationRegistry,
        address componentRegistry
    )
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert IndexFactory_InvalidInitialOwner(initialOwner);
        if (indexCalculationRegistry == address(0)) {
            revert IndexFactory_InvalidIndexCalculationRegistryAddress(indexCalculationRegistry);
        }
        if (componentRegistry == address(0)) {
            revert IndexFactory_InvalidComponentRegistryAddress(componentRegistry);
        }
        INDEX_CALCULATION_REGISTRY = indexCalculationRegistry;
        COMPONENT_REGISTRY = componentRegistry;
    }

    /// @notice Validates that a calculation strategy is registered
    /// @param indexCalculationAddress Address of the calculation contract to validate
    /// @dev Modifier checks against IndexCalculationRegistry
    modifier checkCalculationRegistered(address indexCalculationAddress) {
        _checkCalculationRegistered(indexCalculationAddress);
        _;
    }

    function _checkCalculationRegistered(address indexCalculationAddress) internal view {
        if (!IndexCalculationRegistry(INDEX_CALCULATION_REGISTRY).isIndexCalculationRegistered(indexCalculationAddress))
        {
            revert IndexFactory_IndexCalculationNotRegistered(indexCalculationAddress);
        }
    }

    /// @notice Validates that all components are registered
    /// @param symbols Array of component symbols to validate
    /// @dev Modifier checks each component against IndexComponentRegistry
    modifier checkComponentsRegistered(string[] memory symbols) {
        _checkComponentsRegistered(symbols);
        _;
    }

    function _checkComponentsRegistered(string[] memory symbols) internal view {
        for (uint256 i = 0; i < symbols.length; i++) {
            if (!IndexComponentRegistry(COMPONENT_REGISTRY).isComponentRegistered(symbols[i])) {
                revert IndexFactory_ComponentNotRegistered(symbols[i]);
            }
        }
    }

    /// @notice Deploys a new Index contract with specified parameters
    /// @param name Human-readable name for the index
    /// @param indexCalculationAddress Address of the calculation strategy contract
    /// @param symbols Array of component symbols to include
    /// @return indexAddress Address of the newly deployed Index contract
    /// @dev Only callable by owner. Validates calculation and components are registered.
    ///      Enforces component count limits and non-empty name.
    function deployIndex(
        string calldata name,
        address indexCalculationAddress,
        string[] memory symbols
    )
        external
        onlyOwner
        checkCalculationRegistered(indexCalculationAddress)
        checkComponentsRegistered(symbols)
        returns (address indexAddress)
    {
        if (symbols.length == 0 || symbols.length > MAX_COMPONENTS_PER_INDEX) {
            revert IndexFactory_TooManyComponents(symbols.length, MAX_COMPONENTS_PER_INDEX);
        }
        if (bytes(name).length == 0) {
            revert IndexFactory_InvalidIndexAddress(address(0));
        }

        indexAddress = address(new Index(address(this), indexCalculationAddress, COMPONENT_REGISTRY, symbols));
        _registerIndex(indexAddress, name, indexCalculationAddress, symbols);
        return indexAddress;
    }

    /// @notice Removes an index from the registry
    /// @param indexAddress Address of the index to remove
    /// @dev Only callable by owner. Does not destroy the Index contract itself.
    function removeIndex(address indexAddress) external onlyOwner {
        if (!_indexAddresses.contains(indexAddress)) revert IndexFactory_IndexNotRegistered(indexAddress);
        _indexAddresses.remove(indexAddress);

        delete _indexInfo[indexAddress];
    }

    /// @notice Retrieves metadata for a specific index
    /// @param indexAddress Address of the index
    /// @return IndexInfo struct containing complete index metadata
    function getIndexInfo(address indexAddress) external view returns (IndexInfo memory) {
        return _indexInfo[indexAddress];
    }

    /// @notice Returns all deployed index addresses
    /// @return Array of index addresses
    function getAllIndices() public view returns (address[] memory) {
        return _indexAddresses.values();
    }

    /// @notice Returns metadata for all deployed indices
    /// @return Array of IndexInfo structs
    function getAllIndexInfos() external view returns (IndexInfo[] memory) {
        IndexInfo[] memory indexInfos = new IndexInfo[](_indexAddresses.length());
        for (uint256 i = 0; i < _indexAddresses.length(); i++) {
            indexInfos[i] = _indexInfo[_indexAddresses.at(i)];
        }
        return indexInfos;
    }

    /// @notice Checks if an index is registered in the factory
    /// @param indexAddress Address to check
    /// @return True if the index is registered, false otherwise
    function isIndexRegistered(address indexAddress) external view returns (bool) {
        return _indexAddresses.contains(indexAddress);
    }

    /// @notice Internal function to register a newly deployed index
    /// @param indexAddress Address of the deployed Index contract
    /// @param name Name of the index
    /// @param indexCalculationAddress Calculation strategy address
    /// @param symbols Array of component symbols
    /// @dev Assigns unique ID and stores complete metadata
    function _registerIndex(
        address indexAddress,
        string calldata name,
        address indexCalculationAddress,
        string[] memory symbols
    )
        internal
    {
        if (_indexAddresses.contains(indexAddress)) revert IndexFactory_IndexAlreadyRegistered(indexAddress);
        _indexIdCounter++;
        _indexInfo[indexAddress] = IndexInfo({
            name: name,
            id: _indexIdCounter,
            indexAddress: indexAddress,
            symbols: symbols,
            indexCalculationAddress: indexCalculationAddress,
            createdAt: block.timestamp
        });
        _indexAddresses.add(indexAddress);
    }
}
