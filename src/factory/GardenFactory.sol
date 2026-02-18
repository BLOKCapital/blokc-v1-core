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
import { ISBTRegistry } from "src/interfaces/ISBTRegistry.sol";

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

/// @notice Thrown when the sbt registry is not set
error GardenFactory_SBTRegistryNotSet();

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

    /// @notice The address of the SBT registry
    ISBTRegistry private _sbtRegistry;

    /// @notice The set of all gardens created by this factory
    EnumerableSet.AddressSet private _gardens;

    /// @notice Mapping of user address to array of their garden addresses
    mapping(address user => address[]) private _userGardens;

    /// @notice Mapping of user address to index (1-10) to garden address
    mapping(address user => mapping(uint256 index => address)) private _userIndexToGarden;

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
    /// @param sbtRegistry The address of the SBT registry contract
    constructor(
        address initialOwner,
        address facetRegistry,
        address protocolStatus,
        address sbtRegistry
    )
        Ownable(initialOwner)
    {
        _facetRegistry = facetRegistry;
        _protocolStatus = protocolStatus;
        _sbtRegistry = ISBTRegistry(sbtRegistry);

        if (_facetRegistry == address(0)) {
            revert GardenFactory_FacetRegistryNotSet();
        }
        if (_protocolStatus == address(0)) {
            revert GardenFactory_ProtocolStatusNotSet();
        }
        if (sbtRegistry == address(0)) {
            revert GardenFactory_SBTRegistryNotSet();
        }
    }

    // ========================================================================
    // External Functions
    // ========================================================================

    /// @inheritdoc IGardenFactory
    function createGarden(
        uint256 index,
        address collection,
        uint256 tokenId,
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

        // Mint SBT if collection is provided
        // if (collection != address(0) && block.chainid == 42_161) {
        //     _sbtRegistry.mintByAddress(collection, owner, tokenId);
        // }

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
}
