// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import "forge-std/Script.sol";
import { Rebalancer } from "src/rebalancer/Rebalancer.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title DeployAndTestFork
 * @notice Deploys the Rebalancer to a local Anvil fork of Arbitrum One and runs an
 *         end-to-end test through real DEX pools.
 *
 *         Prerequisites:
 *           1. Start Anvil forked from Arbitrum:
 *              anvil --fork-url $ARBITRUM_RPC_URL --fork-block-number 286500000
 *
 *           2. Run this script against the local Anvil:
 *              forge script script/deploy/DeployAndTestFork.s.sol \
 *                  --rpc-url http://localhost:8545 \
 *                  --broadcast \
 *                  -vvvv
 *
 *         What's real:
 *           - PoolRegistry, FacetRegistry, DexFacet (live Arbitrum contracts)
 *           - DEX routers (Uniswap V3, Camelot V2/V3)
 *           - All liquidity pools
 *           - WETH, WBTC, USDC tokens
 *
 *         What's deployed fresh:
 *           - Rebalancer contract
 *           - Mock index + index factory
 *           - Mock component registry (avoids Chainlink fork oracle issues)
 */
contract DeployAndTestFork is Script {
    // Arbitrum One mainnet addresses
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address internal constant POOL_REGISTRY = 0xA3178280c191dD46c551b91c651F337E47594d85;
    address internal constant FACET_REGISTRY = 0xcD06FE7cdCacAed1806E2c29E411d4bD05A51Ef3;
    address internal constant DEX_FACET = 0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B;

    address internal constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant CAMELOT_V2_ROUTER = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;
    address internal constant CAMELOT_V3_ROUTER = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;

    function run() external {
        // -- Fork must already be active (Anvil running in another terminal) --
        //    If fork isn't running, this will just use whatever RPC is configured.

        address deployer = msg.sender;

        // =====================================================================
        // 1. Deploy mock registry + index
        // =====================================================================
        vm.startBroadcast(deployer);

        MockIndexFactory mockFactory = new MockIndexFactory();
        MockIndex mockIndex = new MockIndex();

        bytes32[] memory symbols = new bytes32[](2);
        symbols[0] = bytes32("ETH");
        symbols[1] = bytes32("BTC");
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;
        mockIndex.setWeights(symbols, weights);

        address garden1 = 0x0000000000000000000000000000000000000001;
        address garden2 = 0x0000000000000000000000000000000000000002;
        address[] memory gardens = new address[](2);
        gardens[0] = garden1;
        gardens[1] = garden2;
        mockIndex.setGardens(gardens);

        mockFactory.setRegistered(address(mockIndex), true);

        console2.log("MockIndex deployed at:", address(mockIndex));

        // =====================================================================
        // 2. Deploy mock component registry
        // =====================================================================
        MockComponentRegistry mockComp = new MockComponentRegistry();
        mockComp.setComponent(bytes32("ETH"), WETH);
        mockComp.setPrice(WETH, 3000e8);
        mockComp.setComponent(bytes32("BTC"), WBTC);
        mockComp.setPrice(WBTC, 60000e8);
        mockComp.setComponent(bytes32("USDC"), USDC);
        mockComp.setPrice(USDC, 1e8);
        mockComp.setRegistered(bytes32("USDC"), true);

        // =====================================================================
        // 3. Deploy Rebalancer
        // =====================================================================
        Rebalancer rebalancer = new Rebalancer(
            deployer,
            address(mockFactory),
            address(mockComp),
            POOL_REGISTRY,
            FACET_REGISTRY,
            USDC
        );
        console2.log("Rebalancer deployed at:", address(rebalancer));

        // =====================================================================
        // 4. Configure DEXs
        // =====================================================================
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V2"), CAMELOT_V2_ROUTER, DEX_FACET,
            bytes4(keccak256("swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)")),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        rebalancer.setDexConfig(
            keccak256("UNISWAP_V3"), UNISWAP_V3_ROUTER, DEX_FACET,
            bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V3"), CAMELOT_V3_ROUTER, DEX_FACET,
            bytes4(keccak256("exactInputSingle((address,address,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        console2.log("All DEXs configured");

        // =====================================================================
        // 5. Register index type
        // =====================================================================
        rebalancer.addIndexToType(keccak256("BLOKC2"), address(mockIndex));
        console2.log("BLOKC2 index registered");

        // =====================================================================
        // 6. Fund gardens from Arbitrum whale accounts (impersonation)
        // =====================================================================
        // WETH whale on Arbitrum: Binance hot wallet
        address wethWhale = 0xB38e8c17e38363aF6EbdCb3dAE12e0243582891D;
        // WBTC whale on Arbitrum
        address wbtcWhale = 0x489ee077994B6658eAfA855C308275EAd8097C4A;

        vm.prank(wethWhale);
        IERC20(WETH).transfer(garden1, 0.1e18);
        vm.prank(wethWhale);
        IERC20(WETH).transfer(garden2, 0.1e18);

        vm.prank(wbtcWhale);
        IERC20(WBTC).transfer(garden1, 0.01e8);
        vm.prank(wbtcWhale);
        IERC20(WBTC).transfer(garden2, 0.01e8);

        // =====================================================================
        // 7. Gardens approve the Rebalancer
        // =====================================================================
        vm.prank(garden1);
        IERC20(WETH).approve(address(rebalancer), type(uint256).max);
        vm.prank(garden1);
        IERC20(WBTC).approve(address(rebalancer), type(uint256).max);
        vm.prank(garden1);
        IERC20(USDC).approve(address(rebalancer), type(uint256).max);

        vm.prank(garden2);
        IERC20(WETH).approve(address(rebalancer), type(uint256).max);
        vm.prank(garden2);
        IERC20(WBTC).approve(address(rebalancer), type(uint256).max);
        vm.prank(garden2);
        IERC20(USDC).approve(address(rebalancer), type(uint256).max);

        vm.stopBroadcast();

        // =====================================================================
        // 8. Warp past 24h cooldown
        // =====================================================================
        vm.warp(block.timestamp + 24 hours + 1);

        // =====================================================================
        // 9. Execute cumulative rebalance (permissionless — anyone can call)
        // =====================================================================
        console2.log("");
        console2.log("=== BEFORE REBALANCE ===");
        console2.log("garden1 WETH:", IERC20(WETH).balanceOf(garden1));
        console2.log("garden1 WBTC:", IERC20(WBTC).balanceOf(garden1));
        console2.log("garden2 WETH:", IERC20(WETH).balanceOf(garden2));
        console2.log("garden2 WBTC:", IERC20(WBTC).balanceOf(garden2));

        vm.startBroadcast(deployer);
        rebalancer.cumulativeRebalance(keccak256("BLOKC2"), block.timestamp + 300);
        vm.stopBroadcast();

        console2.log("");
        console2.log("=== AFTER REBALANCE ===");
        console2.log("garden1 WETH:", IERC20(WETH).balanceOf(garden1));
        console2.log("garden1 WBTC:", IERC20(WBTC).balanceOf(garden1));
        console2.log("garden2 WETH:", IERC20(WETH).balanceOf(garden2));
        console2.log("garden2 WBTC:", IERC20(WBTC).balanceOf(garden2));
        console2.log("rebalancer WETH dust:", IERC20(WETH).balanceOf(address(rebalancer)));
        console2.log("rebalancer WBTC dust:", IERC20(WBTC).balanceOf(address(rebalancer)));

        uint256 totalWethAfter = IERC20(WETH).balanceOf(garden1) + IERC20(WETH).balanceOf(garden2);
        uint256 totalWbtcAfter = IERC20(WBTC).balanceOf(garden1) + IERC20(WBTC).balanceOf(garden2);
        console2.log("");
        console2.log("Total WETH after:", totalWethAfter);
        console2.log("Total WBTC after:", totalWbtcAfter);
        console2.log("WETH should be > 0.2 (if swap executed):", totalWethAfter > 0.2e18);
    }
}

// =============================================================================
// Minimal mocks (only Index — everything else is real)
// =============================================================================

contract MockIndexFactory {
    mapping(address => bool) public registered;
    function setRegistered(address idx, bool val) external { registered[idx] = val; }
    function isIndexRegistered(address idx) external view returns (bool) { return registered[idx]; }
}

contract MockIndex {
    bytes32[] private _symbols;
    uint256[] private _weights;
    address[] private _gardens;

    function setWeights(bytes32[] memory s, uint256[] memory w) external { _symbols = s; _weights = w; }
    function setGardens(address[] memory g) external { _gardens = g; }
    function getWeights() external view returns (bytes32[] memory, uint256[] memory) {
        return (_symbols, _weights);
    }
    function getConnectedGardens() external view returns (address[] memory) { return _gardens; }
}

contract MockComponentRegistry {
    mapping(bytes32 => address) public components;
    mapping(address => uint256) public prices;
    mapping(bytes32 => bool) public registered;

    function setComponent(bytes32 s, address t) external { components[s] = t; registered[s] = true; }
    function setPrice(address t, uint256 p) external { prices[t] = p; }
    function setRegistered(bytes32 s, bool v) external { registered[s] = v; }
    function getComponentAddress(bytes32 s) external view returns (address) { return components[s]; }
    function fetchPrice(bytes32 s) external view returns (uint256) { return prices[components[s]]; }
    function isComponentRegistered(bytes32 s) external view returns (bool) { return registered[s]; }
}
