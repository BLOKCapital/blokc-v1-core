//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IndexCalculationRegistry } from "src/indices/IndexCalculationRegistry.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { HardcodedCirculatingSupply } from "src/indices/HardcodedCirculatingSupply.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

contract RegisterIndexComponent is BaseScript {
    address INDEX_COMPONENT_REGISTRY = 0x3F8291D2Fb3f5C4391DDbc36C4Ee0B1F48274977;
    address LIQUIDITY_POOL_REGISTRY = 0xA3178280c191dD46c551b91c651F337E47594d85;
    address HARDCODED_CIRCULATING_SUPPLY = 0x5FB79EfdD1a64063dc5B560AF1150D7d41224171;
    bytes32 uniswapV3 = keccak256("UNISWAP_V3");
    bytes32 ZRO = bytes32("ZRO");

    address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address zro = 0x6985884C4392D348587B19cb9eAAf157F13271cd;

    function run() public broadcaster {
        setUp();
        IndexComponentRegistry indexComponentRegistry = IndexComponentRegistry(INDEX_COMPONENT_REGISTRY);
        ILiquidityPoolRegistry liquidityPoolRegistry = ILiquidityPoolRegistry(LIQUIDITY_POOL_REGISTRY);
        HardcodedCirculatingSupply hardcodedCirculatingSupply = HardcodedCirculatingSupply(HARDCODED_CIRCULATING_SUPPLY);

        // Register new component
        IndexComponentRegistry.Component[] memory newComponents = new IndexComponentRegistry.Component[](1);
        newComponents[0] = IndexComponentRegistry.Component({
            symbol: ZRO,
            tokenAddress: 0x6985884C4392D348587B19cb9eAAf157F13271cd,
            priceFeedAddress: 0x1940fEd49cDBC397941f2D336eb4994D599e568B,
            heartbeat: 3600
        });

        indexComponentRegistry.registerComponents(newComponents);

        // Set circulating supply for new component
        bytes32[] memory symbols = new bytes32[](1);
        symbols[0] = ZRO;
        uint256[] memory supplies = new uint256[](1);
        supplies[0] = 314_994_378;

        hardcodedCirculatingSupply.setSupplies(symbols, supplies);

        // Register liquidity pool for new component
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x4CEf551255EC96d89feC975446301b5C4e164C59,
                tokenA: zro,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "ZRO/WETH"
            })
        );
    }
}
