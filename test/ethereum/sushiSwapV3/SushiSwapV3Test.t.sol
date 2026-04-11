// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { SushiSwapV3Facet } from "src/garden/facets/utilityFacets/ethereum/sushiSwapV3/SushiSwapV3Facet.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

contract SushiSwapV3Test is Test {
    SushiSwapV3Facet sushiSwapV3Facet;

    address constant WETH          = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC          = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WBTC          = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant SUSHI_FACTORY = 0xbACEB8eC6b9355Dfc0269C18bac9d6E2Bdc29C4F;
    address constant POOL_REGISTRY = 0xDe6338E4dd7B0A2076e8CE63cC0443dC6cE7f0B6;

    // Derived from factory in setUp — canonical for this pair+fee on the forked block
    address WETH_USDC_POOL;
    address WBTC_WETH_POOL;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        sushiSwapV3Facet = new SushiSwapV3Facet();

        // Seed OwnershipStorage.layout().owner = address(this)
        bytes32 ownerSlot = keccak256(bytes("OwnershipStorage")) & ~bytes32(uint256(0xff));
        vm.store(
            address(sushiSwapV3Facet),
            ownerSlot,
            bytes32(uint256(uint160(address(this))))
        );

        // Mock PoolRegistry to accept any pool
        vm.mockCall(
            POOL_REGISTRY,
            abi.encodeWithSignature("isPoolRegistered(address)"),
            abi.encode(true)
        );

        // Derive canonical pool addresses from the SushiSwap V3 factory.
        // _validatePool reads fee() from the pool and cross-checks with getPool(),
        // so the address must come from the factory itself.
        WETH_USDC_POOL = IUniswapV3Factory(SUSHI_FACTORY).getPool(WETH, USDC, 500);
        if (WETH_USDC_POOL == address(0)) {
            WETH_USDC_POOL = IUniswapV3Factory(SUSHI_FACTORY).getPool(WETH, USDC, 3000);
        }

        WBTC_WETH_POOL = IUniswapV3Factory(SUSHI_FACTORY).getPool(WBTC, WETH, 500);
        if (WBTC_WETH_POOL == address(0)) {
            WBTC_WETH_POOL = IUniswapV3Factory(SUSHI_FACTORY).getPool(WBTC, WETH, 3000);
        }
    }

    function testSushiSwapV3ExactInputSingle() public {
        vm.skip(WETH_USDC_POOL == address(0));

        uint256 amountIn = 1 ether;
        deal(WETH, address(sushiSwapV3Facet), amountIn);

        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;

        address[] memory pools = new address[](1);
        pools[0] = WETH_USDC_POOL;

        SwapInstruction memory inst = SwapInstruction({
            amountIn: amountIn,
            amountOut: 0,
            tokens: tokens,
            pools: pools,
            exactOutput: false
        });

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(sushiSwapV3Facet));
        sushiSwapV3Facet.sushiSwapV3Swap(inst);
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(sushiSwapV3Facet));

        assertGt(usdcAfter, usdcBefore, "should have received USDC");
    }

    function testSushiSwapV3ExactInput_MultiHop() public {
        vm.skip(WBTC_WETH_POOL == address(0) || WETH_USDC_POOL == address(0));

        uint256 amountIn = 1e7; // 0.1 WBTC (8 decimals)
        deal(WBTC, address(sushiSwapV3Facet), amountIn);

        // Path: WBTC -> WETH -> USDC
        address[] memory tokens = new address[](3);
        tokens[0] = WBTC;
        tokens[1] = WETH;
        tokens[2] = USDC;

        address[] memory pools = new address[](2);
        pools[0] = WBTC_WETH_POOL;
        pools[1] = WETH_USDC_POOL;

        SwapInstruction memory inst = SwapInstruction({
            amountIn: amountIn,
            amountOut: 0,
            tokens: tokens,
            pools: pools,
            exactOutput: false
        });

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(sushiSwapV3Facet));
        sushiSwapV3Facet.sushiSwapV3Swap(inst);
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(sushiSwapV3Facet));

        assertGt(usdcAfter, usdcBefore, "should have received USDC");
    }

    function testSushiSwapV3ExactOutputSingle() public {
        vm.skip(WETH_USDC_POOL == address(0));

        uint256 amountOut       = 50e6; // 50 USDC
        uint256 amountInMaximum = 1 ether;
        deal(WETH, address(sushiSwapV3Facet), amountInMaximum);

        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;

        address[] memory pools = new address[](1);
        pools[0] = WETH_USDC_POOL;

        SwapInstruction memory inst = SwapInstruction({
            amountIn: amountInMaximum,
            amountOut: amountOut,
            tokens: tokens,
            pools: pools,
            exactOutput: true
        });

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(sushiSwapV3Facet));
        sushiSwapV3Facet.sushiSwapV3Swap(inst);
        uint256 usdcAfter = IERC20(USDC).balanceOf(address(sushiSwapV3Facet));

        assertEq(usdcAfter - usdcBefore, amountOut, "should have received exact USDC");
    }

    function testSushiSwapV3Quote() public {
        vm.skip(WETH_USDC_POOL == address(0));

        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;

        address[] memory pools = new address[](1);
        pools[0] = WETH_USDC_POOL;

        QuoteInstruction memory inst = QuoteInstruction({
            amount: 1 ether,
            tokens: tokens,
            pools: pools,
            exactOutput: false
        });

        uint256 estimated = sushiSwapV3Facet.sushiSwapV3Quote(inst);
        assertGt(estimated, 0, "quote should return non-zero");
    }
}
