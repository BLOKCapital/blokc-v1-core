// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title GardenFactory
    @author BLOK Capital DAO
    @notice Factory contract that deploys new garden (Diamond) contracts using CREATE2.
    @dev This contract uses the Transparent Proxy pattern and is upgradeable.
         It uses OpenZeppelin's upgradeable contracts library for security and reliability.
         Each user can deploy up to 10 gardens, identified by indices 1-10.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Upgradeable Contracts
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// OpenZeppelin Standard Contracts
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Local Interfaces
import { IGardenFactory } from "src/interfaces/IGardenFactory.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

// Local Contracts
import { Diamond } from "src/diamond/Diamond.sol";

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

contract GardenFactory is Initializable, OwnableUpgradeable, IGardenFactory, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ========================================================================
    // State Variables
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

    /// @notice Initializes the factory contract
    /// @dev This function should be called during proxy deployment via the proxy's initialization mechanism
    /// @param initialOwner The address that will be the owner of this factory
    /// @param facetRegistry The address of the facet registry contract
    /// @param protocolStatus The address of the protocol status contract
    function initialize(address initialOwner, address facetRegistry, address protocolStatus) public initializer {
        __Ownable_init(initialOwner);
        _facetRegistry = facetRegistry;
        _protocolStatus = protocolStatus;
        if (_facetRegistry == address(0)) {
            revert GardenFactory_FacetRegistryNotSet();
        }
        if (_protocolStatus == address(0)) {
            revert GardenFactory_ProtocolStatusNotSet();
        }
        __ReentrancyGuard_init();

        emit FactoryInitialized(initialOwner);
    }

    // ========================================================================
    // External Functions
    // ========================================================================

    /// @notice Creates a new garden (Diamond) contract for the caller
    /// @dev The garden is deployed using CREATE2 with a deterministic address based on the owner, index, and factory.
    ///      Each user can deploy up to 10 gardens (indices 1-10). The garden is initialized with base facets
    ///      retrieved from the facet registry.
    /// @param index The per-user garden index (must be between 1 and 10, inclusive)
    /// @return gardenAddress The address of the newly deployed garden contract
    function createGarden(uint256 index) external nonReentrant returns (address gardenAddress) {
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

        // Get base facets from registry
        IFacetRegistry registry = IFacetRegistry(_facetRegistry);
        address[4] memory baseFacets = registry.getBaseFacets();

        // Validate all base facets are registered
        for (uint256 i = 0; i < baseFacets.length; i++) {
            if (baseFacets[i] == address(0)) {
                revert GardenFactory_DefaultFacetNotRegistered();
            }
        }

        // Build diamond cut structure with all base facets
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](baseFacets.length);
        for (uint256 i = 0; i < baseFacets.length; i++) {
            diamondCut[i] = IDiamondCut.FacetCut({
                facetAddress: baseFacets[i],
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: registry.getFacetFunctionSelectors(baseFacets[i])
            });
        }

        // Generate deterministic salt for CREATE2 deployment
        bytes32 salt = keccak256(abi.encode(owner, index, address(this)));

        // Deploy the Diamond contract using CREATE2
        Diamond garden = new Diamond{ salt: salt }(diamondCut, owner, _facetRegistry, _protocolStatus);

        gardenAddress = address(garden);

        // Register the garden
        _gardens.add(gardenAddress);
        _userGardens[owner].push(gardenAddress);
        _userIndexToGarden[owner][index] = gardenAddress;

        emit GardenCreated(gardenAddress, owner, index);
    }

    /// @notice Returns all gardens created by this factory
    /// @return gardens_ Array of all registered garden addresses
    function getAllGardens() external view returns (address[] memory gardens_) {
        gardens_ = _gardens.values();
    }

    /// @notice Returns all gardens created by a specific user
    /// @param user The address of the user
    /// @return gardens_ Array of garden addresses created by the specified user
    function getUserGardens(address user) external view returns (address[] memory gardens_) {
        gardens_ = _userGardens[user];
    }

    /// @notice Returns the garden address associated with a specific user and index
    /// @param user The address of the user (owner)
    /// @param index The per-user garden index (1-10)
    /// @return The address of the garden associated with the given user and index, or address(0) if not found
    function getGarden(address user, uint256 index) external view returns (address) {
        return _userIndexToGarden[user][index];
    }

    /// @notice Checks if a garden address is registered in this factory
    /// @param garden The address of the garden to check
    /// @return True if the garden is registered, false otherwise
    function isGardenRegistered(address garden) external view returns (bool) {
        return _gardens.contains(garden);
    }
}
