// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IndicesTestSetUp } from "test/indices/IndicesTestSetUp.sol";
import { MockOracle } from "test/mock/MockPriceFeed.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { MarketCapWeightedHardcoded } from "src/indices/indexCalculations/MarketCapWeightedHardcoded.sol";
import {
    MarketCapWeightedHardcoded_InvalidIndexComponentRegistryAddress
} from "src/indices/indexCalculations/MarketCapWeightedHardcoded.sol";
import { MarketCapWeightedBlokc5Hardcoded } from "src/indices/indexCalculations/MarketCapWeightedBlokc5Hardcoded.sol";
import {
    MarketCapWeightedBlokc5Hardcoded_InvalidIndexComponentRegistryAddress
} from "src/indices/indexCalculations/MarketCapWeightedBlokc5Hardcoded.sol";
import { IndexMath } from "src/indices/libraries/IndexMath.sol";

/**
 * @notice Coverage for the two hardcoded-supply MarketCapWeighted variants. They received the
 *         identical MIN_WEIGHT floor + proportional rescale change as MarketCapWeighted but had
 *         no test references — this file pins that behavior for both variants.
 */
contract MarketCapWeightedHardcodedTest is IndicesTestSetUp {
    MarketCapWeightedHardcoded internal hardcoded;
    MarketCapWeightedBlokc5Hardcoded internal blokc5;

    // Hardcoded supplies (whole token units) — must mirror the contracts
    uint256 internal constant BTC_SUPPLY = 20_012_568;
    uint256 internal constant ETH_SUPPLY = 120_691_190;
    uint256 internal constant LINK_SUPPLY = 727_099_970;
    uint256 internal constant UNI_SUPPLY = 632_591_562;
    uint256 internal constant ARB_SUPPLY = 6_040_824_145;

    function setUp() public override {
        super.setUp();
        hardcoded = new MarketCapWeightedHardcoded(address(icr));
        blokc5 = new MarketCapWeightedBlokc5Hardcoded(address(icr));
    }

    function _register(IndexComponentRegistry.Component[] memory comps) internal {
        vm.startPrank(owner);
        icr.registerComponents(comps);
        vm.stopPrank();
    }

    function _component(
        string memory symbol,
        address token,
        uint256 price
    )
        internal
        returns (IndexComponentRegistry.Component memory)
    {
        return IndexComponentRegistry.Component({
            symbol: bytes32(bytes(symbol)),
            tokenAddress: token,
            priceFeedAddress: address(new MockOracle(symbol, price)),
            heartbeat: 3600
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     Constructor -- Revert
    // ═══════════════════════════════════════════════════════════════════════

    function test_constructor_zeroAddress_hardcoded() public {
        vm.expectRevert(MarketCapWeightedHardcoded_InvalidIndexComponentRegistryAddress.selector);
        new MarketCapWeightedHardcoded(address(0));
    }

    function test_constructor_zeroAddress_blokc5() public {
        vm.expectRevert(MarketCapWeightedBlokc5Hardcoded_InvalidIndexComponentRegistryAddress.selector);
        new MarketCapWeightedBlokc5Hardcoded(address(0));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     MarketCapWeightedHardcoded
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice BTC/ETH at the fixture's oracle prices — weights must match the
    ///         hardcoded-supply market cap math exactly (no floor triggered).
    function test_hardcoded_getWeights_exactMath() public {
        bytes32[] memory syms = new bytes32[](2);
        syms[0] = bytes32("BTC");
        syms[1] = bytes32("ETH");

        uint256 btcMc = Math.mulDiv(BTC_SUPPLY, btcPrice, 1e18);
        uint256 ethMc = Math.mulDiv(ETH_SUPPLY, ethPrice, 1e18);
        uint256 totalMc = btcMc + ethMc;

        uint256[] memory weights = hardcoded.getWeights(syms);
        assertEq(weights.length, 2);
        assertEq(weights[0], IndexMath.calculateWeight(btcMc, totalMc));
        assertEq(weights[1], IndexMath.calculateWeight(ethMc, totalMc));

        uint256 sum = weights[0] + weights[1];
        assertApproxEqAbs(sum, IndexMath.PRECISION, 2);
    }

    /// @notice WETH (→ ETH supply) collapses below MIN_WEIGHT: must NOT revert —
    ///         floored, then proportionally rescaled.
    function test_hardcoded_getWeights_tinyComponent_flooredAndRescaled() public {
        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](2);
        comps[0] = _component("WBTC", makeAddr("WBTC"), 1e23); // $100k
        comps[1] = _component("WETH", makeAddr("WETH"), 1e10); // $1e-8 — collapse
        _register(comps);

        bytes32[] memory syms = new bytes32[](2);
        syms[0] = bytes32("WBTC");
        syms[1] = bytes32("WETH");

        uint256[] memory weights = hardcoded.getWeights(syms);

        // WETH floored: survives, but stays tiny (post-rescale it is shaved below MIN_WEIGHT)
        assertLt(weights[1], IndexMath.MIN_WEIGHT * 1000, "tiny component should stay tiny");
        assertGe(weights[1], IndexMath.MIN_WEIGHT / 10, "tiny component should be floored, not zero");

        // WBTC absorbs nearly all weight
        assertGt(weights[0], IndexMath.PRECISION - IndexMath.MIN_WEIGHT * 10, "dominant component should dominate");

        // Sum stays within the Index contract's accepted tolerance (1e18 ± 1e14)
        assertApproxEqAbs(weights[0] + weights[1], IndexMath.PRECISION, IndexMath.MIN_WEIGHT);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     MarketCapWeightedBlokc5Hardcoded
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice All five BLOKC5 symbols at chosen oracle prices — exact math.
    function test_blokc5_getWeights_exactMath() public {
        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](3);
        comps[0] = _component("LINK", makeAddr("LINK"), 1e21); // $1000
        comps[1] = _component("UNI", makeAddr("UNI"), 1e21); // $1000
        comps[2] = _component("ARB", makeAddr("ARB"), 1e18); // $1
        _register(comps);

        bytes32[] memory syms = new bytes32[](5);
        syms[0] = bytes32("BTC");
        syms[1] = bytes32("ETH");
        syms[2] = bytes32("LINK");
        syms[3] = bytes32("UNI");
        syms[4] = bytes32("ARB");

        uint256 btcMc = Math.mulDiv(BTC_SUPPLY, btcPrice, 1e18);
        uint256 ethMc = Math.mulDiv(ETH_SUPPLY, ethPrice, 1e18);
        uint256 linkMc = Math.mulDiv(LINK_SUPPLY, 1e21, 1e18);
        uint256 uniMc = Math.mulDiv(UNI_SUPPLY, 1e21, 1e18);
        uint256 arbMc = Math.mulDiv(ARB_SUPPLY, 1e18, 1e18);
        uint256 totalMc = btcMc + ethMc + linkMc + uniMc + arbMc;

        uint256[] memory weights = blokc5.getWeights(syms);
        assertEq(weights.length, 5);
        assertEq(weights[0], IndexMath.calculateWeight(btcMc, totalMc));
        assertEq(weights[1], IndexMath.calculateWeight(ethMc, totalMc));
        assertEq(weights[2], IndexMath.calculateWeight(linkMc, totalMc));
        assertEq(weights[3], IndexMath.calculateWeight(uniMc, totalMc));
        assertEq(weights[4], IndexMath.calculateWeight(arbMc, totalMc));

        uint256 sum;
        for (uint256 i; i < 5; i++) {
            sum += weights[i];
        }
        assertApproxEqAbs(sum, IndexMath.PRECISION, 5);
    }

    /// @notice ARB collapses below MIN_WEIGHT (largest supply, negligible price):
    ///         must NOT revert — floored, then proportionally rescaled.
    function test_blokc5_getWeights_tinyComponent_flooredAndRescaled() public {
        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](3);
        comps[0] = _component("LINK", makeAddr("LINK"), 1e21);
        comps[1] = _component("UNI", makeAddr("UNI"), 1e21);
        comps[2] = _component("ARB", makeAddr("ARB"), 1e10); // collapse
        _register(comps);

        bytes32[] memory syms = new bytes32[](5);
        syms[0] = bytes32("BTC");
        syms[1] = bytes32("ETH");
        syms[2] = bytes32("LINK");
        syms[3] = bytes32("UNI");
        syms[4] = bytes32("ARB");

        uint256[] memory weights = blokc5.getWeights(syms);

        assertLt(weights[4], IndexMath.MIN_WEIGHT * 1000, "tiny component should stay tiny");
        assertGe(weights[4], IndexMath.MIN_WEIGHT / 10, "tiny component should be floored, not zero");
        // Market-cap ordering is preserved through the floor + rescale (ratios among the
        // non-floored components are untouched) — fixture caps rank BTC > LINK > UNI > ETH —
        // and the dominant component holds more than its fair share of a 5-component index.
        assertGt(weights[0], weights[2], "BTC > LINK");
        assertGt(weights[2], weights[3], "LINK > UNI");
        assertGt(weights[3], weights[1], "UNI > ETH");
        assertGt(weights[0], IndexMath.PRECISION / 5, "dominant component should hold more than an equal share");

        uint256 sum;
        for (uint256 i; i < 5; i++) {
            sum += weights[i];
        }
        assertApproxEqAbs(sum, IndexMath.PRECISION, IndexMath.MIN_WEIGHT);
    }
}
