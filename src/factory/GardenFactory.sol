// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title GardenFactory
    @author BLOK Capital DAO
    @notice Factory that deploys new gardens.
    NOTE: This contract is structured so that it can be a facet itself.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

//Should we implement functions to set facetRegistry, killSwitch, liquidityPoolRegistry, sbtCollectionRegistry?
//No because some gardens may create arb now, and when they they will try to create garden on other chain and those
// addresses will be different.

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
error GardenFactory_KillSwitchNotSet();
error GardenFactory_LiquidityPoolRegistryNotSet();

contract GardenFactory is Initializable, OwnableUpgradeable, IGardenFactory, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    /// @notice The address of the facet registry

    address facetRegistry;

    /// @notice The address of the kill switch
    address killSwitch;

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
        address _killSwitch,
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
        if (_killSwitch == address(0)) {
            revert GardenFactory_KillSwitchNotSet();
        }
        if (_liquidityPoolRegistry == address(0)) {
            revert GardenFactory_LiquidityPoolRegistryNotSet();
        }
        facetRegistry = _facetRegistry;
        killSwitch = _killSwitch;
        liquidityPoolRegistry = _liquidityPoolRegistry;

        emit FactoryInitialized(_initialOwner, _killSwitch, _facetRegistry, _liquidityPoolRegistry);
    }

    /// @inheritdoc IGardenFactory
    function createGarden(uint256 index) external nonReentrant returns (address gardenAddress) {
        address owner = msg.sender;
        if (facetRegistry == address(0)) {
            revert GardenFactory_FacetRegistryNotSet();
        }
        IFacetRegistry registry = IFacetRegistry(facetRegistry);
        address cutFacetAddress = registry.getFacetAddress(IDiamondCut.diamondCut.selector);
        address loupeFacetAddress = registry.getFacetAddress(IDiamondLoupe.facetAddress.selector);
        address ownableFacetAddress = registry.getFacetAddress(IERC173.owner.selector);
        address upgradeFacetAddress = registry.getFacetAddress(IUpgrade.upgrade.selector);

        IDiamondCut.FacetCut[] memory baseFacets = new IDiamondCut.FacetCut[](4);

        baseFacets[0] = IDiamondCut.FacetCut({
            facetAddress: cutFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: registry.getFacetFunctionSelectors(cutFacetAddress)
        });
        baseFacets[1] = IDiamondCut.FacetCut({
            facetAddress: loupeFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: registry.getFacetFunctionSelectors(loupeFacetAddress)
        });
        baseFacets[2] = IDiamondCut.FacetCut({
            facetAddress: ownableFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: registry.getFacetFunctionSelectors(ownableFacetAddress)
        });
        baseFacets[3] = IDiamondCut.FacetCut({
            facetAddress: upgradeFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: registry.getFacetFunctionSelectors(upgradeFacetAddress)
        });

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
        // bytes memory creationCode = type(Diamond).creationCode;
        // bytes memory initCode = abi.encodePacked(creationCode, abi.encode(params, facetRegistry, killSwitch));

        console.log("Deploying diamond");
        // gardenAddress = Create2.deploy(0, salt, initCode);

        // Deploy the Diamond contract using Create2
        Diamond garden = new Diamond{ salt: salt }(baseFacets, owner, facetRegistry, liquidityPoolRegistry, killSwitch);

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
