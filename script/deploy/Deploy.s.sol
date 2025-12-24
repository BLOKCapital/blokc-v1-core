// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { DiamondCutFacet } from "src/garden/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/garden/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/garden/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { SBTRegistry } from "src/GardenSBT/CollectionRegistry/SBTRegistry.sol";

contract Deploy is BaseScript {
    FacetRegistry internal facetRegistry;

    PoolRegistry internal poolRegistry;

    GardenFactory internal gardenFactory;

    ProtocolStatus internal protocolStatus;

    function run() public broadcaster {
        setUp();
        
        // Register default facets
        DiamondCutFacet cutFacet = new DiamondCutFacet{ salt: salt }();
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = cutFacet.diamondCut.selector;
        console2.log("DiamondCutFacet deployed at:", address(cutFacet));

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet{ salt: salt }();
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = loupeFacet.facets.selector;
        loupeSelectors[1] = loupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = loupeFacet.facetAddresses.selector;
        loupeSelectors[3] = loupeFacet.facetAddress.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;
        console2.log("DiamondLoupeFacet deployed at:", address(loupeFacet));

        OwnershipFacet ownershipFacet = new OwnershipFacet{ salt: salt }();
        bytes4[] memory ownableSelectors = new bytes4[](2);
        ownableSelectors[0] = ownershipFacet.owner.selector;
        ownableSelectors[1] = ownershipFacet.transferOwnership.selector;
        console2.log("OwnershipFacet deployed at:", address(ownershipFacet));

        UpgradeFacet upgradeFacet = new UpgradeFacet{ salt: salt }();
        bytes4[] memory upgradeSelectors = new bytes4[](3);
        upgradeSelectors[0] = upgradeFacet.upgrade.selector;
        upgradeSelectors[1] = upgradeFacet.getCurrentVersion.selector;
        upgradeSelectors[2] = upgradeFacet.upgradeDetails.selector;
        console2.log("UpgradeFacet deployed at:", address(upgradeFacet));

        address[4] memory baseFacets =
            [address(cutFacet), address(loupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseFacetFunctionSelectors = new bytes4[][](4);
        baseFacetFunctionSelectors[0] = cutSelectors;
        baseFacetFunctionSelectors[1] = loupeSelectors;
        baseFacetFunctionSelectors[2] = ownableSelectors;
        baseFacetFunctionSelectors[3] = upgradeSelectors;

        facetRegistry = new FacetRegistry{ salt: salt }(deployer, baseFacets, baseFacetFunctionSelectors);
        console2.log("FacetRegistry deployed at:", address(facetRegistry));

        // --- Deploy ProtocolStatus ---
        // For local testing: Use a placeholder ENS registry address (ENS won't resolve on Anvil)
        // For production: Use the actual ENS registry address (0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e)
        address ensRegistry = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;

        // For local testing: Use empty arrays to skip ENS resolution during construction
        // For production: Populate with actual ENS names
        bytes32[] memory initialNamehashes = new bytes32[](0);
        string[] memory initialNames = new string[](0);
        uint256[] memory initialExpiries = new uint256[](0);

        // Uncomment below for production deployment with ENS names:
        // bytes32[] memory initialNamehashes = new bytes32[](1);
        // string[] memory initialNames = new string[](1);
        // uint256[] memory initialExpiries = new uint256[](1);
        // initialNames[0] = "chintan.eth";
        // initialNamehashes[0] = keccak256(abi.encodePacked("chintan.eth"));
        // initialExpiries[0] = block.timestamp + 365 days;

        protocolStatus =
            new ProtocolStatus{ salt: salt }(deployer, ensRegistry, initialNamehashes, initialNames, initialExpiries);

        console2.log("ProtocolStatus deployed at:", address(protocolStatus));
        protocolStatus.activateProtocol();
        console2.log("ProtocolStatus activated");

        SBTRegistry sbtRegistry = new SBTRegistry(deployer);
        console2.log("SBTRegistry deployed at:", address(sbtRegistry));

        gardenFactory = new GardenFactory{ salt: salt }(
            deployer, address(facetRegistry), address(protocolStatus), address(sbtRegistry)
        );

        console2.log("GardenFactory deployed at:", address(gardenFactory));
    }
}
