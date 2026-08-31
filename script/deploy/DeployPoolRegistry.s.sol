//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IUniswapV3 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { IUniswapV2 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/IUniswapV2.sol";
import { ICamelotV3 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/ICamelotV3.sol";
import { ICamelotV2 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/ICamelotV2.sol";
import { ArbitrumOneAddresses } from "src/garden/libraries/ArbitrumOneAddresses.sol";
import { console2 } from "forge-std/console2.sol";

/// @dev Minimal pair interface: every pool this registry seeds (UniV3, UniV2,
///      CamelotV2, CamelotV3/Algebra) exposes token0()/token1().
interface IMinimalPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract DeployLiquidityPoolRegistry is BaseScript {
    function run() public broadcaster {
        setUp();
        LiquidityPoolRegistry liquidityPoolRegistry = new LiquidityPoolRegistry{ salt: salt }(deployer);
        console2.log("LiquidityPoolRegistry deployed at:", address(liquidityPoolRegistry));

        // Hard gate: the four arbitrumOne DEX bases reach this registry through the compile-time
        // ArbitrumOneAddresses.POOL_REGISTRY_ADDRESS constant (re-exported by each base). Stale
        // constants would deploy successfully while pointing the facets at the old protocol — abort.
        // (The IndexFacet's registry address is deployer-configured at install via
        // configureIndexModule, so no constant to gate there.)
        require(
            ArbitrumOneAddresses.POOL_REGISTRY_ADDRESS == address(liquidityPoolRegistry),
            "stale POOL_REGISTRY_ADDRESS constant: update ArbitrumOneAddresses to the fresh address"
        );

        // =====================================================================
        // Token Addresses (Arbitrum One)
        // =====================================================================
        address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Native USDC
        address usdce = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // Bridged USDC.e
        address usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        address wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
        address arb = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        address dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        address gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
        address link = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
        address uni = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
        address pendle = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
        address rdnt = 0x3082CC23568eA640225c2467653dB90e9250AaA0;
        address magic = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;
        address grail = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8;
        address grt = 0x9623063377AD1B27544C965cCd7342f7EA7e88C7;
        address crv = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;
        address aave = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
        address zro = 0x6985884C4392D348587B19cb9eAAf157F13271cd;

        // =====================================================================
        // DEX Identifiers
        // =====================================================================
        bytes32 uniswapV3 = keccak256("UNISWAP_V3");
        bytes32 uniswapV2 = keccak256("UNISWAP_V2");
        bytes32 camelotV2 = keccak256("CAMELOT_V2");
        bytes32 camelotV3 = keccak256("CAMELOT_V3");

        // =====================================================================
        //  REGISTER DEXes (must be done before adding pools)
        // =====================================================================

        liquidityPoolRegistry.registerDex(
            uniswapV3, IUniswapV3.uniswapV3Swap.selector, IUniswapV3.uniswapV3Quote.selector
        );
        liquidityPoolRegistry.registerDex(
            uniswapV2, IUniswapV2.uniswapV2Swap.selector, IUniswapV2.uniswapV2Quote.selector
        );
        liquidityPoolRegistry.registerDex(
            camelotV3, ICamelotV3.camelotV3Swap.selector, ICamelotV3.camelotV3Quote.selector
        );
        liquidityPoolRegistry.registerDex(
            camelotV2, ICamelotV2.camelotV2Swap.selector, ICamelotV2.camelotV2Quote.selector
        );

        // =====================================================================
        //  UNISWAP V3 POOLS
        // =====================================================================

        // 1. WETH/USDC - 0.05% swapFee (~$75M TVL)
        _addPool(liquidityPoolRegistry, 0xC6962004f452bE9203591991D15f6b388e09E8D0, usdc, weth, uniswapV3, "WETH/USDC");

        // 2. WETH/USDC - 0.3% swapFee (~$10M TVL)
        _addPool(liquidityPoolRegistry, 0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c, usdc, weth, uniswapV3, "WETH/USDC");

        // 3. WETH/USDC.e - 0.05% swapFee
        _addPool(
            liquidityPoolRegistry, 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443, usdce, weth, uniswapV3, "WETH/USDC.e"
        );

        // 4. WETH/USDT - 0.05% swapFee
        _addPool(liquidityPoolRegistry, 0x641C00A822e8b671738d32a431a4Fb6074E5c79d, usdt, weth, uniswapV3, "WETH/USDT");

        // 5. WBTC/WETH - 0.05% swapFee
        _addPool(liquidityPoolRegistry, 0x2f5e87C9312fa29aed5c179E456625D79015299c, wbtc, weth, uniswapV3, "WBTC/WETH");

        // 6. ARB/WETH - 0.05% swapFee
        _addPool(liquidityPoolRegistry, 0xC6F780497A95e246EB9449f5e4770916DCd6396A, arb, weth, uniswapV3, "ARB/WETH");

        // 7. ARB/WETH - 0.3% swapFee
        _addPool(liquidityPoolRegistry, 0x92c63d0e701CAAe670C9415d91C474F686298f00, arb, weth, uniswapV3, "ARB/WETH");

        // 8. LINK/WETH - 0.3% swapFee
        _addPool(liquidityPoolRegistry, 0x468b88941e7Cc0B88c1869d68ab6b570bCEF62Ff, link, weth, uniswapV3, "LINK/WETH");

        // 9. UNI/WETH - 0.3% swapFee
        _addPool(liquidityPoolRegistry, 0xC24f7d8E51A64dc1238880BD00bb961D54cbeb29, uni, weth, uniswapV3, "UNI/WETH");

        // 10. GMX/WETH - 1% swapFee
        _addPool(liquidityPoolRegistry, 0x80A9ae39310abf666A87C743d6ebBD0E8C42158E, gmx, weth, uniswapV3, "GMX/WETH");

        // 11. PENDLE/WETH - 0.3% swapFee
        _addPool(
            liquidityPoolRegistry, 0xdbaeB7f0DFe3a0AAFD798CCECB5b22E708f7852c, pendle, weth, uniswapV3, "PENDLE/WETH"
        );

        // 12. RDNT/WETH - 0.3% swapFee
        _addPool(liquidityPoolRegistry, 0x446BF9748B4eA044dd759d9B9311C70491dF8F29, rdnt, weth, uniswapV3, "RDNT/WETH");

        // 13. MAGIC/WETH - 1% swapFee
        _addPool(
            liquidityPoolRegistry, 0x7e7FB3CCEcA5F2ac952eDF221fd2a9f62E411980, magic, weth, uniswapV3, "MAGIC/WETH"
        );

        // 14. USDC/USDT - 0.01% swapFee (stablecoin pair)
        _addPool(liquidityPoolRegistry, 0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6, usdc, usdt, uniswapV3, "USDC/USDT");

        // 15. DAI/USDC - 0.01% swapFee (stablecoin pair)
        // NOTE: native-USDC pool (token1 = 0xaf88d065...). The old seed used the DAI/USDC.e
        // pool 0xF0428617... — the token0()/token1() gate below would have caught that.
        _addPool(liquidityPoolRegistry, 0x7CF803e8d82A50504180f417B8bC7a493C0a0503, dai, usdc, uniswapV3, "DAI/USDC");

        // 16. WETH/USDT - 0.01% swapFee (tight spread)
        _addPool(liquidityPoolRegistry, 0x42161084d0672e1d3F26a9B53E653bE2084ff19C, usdt, weth, uniswapV3, "WETH/USDT");

        // 17. WBTC/USDT - 0.05% swapFee
        _addPool(liquidityPoolRegistry, 0x5969EFddE3cF5C0D9a88aE51E47d721096A97203, wbtc, usdt, uniswapV3, "WBTC/USDT");

        // 18. WBTC/USDC - 0.05% swapFee (canonical via factory.getPool(WBTC, USDC, 500))
        // NOTE: the old seed registered the USDC.e pool 0xac70bD92... as if it were native
        // USDC — quotes reverted (UniswapV3Facet_InvalidPath) and the WBTC leg was silently
        // skipped by the rebalancer. The token0()/token1() gate below prevents this class.
        _addPool(liquidityPoolRegistry, 0x0E4831319A50228B9e450861297aB92dee15B44F, wbtc, usdc, uniswapV3, "WBTC/USDC");

        // 19. WBTC/USDC - 0.3% swapFee (canonical via factory.getPool(WBTC, USDC, 3000))
        _addPool(liquidityPoolRegistry, 0x6985cb98CE393FCE8d6272127F39013f61e36166, wbtc, usdc, uniswapV3, "WBTC/USDC");

        // 20. AAVE/WETH - 0.3% swapFee
        _addPool(liquidityPoolRegistry, 0xDD672b3B768A16b9BcB4eE1060d3e8221435BeAa, aave, weth, uniswapV3, "AAVE/WETH");

        // 21. GRT/WETH - 0.3% swapFee
        _addPool(liquidityPoolRegistry, 0x74d0Ae8B8e1fCA6039707564704a25aD2ee036B0, grt, weth, uniswapV3, "GRT/WETH");

        // 22. CRV/WETH - 0.3% swapFee
        _addPool(liquidityPoolRegistry, 0xa95b0F5a65a769d82AB4F3e82842E45B8bbAf101, crv, weth, uniswapV3, "CRV/WETH");

        // 23. DAI/WETH - 0.3% swapFee
        _addPool(liquidityPoolRegistry, 0xA961F0473dA4864C5eD28e00FcC53a3AAb056c1b, dai, weth, uniswapV3, "DAI/WETH");

        // 24. LINK/USDC - 0.05% swapFee (direct leg for the BLOKC10 index)
        _addPool(liquidityPoolRegistry, 0x655C1607F8c2E73D5b4ddAbCe9Ba8792b87592B6, link, usdc, uniswapV3, "LINK/USDC");

        // 25. UNI/USDC - 0.3% swapFee (direct leg for the BLOKC10 index)
        _addPool(liquidityPoolRegistry, 0x05477c22a5349ceE601500Da0489daD137fd6BfA, uni, usdc, uniswapV3, "UNI/USDC");

        // 26. ARB/USDC - 0.3% swapFee (direct leg for the BLOKC10 index)
        _addPool(liquidityPoolRegistry, 0xaEBDcA1Bc8d89177EbE2308d62af5e74885DcCc3, arb, usdc, uniswapV3, "ARB/USDC");

        // 27. AAVE/USDC - 0.3% swapFee (direct leg for the BLOKC10 index)
        _addPool(liquidityPoolRegistry, 0x3Db70832F48F8c01ee041671f7BB1cfaA2677584, aave, usdc, uniswapV3, "AAVE/USDC");

        // 28. GMX/USDC - 1% swapFee (direct leg for the BLOKC10 index)
        _addPool(liquidityPoolRegistry, 0x0A36952Fb8C8dc6daeFB2fADb07C5212f560880e, gmx, usdc, uniswapV3, "GMX/USDC");

        // 29. PENDLE/USDC - 0.3% swapFee (direct leg for the BLOKC10 index)
        _addPool(
            liquidityPoolRegistry, 0xc6aF8e73e2261264eF95466B97B13e03Bd88165e, pendle, usdc, uniswapV3, "PENDLE/USDC"
        );

        // 30. GRT/USDC - 1% swapFee (direct leg for the BLOKC10 index)
        _addPool(liquidityPoolRegistry, 0xbEC22ca49E499C752542ca242B708c97739e4bAF, grt, usdc, uniswapV3, "GRT/USDC");

        // 31. CRV/USDC - 0.3% swapFee (direct leg for the BLOKC10 index)
        _addPool(liquidityPoolRegistry, 0x31F263f819B08036aA76Ccb235Adc8e0405c3DF0, crv, usdc, uniswapV3, "CRV/USDC");

        // 32. ZRO/USDC - 1% swapFee (direct leg for the BLOKC10 index)
        _addPool(liquidityPoolRegistry, 0xEB1f77a0ECa759c226D442F9ae5249121a555129, zro, usdc, uniswapV3, "ZRO/USDC");

        // =====================================================================
        //  CAMELOT V3 POOLS (Algebra - Dynamic swapFees)
        //  swapFee: 0 indicates dynamic swapFee managed by the protocol
        // =====================================================================
        // NOTE: the deployed CamelotV3Facet is a UniV3-style facet; Algebra pools do not
        // implement slot0()/observe()/fee() so every CamelotV3 quote reverts. The DEX is
        // registered below but LEFT INACTIVE (setDexActive(false) at the end) — a future
        // Algebra-compatible facet can flip it on without a redeploy.

        // 33. WETH/USDC - Camelot V3 (highest TVL on Camelot)
        _addPool(liquidityPoolRegistry, 0xB1026b8e7276e7AC75410F1fcbbe21796e8f7526, usdc, weth, camelotV3, "WETH/USDC");

        // 34. WETH/USDT - Camelot V3
        _addPool(liquidityPoolRegistry, 0x7CcCBA38E2D959fe135e79AEBB57CCb27B128358, usdt, weth, camelotV3, "WETH/USDT");

        // 35. ARB/WETH - Camelot V3
        _addPool(liquidityPoolRegistry, 0xe51635ae8136aBAc44906A8f230C2D235E9c195F, arb, weth, camelotV3, "ARB/WETH");

        // 36. ARB/USDC - Camelot V3
        _addPool(liquidityPoolRegistry, 0xfaE2AE0a9f87FD35b5b0E24B47BAC796A7EEfEa1, arb, usdc, camelotV3, "ARB/USDC");

        // 37. WBTC/WETH - Camelot V3
        _addPool(liquidityPoolRegistry, 0xd845f7D4f4DeB9Ff5bCf09D140Ef13718F6f6C71, wbtc, weth, camelotV3, "WBTC/WETH");

        // 38. GRAIL/WETH - Camelot V3
        _addPool(
            liquidityPoolRegistry, 0x60451B6aC55E3C5F0f3aeE31519670EcC62DC28f, grail, weth, camelotV3, "GRAIL/WETH"
        );

        // 39. PENDLE/WETH - Camelot V3
        _addPool(
            liquidityPoolRegistry, 0xE461f84C3fE6BCDd1162Eb0Ef4284F3bB6e4CAD3, pendle, weth, camelotV3, "PENDLE/WETH"
        );

        // =====================================================================
        //  CAMELOT V2 POOLS (AMM - Constant Product)
        //  swapFee: 3000 represents the default 0.3% swap Fee
        // =====================================================================

        // 40. WETH/USDC - Camelot V2 (canonical via factory.getPair(WETH, USDC))
        // NOTE: the old seed registered the USDC.e pair 0x84652bb2... here; the canonical
        // native-USDC pair is 0x54b26faf...
        _addPool(liquidityPoolRegistry, 0x54B26fAf3671677C19F70c4B879A6f7B898F732c, usdc, weth, camelotV2, "WETH/USDC");

        // 41. ARB/WETH - Camelot V2
        _addPool(liquidityPoolRegistry, 0xa6c5C7D189fA4eB5Af8ba34E63dCDD3a635D433f, arb, weth, camelotV2, "ARB/WETH");

        // 42. PENDLE/WETH - Camelot V2
        _addPool(
            liquidityPoolRegistry, 0xBfCa4230115DE8341F3A3d5e8845fFb3337B2Be3, pendle, weth, camelotV2, "PENDLE/WETH"
        );

        // =====================================================================
        //  UNISWAP V2 POOLS (Constant Product)
        //  swapFee: 3000 represents the flat 0.3% swap swapFee
        //  Factory: 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9
        // =====================================================================

        // 43. WETH/USDC - Uniswap V2 (~$80K TVL)
        _addPool(liquidityPoolRegistry, 0xF64Dfe17C8b87F012FCf50FbDA1D62bfA148366a, usdc, weth, uniswapV2, "WETH/USDC");

        // 44. WETH/DAI - Uniswap V2 (~$30K TVL)
        _addPool(liquidityPoolRegistry, 0x692a0B300366D1042679397e40f3d2cb4b8F7D30, dai, weth, uniswapV2, "WETH/DAI");

        // 45. DAI/USDC - Uniswap V2 (stablecoin pair, useful for routing)
        _addPool(liquidityPoolRegistry, 0x8edd9aEABdf2e63f76f4c4B7F36AEFa14D3cC6BC, dai, usdc, uniswapV2, "DAI/USDC");

        // =====================================================================
        //  DEX ACTIVATION
        // =====================================================================
        // CamelotV3 stays registered but inactive until an Algebra-compatible
        // quote/swap facet exists (see note above the Camelot V3 pool section).
        liquidityPoolRegistry.setDexActive(camelotV3, false);
    }

    /// @dev Adds a pool after asserting the on-chain token0()/token1() exactly match the
    ///      tokens being registered (order-independent). This is the deploy-time gate that
    ///      catches USDC.e-vs-native-USDC style misregistrations: without it, a wrong pool
    ///      address registers cleanly and the rebalancer silently skips every deficit whose
    ///      only route quotes through it.
    function _addPool(
        LiquidityPoolRegistry registry,
        address poolAddress,
        address tokenA,
        address tokenB,
        bytes32 dexId,
        string memory pairName
    )
        internal
    {
        address token0 = IMinimalPair(poolAddress).token0();
        address token1 = IMinimalPair(poolAddress).token1();
        require(
            (token0 == tokenA && token1 == tokenB) || (token0 == tokenB && token1 == tokenA),
            "pool token0/token1 mismatch with registration"
        );
        registry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: poolAddress, tokenA: tokenA, tokenB: tokenB, dexId: dexId, pairName: pairName
            })
        );
    }
}
