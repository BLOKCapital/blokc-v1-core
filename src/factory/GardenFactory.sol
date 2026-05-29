// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// OpenZeppelin Standard Contracts
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Local Interfaces
import { IGardenFactory } from "src/interfaces/IGardenFactory.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

// Local Contracts
import { Garden } from "src/garden/Garden.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when attempting to use an index that is already in use
/// @param user The address of the user attempting to use the index
/// @param index The index that is already in use
error GardenFactory_IndexAlreadyUsed(address user, uint256 index);

/// @notice Thrown when a required base facet is not registered in the registry
error GardenFactory_DefaultFacetNotRegistered();

/// @notice Thrown when the provided index is out of valid range (must be 1-10)
/// @param index The invalid index value
error GardenFactory_IndexOutOfRange(uint256 index);

/// @notice Thrown when the facet registry is not set
error GardenFactory_FacetRegistryNotSet();

/// @notice Thrown when the protocol status is not set
error GardenFactory_ProtocolStatusNotSet();

/// @notice Thrown when the protocol is inactive
error GardenFactory_ProtocolIsInactive();

/// @notice Thrown when the garden type is not registered
/// @param gardenType The unregistered garden type
error GardenFactory_GardenTypeNotRegistered(bytes32 gardenType);

/**
 * @title GardenFactory
 * @author BLOK Capital DAO
 * @notice Factory contract that deploys new garden (Diamond) contracts using CREATE2.
 * @dev Each user can deploy up to 10 gardens, with deterministic addresses based on the user, index, and factory
 * address.
 * The factory also keeps track of all deployed gardens and their associations with users.
 */
