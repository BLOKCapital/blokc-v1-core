// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { WithdrawFacet } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import { UniswapV2Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/UniswapV2Facet.sol";
import { UniswapV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import { CamelotV2Facet } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/CamelotV2Facet.sol";
import { CamelotV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/camelotV3Facet.sol";
import { AaveV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract RegisterUtilityFacets is BaseScript {
    address constant FACET_REGISTRY = 0xf56e5573210Eaec46E29B4C5B9F8670b76730b6b;

    // Module IDs
    bytes32 constant MODULE_WITHDRAW = keccak256("WITHDRAW");
    bytes32 constant MODULE_DEX = keccak256("DEX");
    bytes32 constant MODULE_YIELD = keccak256("YIELD");

    // Garden type IDs
    bytes32 constant YIELD_GARDEN = keccak256("YIELD");

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
        bytes4[] memory uniswapV2Selectors = new bytes4[](13);
        uniswapV2Selectors[0] = uniswapV2Facet.uniswapV2SwapExactTokensForTokens.selector;
        uniswapV2Selectors[1] = uniswapV2Facet.uniswapV2SwapTokensForExactTokens.selector;
        uniswapV2Selectors[2] = uniswapV2Facet.uniswapV2SwapExactETHForTokens.selector;
        uniswapV2Selectors[3] = uniswapV2Facet.uniswapV2SwapTokensForExactETH.selector;
        uniswapV2Selectors[4] = uniswapV2Facet.uniswapV2SwapExactTokensForETH.selector;
        uniswapV2Selectors[5] = uniswapV2Facet.uniswapV2SwapETHForExactTokens.selector;
        uniswapV2Selectors[6] = uniswapV2Facet.uniswapV2SwapExactTokensForTokensSupportingFeeOnTransferTokens.selector;
        uniswapV2Selectors[7] = uniswapV2Facet.uniswapV2SwapExactETHForTokensSupportingFeeOnTransferTokens.selector;
        uniswapV2Selectors[8] = uniswapV2Facet.uniswapV2SwapExactTokensForETHSupportingFeeOnTransferTokens.selector;
        uniswapV2Selectors[9] = uniswapV2Facet.uniswapV2GetAmountOut.selector;
        uniswapV2Selectors[10] = uniswapV2Facet.uniswapV2GetAmountIn.selector;
        uniswapV2Selectors[11] = uniswapV2Facet.uniswapV2GetAmountsOut.selector;
        uniswapV2Selectors[12] = uniswapV2Facet.uniswapV2GetAmountsIn.selector;
        console2.log("UniswapV2Facet deployed at:", address(uniswapV2Facet));

        // Uniswap V3
        UniswapV3Facet uniswapV3Facet = new UniswapV3Facet();
        bytes4[] memory uniswapV3Selectors = new bytes4[](6);
        uniswapV3Selectors[0] = uniswapV3Facet.uniswapV3ExactInputSingle.selector;
        uniswapV3Selectors[1] = uniswapV3Facet.uniswapV3ExactInput.selector;
        uniswapV3Selectors[2] = uniswapV3Facet.uniswapV3ExactOutputSingle.selector;
        uniswapV3Selectors[3] = uniswapV3Facet.uniswapV3ExactOutput.selector;
        uniswapV3Selectors[4] = uniswapV3Facet.getSqrtTwapX96.selector;
        uniswapV3Selectors[5] = uniswapV3Facet.getCombinedTwapX96.selector;
        console2.log("UniswapV3Facet deployed at:", address(uniswapV3Facet));

        // Camelot V2
        CamelotV2Facet camelotV2Facet = new CamelotV2Facet();
        bytes4[] memory camelotV2Selectors = new bytes4[](3);
        camelotV2Selectors[0] = camelotV2Facet.camelotV2ExactInputSingle.selector;
        camelotV2Selectors[1] = camelotV2Facet.camelotV2ExactInput.selector;
        camelotV2Selectors[2] = camelotV2Facet.camelotV2ExactOutputSingle.selector;
        console2.log("CamelotV2Facet deployed at:", address(camelotV2Facet));

        // Camelot V3
        CamelotV3Facet camelotV3Facet = new CamelotV3Facet();
        bytes4[] memory camelotV3Selectors = new bytes4[](4);
        camelotV3Selectors[0] = camelotV3Facet.camelotV3ExactInputSingle.selector;
        camelotV3Selectors[1] = camelotV3Facet.camelotV3ExactInput.selector;
        camelotV3Selectors[2] = camelotV3Facet.camelotV3ExactOutputSingle.selector;
        camelotV3Selectors[3] = camelotV3Facet.camelotV3ExactOutput.selector;
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
    }
}
