// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title GardenFactory
    @author BLOK Capital DAO
    @notice Factory that deploys new gardens.
    @dev This contract is a implementation of Transparent Proxy pattern with upgradeability.
    It uses OpenZeppelin's upgradeable contracts library for security and reliability.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { console } from "forge-std/console.sol";
import { IGardenFactory } from "src/interfaces/IGardenFactory.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/IDiamondLoupe.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IUpgrade } from "src/interfaces/IUpgrade.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

error GardenFactory_FacetRegistryNotSet();
error GardenFactory_IndexAlreadyUsed(address user, uint256 index);
error GardenFactory_LoupeNotSupported();
error GardenFactory_DefaultFacetNotRegistered();
error GardenFactory_GardenAlreadyRegistered();
error GardenFactory_IndexOutOfRange(uint256 index);
error GardenFactory_ProtocolStatusNotSet();
error GardenFactory_LiquidityPoolRegistryNotSet();

contract GardenFactory is Initializable, OwnableUpgradeable, IGardenFactory, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    /// @notice The address of the facet registry

    address facetRegistry;

    /// @notice The address of the kill switch
    address protocolStatus;

    /// @notice The address of the liquidity pool registry
    address liquidityPoolRegistry;

    /// @notice The set of all gardens created by the factory
    EnumerableSet.AddressSet private gardens;

    /// @notice A mapping of user address to the set of gardens they have
    mapping(address user => address[]) userGardens;

    /// @notice A mapping of user -> index (1..10) -> garden address
    mapping(address user => mapping(uint256 index => address)) userIndexToGarden;

    event GardenCreated(address garden, address owner, uint256 index);
    event FactoryInitialized(
        address initialOwner, address killSwitch, address facetRegistry, address liquidityPoolRegistry
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        address _protocolStatus,
        address _facetRegistry,
        address _liquidityPoolRegistry
    )
        public
        initializer
    {
        __Ownable_init(_initialOwner);

        if (_facetRegistry == address(0)) {
            revert GardenFactory_FacetRegistryNotSet();
        }
        if (_protocolStatus == address(0)) {
            revert GardenFactory_ProtocolStatusNotSet();
        }
        if (_liquidityPoolRegistry == address(0)) {
            revert GardenFactory_LiquidityPoolRegistryNotSet();
        }
        facetRegistry = _facetRegistry;
        protocolStatus = _protocolStatus;
        liquidityPoolRegistry = _liquidityPoolRegistry;

        emit FactoryInitialized(_initialOwner, _protocolStatus, _facetRegistry, _liquidityPoolRegistry);
    }

    /// @inheritdoc IGardenFactory
    function createGarden(uint256 index) external nonReentrant returns (address gardenAddress) {
        address owner = msg.sender;
        if (facetRegistry == address(0)) {
            revert GardenFactory_FacetRegistryNotSet();
        }

        IFacetRegistry registry = IFacetRegistry(facetRegistry);

        address[4] memory baseFacets = registry.getBaseFacets();

        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](4);

        for (uint256 i = 0; i < baseFacets.length; i++) {
            if (baseFacets[i] == address(0)) {
                revert GardenFactory_DefaultFacetNotRegistered();
            }
            diamondCut[i] = IDiamondCut.FacetCut({
                facetAddress: baseFacets[i],
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: registry.getFacetFunctionSelectors(baseFacets[i])
            });
        }

        // index must be between 1 and 10 (inclusive) per user
        if (index < 1 || index > 10) {
            revert GardenFactory_IndexOutOfRange(index);
        }

        // ensure the user hasn't already used this index
        if (userIndexToGarden[owner][index] != address(0)) {
            revert GardenFactory_IndexAlreadyUsed(owner, index);
        }

        // Generate a unique salt using the owner address and index
        bytes32 salt = keccak256(abi.encode(owner, index, address(this)));

        console.log("Deploying diamond");

        // Deploy the Diamond contract using Create2
        Diamond garden =
            new Diamond{ salt: salt }(diamondCut, owner, facetRegistry, liquidityPoolRegistry, protocolStatus);

        gardenAddress = address(garden);

        gardens.add(gardenAddress);

        userGardens[owner].push(gardenAddress);

        userIndexToGarden[owner][index] = gardenAddress;

        // Emit event for garden creation including the user index
        emit GardenCreated(gardenAddress, owner, index);
    }

    /// @inheritdoc IGardenFactory
    function getAllGardens() external view returns (address[] memory gardens_) {
        gardens_ = gardens.values();
    }

    /// @inheritdoc IGardenFactory
    function getUserGardens(address user) external view returns (address[] memory gardens_) {
        gardens_ = userGardens[user];
    }

    /// @inheritdoc IGardenFactory
    function getGarden(address user, uint256 index) external view returns (address) {
        return userIndexToGarden[user][index];
    }

    /// @inheritdoc IGardenFactory
    function isGardenRegistered(address garden) external view returns (bool) {
        return gardens.contains(garden);
    }
}
