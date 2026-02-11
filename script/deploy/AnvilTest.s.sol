//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { SBTRegistry } from "src/GardenSBT/CollectionRegistry/SBTRegistry.sol";
import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";

import {
    RewardCollectionFacet
} from "src/garden/facets/utilityFacets/arbitrumOne/rewardCollection/RewardCollectionFacet.sol";
import { WithdrawFacet } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import { UniswapV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import { AaveV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";
import { DiamondCutFacet } from "src/garden/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/garden/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/garden/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";

contract AnvilTest is BaseScript {
    FacetRegistry internal facetRegistry;

    LiquidityPoolRegistry internal liquidityPoolRegistry;

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

        // --- Register utility facets ---
        WithdrawFacet withdrawFacet = new WithdrawFacet();
        bytes4[] memory withdrawFacetSelectors = new bytes4[](1);
        withdrawFacetSelectors[0] = withdrawFacet.withdrawUsdc.selector;

        console2.log("WithdrawFacet deployed at:", address(withdrawFacet));

        UniswapV3Facet uniswapFacet = new UniswapV3Facet();
        bytes4[] memory uniswapFacetSelectors = new bytes4[](6);
        uniswapFacetSelectors[0] = UniswapV3Facet.uniswapV3ExactInputSingle.selector;
        uniswapFacetSelectors[1] = UniswapV3Facet.uniswapV3ExactInput.selector;
        uniswapFacetSelectors[2] = UniswapV3Facet.uniswapV3ExactOutputSingle.selector;
        uniswapFacetSelectors[3] = UniswapV3Facet.uniswapV3ExactOutput.selector;
        uniswapFacetSelectors[4] = UniswapV3Facet.getSqrtTwapX96.selector;
        uniswapFacetSelectors[5] = UniswapV3Facet.getCombinedTwapX96.selector;

        console2.log("UniswapV3Facet deployed at:", address(uniswapFacet));

        AaveV3Facet aaveFacet = new AaveV3Facet();
        bytes4[] memory aaveFacetSelectors = new bytes4[](3);
        aaveFacetSelectors[0] = AaveV3Facet.getReserveDataAaveV3.selector;
        aaveFacetSelectors[1] = AaveV3Facet.lendAaveV3.selector;
        aaveFacetSelectors[2] = AaveV3Facet.withdrawAaveV3.selector;

        console2.log("AaveV3Facet deployed at:", address(aaveFacet));

        RewardCollectionFacet rewardCollectionFacet = new RewardCollectionFacet();
        bytes4[] memory rewardCollectionFacetSelectors = new bytes4[](8);
        rewardCollectionFacetSelectors[0] = RewardCollectionFacet.name.selector;
        rewardCollectionFacetSelectors[1] = RewardCollectionFacet.symbol.selector;
        rewardCollectionFacetSelectors[2] = RewardCollectionFacet.tokenURI.selector;
        rewardCollectionFacetSelectors[3] = RewardCollectionFacet.transferFrom.selector;
        rewardCollectionFacetSelectors[4] = RewardCollectionFacet.mint.selector;
        rewardCollectionFacetSelectors[5] = RewardCollectionFacet.burn.selector;
        rewardCollectionFacetSelectors[6] = RewardCollectionFacet.ownerOf.selector;
        rewardCollectionFacetSelectors[7] = RewardCollectionFacet.balanceOf.selector;
        console2.log("RewardCollectionFacet deployed at:", address(rewardCollectionFacet));

        IndexFacet indexFacet = new IndexFacet();
        bytes4[] memory indexFacetSelectors = new bytes4[](4);
        indexFacetSelectors[0] = indexFacet.connectToIndex.selector;
        indexFacetSelectors[1] = indexFacet.disconnectFromIndex.selector;
        indexFacetSelectors[2] = indexFacet.rebalance.selector;
        indexFacetSelectors[3] = indexFacet.isConnectedToIndex.selector;

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](5);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(withdrawFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: withdrawFacetSelectors
        });
        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: uniswapFacetSelectors
        });
        facetCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(aaveFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: aaveFacetSelectors
        });
        facetCuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(rewardCollectionFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: rewardCollectionFacetSelectors
        });
        facetCuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(indexFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: indexFacetSelectors
        });

        // TODO: Update moduleId to match the appropriate module
        bytes32 moduleId = keccak256("DEX");
        FacetRegistry(address(facetRegistry)).upgradeModule(moduleId, facetCuts);
        console2.log("Utility facets registered");

        // --- Deploy ProtocolStatus ---
        // For local testing: Use a placeholder ENS registry address (ENS won't resolve on Anvil)
        // For production: Use the actual ENS registry address (0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e)
        address ensRegistry = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;

        // For local testing: Use empty arrays to skip ENS resolution during construction
        // For production: Populate with actual ENS names
        bytes32[] memory initialNamehashes = new bytes32[](0);
        string[] memory initialNames = new string[](0);
        uint256[] memory initialExpiries = new uint256[](0);

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

        address gardenAddress = GardenFactory(address(gardenFactory)).createGarden(1, address(0), 0);
        console2.log("Garden deployed at:", gardenAddress);

        (,,, bytes32 hashData) = UpgradeFacet(gardenAddress).upgradeDetails();
        console2.logBytes32(hashData);
        UpgradeFacet(gardenAddress).upgrade(hashData);

        RewardCollectionFacet(gardenAddress).mint(1);
        console2.log("NFT minted");

        address owner = RewardCollectionFacet(gardenAddress).ownerOf(1);
        console2.log("Owner of NFT:", owner);

        console2.log("NFT tokenURI:", RewardCollectionFacet(gardenAddress).tokenURI(1));

        console2.log("NFT balance of owner:", RewardCollectionFacet(gardenAddress).balanceOf(owner));

        console2.log("NFT name:", RewardCollectionFacet(gardenAddress).name());
        console2.log("NFT symbol:", RewardCollectionFacet(gardenAddress).symbol());
    }
}
