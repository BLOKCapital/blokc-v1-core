// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { WithdrawFacet } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import { UniswapV2Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/UniswapV2Facet.sol";
import { UniswapV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import { CamelotV2Facet } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/CamelotV2Facet.sol";
import { CamelotV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/CamelotV3Facet.sol";
import { AaveV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";
import { GmxV2Facet } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Facet.sol";
import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract RegisterUtilityFacets is BaseScript {
    address constant FACET_REGISTRY = 0x1e237507bb8520a253300b9e22bFccCd396E45cF;

    // Module IDs
    bytes32 constant MODULE_WITHDRAW = keccak256("WITHDRAW");
    bytes32 constant MODULE_DEX = keccak256("DEX");
    bytes32 constant MODULE_YIELD = keccak256("YIELD");
    bytes32 constant MODULE_INDEX = keccak256("INDEX");
    bytes32 constant MODULE_PERP = keccak256("PERP");

    // Garden type IDs
    bytes32 constant YIELD_GARDEN = keccak256("YIELD");
    bytes32 constant INDEX_GARDEN = keccak256("INDEX");

    function run() public broadcaster {
        setUp();

        IFacetRegistry registry = IFacetRegistry(FACET_REGISTRY);

        // =====================================================================
        // Withdraw module
        // =====================================================================
        WithdrawFacet withdrawFacet = new WithdrawFacet();
        bytes4[] memory withdrawFacetSelectors = new bytes4[](1);
        withdrawFacetSelectors[0] = withdrawFacet.withdrawUsdc.selector;
        console2.log("WithdrawFacet deployed at:", address(withdrawFacet));

        IDiamondCut.FacetCut[] memory withdrawCuts = new IDiamondCut.FacetCut[](1);
        withdrawCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(withdrawFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: withdrawFacetSelectors
        });

        if (!registry.isModuleRegistered(MODULE_WITHDRAW)) {
            registry.registerModule(MODULE_WITHDRAW);
            console2.log("WITHDRAW module registered");
        }
        registry.upgradeModule(MODULE_WITHDRAW, withdrawCuts);
        console2.log("WITHDRAW module upgraded with WithdrawFacet");

        // =====================================================================
        // DEX module (Uniswap V2, Uniswap V3, Camelot V2, Camelot V3)
        // =====================================================================

        // Uniswap V2
        UniswapV2Facet uniswapV2Facet = new UniswapV2Facet();
        bytes4[] memory uniswapV2Selectors = new bytes4[](6);
        uniswapV2Selectors[0] = uniswapV2Facet.uniswapV2Swap.selector;
        uniswapV2Selectors[1] = uniswapV2Facet.uniswapV2Quote.selector;
        uniswapV2Selectors[2] = uniswapV2Facet.uniswapV2GetAmountOut.selector;
        uniswapV2Selectors[3] = uniswapV2Facet.uniswapV2GetAmountIn.selector;
        uniswapV2Selectors[4] = uniswapV2Facet.uniswapV2GetAmountsOut.selector;
        uniswapV2Selectors[5] = uniswapV2Facet.uniswapV2GetAmountsIn.selector;
        console2.log("UniswapV2Facet deployed at:", address(uniswapV2Facet));

        // Uniswap V3
        UniswapV3Facet uniswapV3Facet = new UniswapV3Facet();
        bytes4[] memory uniswapV3Selectors = new bytes4[](4);
        uniswapV3Selectors[0] = uniswapV3Facet.uniswapV3Swap.selector;
        uniswapV3Selectors[1] = uniswapV3Facet.getSqrtTwapX96.selector;
        uniswapV3Selectors[2] = uniswapV3Facet.getCombinedTwapX96.selector;
        uniswapV3Selectors[3] = uniswapV3Facet.uniswapV3Quote.selector;
        console2.log("UniswapV3Facet deployed at:", address(uniswapV3Facet));

        // Camelot V2
        CamelotV2Facet camelotV2Facet = new CamelotV2Facet();
        bytes4[] memory camelotV2Selectors = new bytes4[](2);
        camelotV2Selectors[0] = camelotV2Facet.camelotV2Swap.selector;
        camelotV2Selectors[1] = camelotV2Facet.camelotV2Quote.selector;
        console2.log("CamelotV2Facet deployed at:", address(camelotV2Facet));

        // Camelot V3
        CamelotV3Facet camelotV3Facet = new CamelotV3Facet();
        bytes4[] memory camelotV3Selectors = new bytes4[](3);
        camelotV3Selectors[0] = camelotV3Facet.camelotV3Swap.selector;
        camelotV3Selectors[1] = camelotV3Facet.camelotV3GetSqrtTwapX96.selector;
        camelotV3Selectors[2] = camelotV3Facet.camelotV3Quote.selector;
        console2.log("CamelotV3Facet deployed at:", address(camelotV3Facet));

        IDiamondCut.FacetCut[] memory dexCuts = new IDiamondCut.FacetCut[](4);
        dexCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapV2Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: uniswapV2Selectors
        });
        dexCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapV3Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: uniswapV3Selectors
        });
        dexCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(camelotV2Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: camelotV2Selectors
        });
        dexCuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(camelotV3Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: camelotV3Selectors
        });

        if (!registry.isModuleRegistered(MODULE_DEX)) {
            registry.registerModule(MODULE_DEX);
            console2.log("DEX module registered");
        }
        registry.upgradeModule(MODULE_DEX, dexCuts);
        console2.log("DEX module upgraded with UniswapV2, UniswapV3, CamelotV2, CamelotV3 facets");

        // =====================================================================
        // YIELD module (Aave V3, Pendle V2)
        // =====================================================================
        AaveV3Facet aaveV3Facet = new AaveV3Facet();
        bytes4[] memory aaveSelectors = new bytes4[](3);
        aaveSelectors[0] = aaveV3Facet.aaveV3GetReserveData.selector;
        aaveSelectors[1] = aaveV3Facet.aaveV3Lend.selector;
        aaveSelectors[2] = aaveV3Facet.aaveV3Withdraw.selector;
        console2.log("AaveV3Facet deployed at:", address(aaveV3Facet));

        IDiamondCut.FacetCut[] memory yieldCuts = new IDiamondCut.FacetCut[](1);
        yieldCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(aaveV3Facet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: aaveSelectors
        });

        if (!registry.isModuleRegistered(MODULE_YIELD)) {
            registry.registerModule(MODULE_YIELD);
            console2.log("YIELD module registered");
        }
        registry.upgradeModule(MODULE_YIELD, yieldCuts);
        console2.log("YIELD module upgraded with AaveV3 and PendleV2 facets");

        // YIELD_GARDEN allowed modules: BASE (implicit), YIELD_MODULE, WITHDRAW_MODULE, DEX_MODULE
        if (!registry.isGardenTypeRegistered(YIELD_GARDEN)) {
            bytes32[] memory yieldGardenModules = new bytes32[](3);
            yieldGardenModules[0] = MODULE_YIELD;
            yieldGardenModules[1] = MODULE_WITHDRAW;
            yieldGardenModules[2] = MODULE_DEX;
            registry.addGardenType(YIELD_GARDEN, yieldGardenModules);
            console2.log("YIELD_GARDEN type registered");
        }

        // =====================================================================
        // PERP module (GMX V2)
        // =====================================================================
        // The three afterOrder* selectors MUST be registered alongside the user-facing ones. They are the
        // entry points GMX keepers call to report execution, cancellation and freezing — including
        // liquidations and ADLs. If they are not routable through the diamond, GMX's callbacks hit the
        // fallback and position state silently stops tracking the real position.
        GmxV2Facet gmxV2Facet = new GmxV2Facet();
        bytes4[] memory gmxSelectors = new bytes4[](15);
        gmxSelectors[0] = gmxV2Facet.gmxV2OpenShort.selector;
        gmxSelectors[1] = gmxV2Facet.gmxV2CloseShort.selector;
        gmxSelectors[2] = gmxV2Facet.gmxV2AddCollateral.selector;
        gmxSelectors[3] = gmxV2Facet.gmxV2CancelOrder.selector;
        gmxSelectors[4] = gmxV2Facet.gmxV2RegisterCallback.selector;
        gmxSelectors[5] = gmxV2Facet.gmxV2UpdateConfig.selector;
        gmxSelectors[6] = gmxV2Facet.gmxV2GetPosition.selector;
        gmxSelectors[7] = gmxV2Facet.gmxV2GetActivePositions.selector;
        gmxSelectors[8] = gmxV2Facet.gmxV2GetTotalCollateral.selector;
        gmxSelectors[9] = gmxV2Facet.gmxV2GetActivePositionCount.selector;
        gmxSelectors[10] = gmxV2Facet.gmxV2GetConfig.selector;
        gmxSelectors[11] = gmxV2Facet.gmxV2GetPositionPnL.selector;
        gmxSelectors[12] = gmxV2Facet.afterOrderExecution.selector;
        gmxSelectors[13] = gmxV2Facet.afterOrderCancellation.selector;
        gmxSelectors[14] = gmxV2Facet.afterOrderFrozen.selector;
        console2.log("GmxV2Facet deployed at:", address(gmxV2Facet));

        IDiamondCut.FacetCut[] memory perpCuts = new IDiamondCut.FacetCut[](1);
        perpCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(gmxV2Facet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: gmxSelectors
        });

        if (!registry.isModuleRegistered(MODULE_PERP)) {
            registry.registerModule(MODULE_PERP);
            console2.log("PERP module registered");
        }
        registry.upgradeModule(MODULE_PERP, perpCuts);
        console2.log("PERP module upgraded with GmxV2Facet");

        // =====================================================================
        // INDEX module (IndexFacet)
        // =====================================================================
        IndexFacet indexFacet = new IndexFacet();
        bytes4[] memory indexSelectors = new bytes4[](7);
        indexSelectors[0] = indexFacet.connectToIndex.selector;
        indexSelectors[1] = indexFacet.disconnectFromIndex.selector;
        indexSelectors[2] = indexFacet.rebalanceIntent.selector;
        indexSelectors[3] = indexFacet.rebalance.selector;
        indexSelectors[4] = indexFacet.isConnectedToIndex.selector;
        indexSelectors[5] = indexFacet.getConnectedIndex.selector;
        indexSelectors[6] = indexFacet.hasPendingIntent.selector;
        console2.log("IndexFacet deployed at:", address(indexFacet));

        IDiamondCut.FacetCut[] memory indexCuts = new IDiamondCut.FacetCut[](1);
        indexCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(indexFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: indexSelectors
        });

        if (!registry.isModuleRegistered(MODULE_INDEX)) {
            registry.registerModule(MODULE_INDEX);
            console2.log("INDEX module registered");
        }
        registry.upgradeModule(MODULE_INDEX, indexCuts);
        console2.log("INDEX module upgraded with IndexFacet");

        // =====================================================================
        // Garden types
        // =====================================================================
        // INDEX_GARDEN allowed modules: BASE (implicit), DEX_MODULE, WITHDRAW_MODULE, INDEX_MODULE
        if (!registry.isGardenTypeRegistered(INDEX_GARDEN)) {
            bytes32[] memory indexGardenModules = new bytes32[](3);
            indexGardenModules[0] = MODULE_DEX;
            indexGardenModules[1] = MODULE_WITHDRAW;
            indexGardenModules[2] = MODULE_INDEX;
            registry.addGardenType(INDEX_GARDEN, indexGardenModules);
            console2.log("INDEX_GARDEN type registered");
        }
    }
}
