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
 * @notice Deploys the Rebalancer to a local Anvil fork of Arbitrum One using the
 *         real protocol contracts (IndexFactory, GardenFactory, registries) and
 *         prints instructions for manual testing via cast.
 *
 *         Prerequisites:
 *           1. Start Anvil forked from Arbitrum:
 *              anvil --fork-url $ARBITRUM_RPC_URL
 *
 *           2. Run this script against the local Anvil:
 *              forge script script/deploy/DeployAndTestFork.s.sol \
 *                  --rpc-url http://localhost:8545 \
 *                  --broadcast \
 *                  -vvvv
 *
 *         What's real:
 *           - IndexFactory, GardenFactory (deploy real Index + diamond gardens)
 *           - ComponentRegistry, PoolRegistry, FacetRegistry
 *           - DexFacet, DEX routers, all liquidity pools
 *           - WETH, WBTC, USDC tokens
 *
 *         What's deployed fresh:
 *           - Rebalancer contract
 */
contract DeployAndTestFork is Script {
    // Arbitrum One mainnet addresses
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address internal constant INDEX_FACTORY = 0x91da26BF1a4adDa42355B80502785d3F026d7074;
    address internal constant COMPONENT_REGISTRY = 0x3F8291D2Fb3f5C4391DDbc36C4Ee0B1F48274977;
    address internal constant POOL_REGISTRY = 0xA3178280c191dD46c551b91c651F337E47594d85;
    address internal constant FACET_REGISTRY = 0x1e237507bb8520a253300b9e22bFccCd396E45cF;
    address internal constant GARDEN_FACTORY = 0xA6c558f50c435896aEDe997091bD06ef6cAd3603;
    address internal constant DEX_FACET = 0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B;
    address internal constant DAO = 0xC20fc692710AE3da739d1A10560be6C72A84857F;

    address internal constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant CAMELOT_V2_ROUTER = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;

    bytes32 internal constant INDEX_GARDEN_TYPE = keccak256("INDEX");
    address internal constant MARKET_CAP_WEIGHTED = 0xaE505b029C9BC7d415Ed38b420585A02363D5d03;

    function run() external {
        address deployer = msg.sender;
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        // =====================================================================
        // 1. Deploy a real Index through the real IndexFactory
        //    Must impersonate the DAO — deployIndex is onlyOwner.
        // =====================================================================
        vm.startBroadcast(deployer);
        vm.prank(DAO);
        bytes32[] memory symbols = new bytes32[](2);
        symbols[0] = bytes32("BTC");
        symbols[1] = bytes32("ETH");
        address testIndex = IIndexFactory(INDEX_FACTORY).deployIndex("BLOKC2-FORK-SCRIPT", MARKET_CAP_WEIGHTED, symbols);
        console2.log("Index deployed at:", testIndex);
        vm.stopBroadcast();

        // =====================================================================
        // 2. Deploy real Garden diamond proxies via GardenFactory
        //    Each user deploys their own garden.
        // =====================================================================
        vm.startBroadcast(deployer);
        vm.prank(user1);
        address garden1 = IGardenFactory(GARDEN_FACTORY).createGarden(1, INDEX_GARDEN_TYPE);
        vm.prank(user2);
        address garden2 = IGardenFactory(GARDEN_FACTORY).createGarden(2, INDEX_GARDEN_TYPE);
        console2.log("Garden1 deployed at:", garden1);
        console2.log("Garden2 deployed at:", garden2);

        // =====================================================================
        // 3. Install INDEX module on each garden via the two-step upgrade flow
        //    upgradeDetails() reads FacetRegistry for pending module cuts.
        //    upgrade(hash) applies the diamond cut.
        // =====================================================================
        vm.prank(user1);
        (, bytes32 hash1) = IUpgrade(garden1).upgradeDetails();
        vm.prank(user1);
        IUpgrade(garden1).upgrade(hash1);
        console2.log("INDEX module installed on garden1");

        vm.prank(user2);
        (, bytes32 hash2) = IUpgrade(garden2).upgradeDetails();
        vm.prank(user2);
        IUpgrade(garden2).upgrade(hash2);
        console2.log("INDEX module installed on garden2");

        // =====================================================================
        // 4. Connect gardens to the Index
        // =====================================================================
        vm.prank(user1);
        IIndexFacet(garden1).connectToIndex(testIndex);
        vm.prank(user2);
        IIndexFacet(garden2).connectToIndex(testIndex);
        console2.log("Gardens connected to Index");

        vm.stopBroadcast();

        // =====================================================================
        // 5. Override Index weights → 50/50 (MarketCapWeighted produces ~85/15)
        // =====================================================================
        bytes32[] memory overrideSymbols = new bytes32[](2);
        overrideSymbols[0] = bytes32("BTC");
        overrideSymbols[1] = bytes32("ETH");
        uint256[] memory overrideWeights = new uint256[](2);
        overrideWeights[0] = 0.5e18;
        overrideWeights[1] = 0.5e18;
        vm.mockCall(testIndex, abi.encodeWithSignature("getWeights()"), abi.encode(overrideSymbols, overrideWeights));
        console2.log("Index weights overridden to 50/50");

        // =====================================================================
        // 6. Override ComponentRegistry.fetchPrice → stable prices
        //    (Chainlink oracle records have stale state on forks)
        // =====================================================================
        vm.mockCall(
            COMPONENT_REGISTRY,
            abi.encodeWithSignature("fetchPrice(bytes32)", bytes32("BTC")),
            abi.encode(uint256(60_000e8))
        );
        vm.mockCall(
            COMPONENT_REGISTRY,
            abi.encodeWithSignature("fetchPrice(bytes32)", bytes32("ETH")),
            abi.encode(uint256(3000e8))
        );
        vm.mockCall(
            COMPONENT_REGISTRY,
            abi.encodeWithSignature("fetchPrice(bytes32)", bytes32("USDC")),
            abi.encode(uint256(1e8))
        );
        console2.log("fetchPrice overrides set");

        // =====================================================================
        // 7. Deploy Rebalancer — ALL constructor args are real
        // =====================================================================
        vm.startBroadcast(deployer);
        Rebalancer rebalancer =
            new Rebalancer(deployer, INDEX_FACTORY, COMPONENT_REGISTRY, POOL_REGISTRY, FACET_REGISTRY, USDC);
        console2.log("Rebalancer deployed at:", address(rebalancer));

        // =====================================================================
        // 8. Configure DEXs
        // =====================================================================
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V2"),
            CAMELOT_V2_ROUTER,
            DEX_FACET,
            bytes4(
                keccak256(
                    "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)"
                )
            ),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        rebalancer.setDexConfig(
            keccak256("UNISWAP_V3"),
            UNISWAP_V3_ROUTER,
            DEX_FACET,
            bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        console2.log("DEXs configured");

        // =====================================================================
        // 9. Register index type
        // =====================================================================
        rebalancer.addIndexToType(keccak256("BLOKC2"), testIndex);
        console2.log("BLOKC2 index registered");
        vm.stopBroadcast();

        // =====================================================================
        // Done. Print instructions for manual testing via cast.
        // =====================================================================
        console2.log("");
        console2.log("================================================================");
        console2.log("  Protocol deployed. Run these commands to test:");
        console2.log("================================================================");
        console2.log("");
        console2.log("  # Fund gardens (wrap ETH to WETH, then transfer):");
        console2.log("  cast send <weth> --value 1ether --private-key <key>");
        console2.log("  cast send <weth> \"transfer(address,uint256)\" <g1> 0.1ether");
        console2.log("");
        console2.log("  # Approve Rebalancer:");
        console2.log("  cast send <weth> \"approve(address,uint256)\" <reb> max");
        console2.log("");
        console2.log("  # Warp time via Anvil RPC:");
        console2.log("  curl -X POST ... -d '{\"method\":\"evm_increaseTime\",...}'");
        console2.log("");
        console2.log("  # Execute rebalance:");
        console2.log("  cast send <reb> \"cumulativeRebalance(bytes32,uint256)\" ...");
        console2.log("");
        console2.log("Deployed addresses:");
        console2.log("  Index:     ", testIndex);
        console2.log("  Garden1:   ", garden1);
        console2.log("  Garden2:   ", garden2);
        console2.log("  Rebalancer:", address(rebalancer));
    }
}

// =============================================================================
// Minimal interfaces for on-chain protocol contracts
// =============================================================================

interface IGardenFactory {
    function createGarden(uint256 index, bytes32 gardenType) external returns (address);
}

interface IIndexFactory {
    function deployIndex(string calldata name, address calc, bytes32[] memory syms) external returns (address);
}

interface IUpgrade {
    function upgradeDetails() external view returns (bytes memory, bytes32);
    function upgrade(bytes32 hashData) external;
}

interface IIndexFacet {
    function connectToIndex(address indexAddress) external;
}
