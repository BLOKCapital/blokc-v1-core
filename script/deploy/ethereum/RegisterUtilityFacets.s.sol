// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { WithdrawFacet } from "src/garden/facets/utilityFacets/ethereum/withdraw/WithdrawFacet.sol";
import { UniswapV2Facet } from "src/garden/facets/utilityFacets/ethereum/uniswapV2/UniswapV2Facet.sol";
import { UniswapV3Facet } from "src/garden/facets/utilityFacets/ethereum/uniswapV3/UniswapV3Facet.sol";
import { SushiSwapV3Facet } from "src/garden/facets/utilityFacets/ethereum/sushiSwapV3/SushiSwapV3Facet.sol";
import { BalancerV3Facet } from "src/garden/facets/utilityFacets/ethereum/balancerV3/BalancerV3Facet.sol";
import { IBalancerV3 } from "src/garden/facets/utilityFacets/ethereum/balancerV3/IBalancerV3.sol";

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract RegisterUtilityFacets is BaseScript {
    address constant FACET_REGISTRY = 0x51F061273398b93369F3C99520813656c779f293;

    // Module IDs
    bytes32 constant MODULE_WITHDRAW = keccak256("WITHDRAW");
    bytes32 constant MODULE_DEX = keccak256("DEX");
    bytes32 constant MODULE_YIELD = keccak256("YIELD");
    bytes32 constant MODULE_INDEX = keccak256("INDEX");

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

        // SushiSwap V3
        SushiSwapV3Facet sushiSwapV3Facet = new SushiSwapV3Facet();
        bytes4[] memory sushiSwapV3Selectors = new bytes4[](5);
        sushiSwapV3Selectors[0] = sushiSwapV3Facet.sushiSwapV3Swap.selector;
        sushiSwapV3Selectors[1] = sushiSwapV3Facet.sushiSwapV3Quote.selector;
        sushiSwapV3Selectors[2] = sushiSwapV3Facet.getSushiSqrtTwapX96.selector;
        sushiSwapV3Selectors[3] = sushiSwapV3Facet.getSushiCombinedTwapX96.selector;
        // this is important because sushiswap's pools call this callback during swaps, and it needs to be registered to route correctly through the diamond proxy
        sushiSwapV3Selectors[4] = sushiSwapV3Facet.uniswapV3SwapCallback.selector;
        console2.log("SushiSwapV3Facet deployed at:", address(sushiSwapV3Facet));
        // Balancer V3
        BalancerV3Facet balancerV3Facet = new BalancerV3Facet();
        bytes4[] memory balancerV3Selectors = new bytes4[](2);
        balancerV3Selectors[0] = IBalancerV3.balancerV3Swap.selector;
        balancerV3Selectors[1] = IBalancerV3.balancerV3Quote.selector;
        console2.log("BalancerV3Facet deployed at:", address(balancerV3Facet));

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
            facetAddress: address(sushiSwapV3Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sushiSwapV3Selectors
        });
        
        dexCuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(balancerV3Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: balancerV3Selectors
        });

        if (!registry.isModuleRegistered(MODULE_DEX)) {
            registry.registerModule(MODULE_DEX);
            console2.log("DEX module registered");
        }
        registry.upgradeModule(MODULE_DEX, dexCuts);
        console2.log("DEX module upgraded with UniswapV2, UniswapV3, BalancerV3 facets");

        // =====================================================================
        // INDEX module (IndexFacet)
        // =====================================================================
        // IndexFacet indexFacet = new IndexFacet();
        // bytes4[] memory indexSelectors = new bytes4[](7);
        // indexSelectors[0] = indexFacet.connectToIndex.selector;
        // indexSelectors[1] = indexFacet.disconnectFromIndex.selector;
        // indexSelectors[2] = indexFacet.rebalanceIntent.selector;
        // indexSelectors[3] = indexFacet.rebalance.selector;
        // indexSelectors[4] = indexFacet.isConnectedToIndex.selector;
        // indexSelectors[5] = indexFacet.getConnectedIndex.selector;
        // indexSelectors[6] = indexFacet.hasPendingIntent.selector;
        // console2.log("IndexFacet deployed at:", address(indexFacet));

        // IDiamondCut.FacetCut[] memory indexCuts = new IDiamondCut.FacetCut[](1);
        // indexCuts[0] = IDiamondCut.FacetCut({
        //     facetAddress: address(indexFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors:
        // indexSelectors });

        // if (!registry.isModuleRegistered(MODULE_INDEX)) {
        //     registry.registerModule(MODULE_INDEX);
        //     console2.log("INDEX module registered");
        // }
        // registry.upgradeModule(MODULE_INDEX, indexCuts);
        // console2.log("INDEX module upgraded with IndexFacet");

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