contract GardenFactory is Ownable, ReentrancyGuard, IGardenFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ========================================================================
    //                            STATE VARIABLES
    // ========================================================================

    /// @notice The address of the facet registry contract
    address private _facetRegistry;

    /// @notice The address of the protocol status contract
    address private _protocolStatus;

    /// @notice The set of all gardens created by this factory
    EnumerableSet.AddressSet private _gardens;

    /// @notice Mapping of user address to array of their garden addresses
    mapping(address user => address[]) private _userGardens;

    /// @notice Mapping of user address to index (1-10) to garden address
    mapping(address user => mapping(uint256 index => address)) private _userIndexToGarden;

    /// @notice Mapping of garden address to its garden type
    mapping(address garden => bytes32 gardenType) private _gardenToType;

    /// @notice Mapping of garden type to the set of gardens of that type
    mapping(bytes32 gardenType => EnumerableSet.AddressSet) private _gardensByType;

    /// @notice Mapping of user address to garden type to array of garden addresses
    mapping(address user => mapping(bytes32 gardenType => address[])) private _userGardensByType;

    /// @notice Mapping of garden address to its owner
    mapping(address garden => address owner) private _gardenToOwner;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when a new garden is created
    /// @param garden The address of the newly created garden
    /// @param owner The address of the garden owner
    /// @param index The index (1-10) used by the owner for this garden
    event GardenCreated(address indexed garden, address indexed owner, uint256 indexed index);

    /// @notice Emitted when the factory is initialized
    /// @param initialOwner The initial owner of the factory
    event FactoryInitialized(address indexed initialOwner);

    // ========================================================================
    //                            CONSTRUCTOR
    // ========================================================================

    /// @notice Constructor
    /// @dev Initializes the factory with the given addresses
    /// @param initialOwner The initial owner of the factory
    /// @param facetRegistry The address of the facet registry contract
    /// @param protocolStatus The address of the protocol status contract
    constructor(address initialOwner, address facetRegistry, address protocolStatus) Ownable(initialOwner) {
        _facetRegistry = facetRegistry;
        _protocolStatus = protocolStatus;

        if (_facetRegistry == address(0)) {
            revert GardenFactory_FacetRegistryNotSet();
        }
        if (_protocolStatus == address(0)) {
            revert GardenFactory_ProtocolStatusNotSet();
        }
    }

    // ========================================================================
    // External Functions
    // ========================================================================

    /// @inheritdoc IGardenFactory
    function createGarden(
        uint256 index,
        bytes32 gardenType
    )
        external
        override
        nonReentrant
        returns (address gardenAddress)
    {
        address owner = msg.sender;

        IProtocolStatus protocolStatus = IProtocolStatus(_protocolStatus);
        if (protocolStatus.getProtocolStatus() == IProtocolStatus.State.INACTIVE) {
            revert GardenFactory_ProtocolIsInactive();
        }

        // Validate index is within allowed range
        if (index < 1 || index > 10) {
            revert GardenFactory_IndexOutOfRange(index);
        }

        // Ensure the user hasn't already used this index
        if (_userIndexToGarden[owner][index] != address(0)) {
            revert GardenFactory_IndexAlreadyUsed(owner, index);
        }

        // Validate garden type is registered and get facet cuts for this type
        IFacetRegistry registry = IFacetRegistry(_facetRegistry);
        if (!registry.isGardenTypeRegistered(gardenType)) {
            revert GardenFactory_GardenTypeNotRegistered(gardenType);
        }

        IDiamondCut.FacetCut[] memory diamondCut = registry.getBaseFacetCuts();

        // Generate deterministic salt for CREATE2 deployment
        bytes32 salt = keccak256(abi.encode(owner, index, address(this)));

        // Deploy the Diamond contract using CREATE2 with garden type
        Garden garden = new Garden{ salt: salt }(diamondCut, owner, _facetRegistry, _protocolStatus, gardenType);

        gardenAddress = address(garden);

        // Register the garden
        _gardens.add(gardenAddress);
        _userGardens[owner].push(gardenAddress);
        _userIndexToGarden[owner][index] = gardenAddress;

        // Track garden type associations
        _gardenToType[gardenAddress] = gardenType;
        _gardensByType[gardenType].add(gardenAddress);
        _userGardensByType[owner][gardenType].push(gardenAddress);
        _gardenToOwner[gardenAddress] = owner;

        emit GardenCreated(gardenAddress, owner, index);
    }

    /// @inheritdoc IGardenFactory
    function getAllGardens() external view returns (address[] memory gardens) {
        gardens = _gardens.values();
    }

    /// @inheritdoc IGardenFactory
    function getUserGardens(address user) external view returns (address[] memory gardens) {
        gardens = _userGardens[user];
    }

    /// @inheritdoc IGardenFactory
    function getGarden(address user, uint256 index) external view returns (address) {
        return _userIndexToGarden[user][index];
    }

    /// @inheritdoc IGardenFactory
    function isGardenRegistered(address garden) external view returns (bool) {
        return _gardens.contains(garden);
    }

    /// @inheritdoc IGardenFactory
    function getTotalGardens() external view returns (uint256 count) {
        count = _gardens.length();
    }

    /// @inheritdoc IGardenFactory
    function getUserGardenCount(address user) external view returns (uint256 count) {
        count = _userGardens[user].length;
    }

    /// @inheritdoc IGardenFactory
    function getUserAvailableIndices(address user) external view returns (uint256[] memory availableIndices) {
        uint256 available;
        for (uint256 i = 1; i <= 10; i++) {
            if (_userIndexToGarden[user][i] == address(0)) {
                available++;
            }
        }

        availableIndices = new uint256[](available);
        uint256 cursor;
        for (uint256 i = 1; i <= 10; i++) {
            if (_userIndexToGarden[user][i] == address(0)) {
                availableIndices[cursor] = i;
                cursor++;
            }
        }
    }

    /// @inheritdoc IGardenFactory
    function getUserUsedIndices(address user) external view returns (uint256[] memory usedIndices) {
        uint256 used;
        for (uint256 i = 1; i <= 10; i++) {
            if (_userIndexToGarden[user][i] != address(0)) {
                used++;
            }
        }

        usedIndices = new uint256[](used);
        uint256 cursor;
        for (uint256 i = 1; i <= 10; i++) {
            if (_userIndexToGarden[user][i] != address(0)) {
                usedIndices[cursor] = i;
                cursor++;
            }
        }
    }

    /// @inheritdoc IGardenFactory
    function getGardensByRange(uint256 offset, uint256 limit) external view returns (address[] memory gardens) {
        uint256 total = _gardens.length();
        if (offset >= total) {
            return new address[](0);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 count = end - offset;
        gardens = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            gardens[i] = _gardens.at(offset + i);
        }
    }

    /// @inheritdoc IGardenFactory
    function getFacetRegistry() external view returns (address) {
        return _facetRegistry;
    }

    /// @inheritdoc IGardenFactory
    function getProtocolStatus() external view returns (address) {
        return _protocolStatus;
    }

    /// @inheritdoc IGardenFactory
    function isIndexAvailable(address user, uint256 index) external view returns (bool) {
        if (index < 1 || index > 10) return false;
        return _userIndexToGarden[user][index] == address(0);
    }

    // ========================================================================
    //                       GARDEN TYPE VIEW FUNCTIONS
    // ========================================================================

    /// @inheritdoc IGardenFactory
    function getGardenType(address garden) external view returns (bytes32) {
        return _gardenToType[garden];
    }

    /// @inheritdoc IGardenFactory
    function getGardenOwner(address garden) external view returns (address) {
        return _gardenToOwner[garden];
    }

    /// @inheritdoc IGardenFactory
    function getGardensByType(bytes32 gardenType) external view returns (address[] memory gardens) {
        gardens = _gardensByType[gardenType].values();
    }

    /// @inheritdoc IGardenFactory
    function getGardensByTypeCount(bytes32 gardenType) external view returns (uint256 count) {
        count = _gardensByType[gardenType].length();
    }

    /// @inheritdoc IGardenFactory
    function getGardensByTypeRange(
        bytes32 gardenType,
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (address[] memory gardens)
    {
        uint256 total = _gardensByType[gardenType].length();
        if (offset >= total) {
            return new address[](0);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 count = end - offset;
        gardens = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            gardens[i] = _gardensByType[gardenType].at(offset + i);
        }
    }

    /// @inheritdoc IGardenFactory
    function getUserGardensByType(address user, bytes32 gardenType) external view returns (address[] memory gardens) {
        gardens = _userGardensByType[user][gardenType];
    }

    /// @inheritdoc IGardenFactory
    function getUserGardensByTypeCount(address user, bytes32 gardenType) external view returns (uint256 count) {
        count = _userGardensByType[user][gardenType].length;
    }

    /// @inheritdoc IGardenFactory
    function getGardenInfo(address garden) external view returns (address owner, bytes32 gardenType, bool registered) {
        owner = _gardenToOwner[garden];
        gardenType = _gardenToType[garden];
        registered = _gardens.contains(garden);
    }

    /// @inheritdoc IGardenFactory
    function getUserGardenInfos(address user)
        external
        view
        returns (address[] memory gardens, bytes32[] memory gardenTypes)
    {
        gardens = _userGardens[user];
        uint256 length = gardens.length;
        gardenTypes = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            gardenTypes[i] = _gardenToType[gardens[i]];
        }
    }
}
