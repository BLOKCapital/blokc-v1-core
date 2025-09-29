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

import { IGardenFactory } from "src/interfaces/IGardenFactory.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/IDiamondLoupe.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IUpgrade } from "src/interfaces/IUpgrade.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { console } from "forge-std/console.sol";

error GardenFactory_FacetRegistryNotSet();
error GardenFactory_NFTAlreadyUsed(uint256 nftId);
error GardenFactory_LoupeNotSupported();
error GardenFactory_DefaultFacetNotRegistered();
error GardenFactory_GardenAlreadyRegistered();

contract GardenFactory is Initializable, OwnableUpgradeable, IGardenFactory {
    /// @notice The address of the facet registry
    address facetRegistry;
    /// @notice The address of the kill switch
    address killSwitch;
    /// @notice The address of the liquidity pool registry
    address liquidityPoolRegistry;
    /// @notice The set of all gardens created by the factory
    address[] gardens;
    /// @notice A mapping of user address to the set of gardens they have
    mapping(address user => address[]) userGardens;
    /// @notice A mapping of NFT ID to the garden address
    mapping(uint256 nftId => address) nftToGarden;

    event GardenCreated(address garden, address owner);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        address _facetRegistry,
        address _killSwitch,
        address _liquidityPoolRegistry
    )
        public
        initializer
    {
        __Ownable_init(_initialOwner);

        facetRegistry = _facetRegistry;
        killSwitch = _killSwitch;
        liquidityPoolRegistry = _liquidityPoolRegistry;
    }

    /// @inheritdoc IGardenFactory
    function createGarden(uint256 nftId) external returns (address gardenAddress) {
        address owner = msg.sender;
        if (facetRegistry == address(0)) {
            revert GardenFactory_FacetRegistryNotSet();
        }
        IFacetRegistry registry = IFacetRegistry(facetRegistry);
        address cutFacetAddress = registry.getFacetAddress(IDiamondCut.diamondCut.selector);
        address loupeFacetAddress = registry.getFacetAddress(IDiamondLoupe.facetAddress.selector);
        address ownableFacetAddress = registry.getFacetAddress(IERC173.owner.selector);
        address upgradeFacetAddress = registry.getFacetAddress(IUpgrade.upgrade.selector);

        if (
            cutFacetAddress == address(0) || loupeFacetAddress == address(0) || ownableFacetAddress == address(0)
                || upgradeFacetAddress == address(0)
        ) {
            revert GardenFactory_DefaultFacetNotRegistered();
        }
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

        // Generate a unique salt using the owner address and nftId
        bytes32 salt = keccak256(abi.encode(owner, nftId));
        if (nftToGarden[nftId] != address(0)) {
            revert GardenFactory_NFTAlreadyUsed(nftId);
        }
        // bytes memory creationCode = type(Diamond).creationCode;
        // bytes memory initCode = abi.encodePacked(creationCode, abi.encode(params, facetRegistry, killSwitch));

        console.log("Deploying diamond");
        // gardenAddress = Create2.deploy(0, salt, initCode);

        // Deploy the Diamond contract using Create2
        Diamond garden = new Diamond{ salt: salt }(baseFacets, owner, facetRegistry, liquidityPoolRegistry, killSwitch);

        gardenAddress = address(garden);

        gardens.push(gardenAddress);

        userGardens[owner].push(gardenAddress);

        nftToGarden[nftId] = gardenAddress;

        // Emit event for garden creation
        emit GardenCreated(gardenAddress, owner);
    }

    /// @inheritdoc IGardenFactory
    function getAllGardens() external view returns (address[] memory gardens_) {
        gardens_ = gardens;
    }

    /// @inheritdoc IGardenFactory
    function getUserGardens(address user) external view returns (address[] memory gardens_) {
        gardens_ = userGardens[user];
    }

    /// @inheritdoc IGardenFactory
    function getGarden(uint256 nftId) external view returns (address) {
        return nftToGarden[nftId];
    }

    /// @inheritdoc IGardenFactory
    function isGardenRegistered(address garden) external view returns (bool) {
        for (uint256 i; i < gardens.length; i++) {
            if (garden == gardens[i]) {
                return true;
            }
        }
        return false;
    }
}
