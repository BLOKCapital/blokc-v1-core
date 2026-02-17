// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title IndexMath
/// @author BLOK Capital DAO
/// @notice Library for safe mathematical operations used in index calculations
/// @dev Uses WETH as base currency for all calculations (more efficient than USD).
///      All values are normalized to 18 decimals (WETH native precision).
library IndexMath {
    /// @notice Thrown when division by zero is attempted
    error IndexMath_DivisionByZero();

    /// @notice Thrown when an arithmetic overflow occurs
    error IndexMath_Overflow();

    /// @notice Thrown when a price value is zero or negative
    error IndexMath_InvalidPrice();

    /// @notice Thrown when a weight exceeds 100% or is otherwise invalid
    error IndexMath_InvalidWeight();

    /// @notice Thrown when oracle price data is stale beyond the staleness threshold
    /// @param updatedAt Timestamp of the last oracle update
    /// @param currentTime Current block timestamp
    error IndexMath_StaleOraclePrice(uint256 updatedAt, uint256 currentTime);

    /// @notice Thrown when oracle round data is incomplete
    /// @param roundId Current round ID
    /// @param answeredInRound Round ID in which the answer was computed
    error IndexMath_IncompleteOracleRound(uint80 roundId, uint80 answeredInRound);

    /// @notice Precision constant (1e18 = 100%)
    uint256 internal constant PRECISION = 1e18;

    /// @notice Maximum weight value (100% in 18 decimals)
    uint256 internal constant MAX_WEIGHT = 1e18;

    /// @notice Minimum weight value (0.01% in 18 decimals)
    uint256 internal constant MIN_WEIGHT = 1e14;

    /// @notice WETH token decimals
    uint256 internal constant WETH_DECIMALS = 18;

    /// @notice Maximum allowed staleness for Chainlink oracle data (1 hour)
    uint256 internal constant CHAINLINK_STALENESS_THRESHOLD = 3600;

    /// @notice Safely calculate weight as a percentage of total with proper rounding
    /// @param part Individual market cap or value
    /// @param total Total market cap or value
    /// @return weight Weight normalized to 1e18 (100%)
    function calculateWeight(uint256 part, uint256 total) internal pure returns (uint256 weight) {
        if (total == 0) revert IndexMath_DivisionByZero();
        if (part > total) revert IndexMath_Overflow();

        // Use Floor rounding for conservative weight calculation
        weight = Math.mulDiv(part, PRECISION, total, Math.Rounding.Floor);

        // Ensure weight doesn't exceed 100%
        if (weight > MAX_WEIGHT) revert IndexMath_InvalidWeight();

        return weight;
    }

    /// @notice Convert USD value to token amount using USD price feed
    /// @param usdValue USD value to convert
    /// @param priceInUsd Price per token from USD price feed
    /// @param tokenDecimals Token decimals
    /// @param priceDecimals Price feed decimals
    /// @return tokenAmount Token amount in native decimals
    function usdToToken(
        uint256 usdValue,
        uint256 priceInUsd,
        uint8 tokenDecimals,
        uint8 priceDecimals
    )
        internal
        pure
        returns (uint256 tokenAmount)
    {
        if (priceInUsd == 0) revert IndexMath_InvalidPrice();
        if (usdValue == 0) return 0;

        // Calculate: (usdValue * 10^tokenDecimals * 10^priceDecimals) / (price * 1e18)
        uint256 numerator = usdValue * (10 ** uint256(tokenDecimals)) * (10 ** uint256(priceDecimals));

        tokenAmount = Math.mulDiv(numerator, 1, priceInUsd * PRECISION, Math.Rounding.Floor);

        return tokenAmount;
    }

    /// @notice Convert token amount to USD value using USD price feed
    /// @dev Only used for display/reporting purposes, not for rebalancing calculations
    /// @param tokenAmount Amount of tokens
    /// @param priceInUsd Price per token from USD price feed
    /// @param tokenDecimals Token decimals
    /// @param priceDecimals Price feed decimals
    /// @return usdValue USD value normalized to 1e18
    function tokenToUsd(
        uint256 tokenAmount,
        uint256 priceInUsd,
        uint8 tokenDecimals,
        uint8 priceDecimals
    )
        internal
        pure
        returns (uint256 usdValue)
    {
        if (priceInUsd == 0) revert IndexMath_InvalidPrice();
        if (tokenAmount == 0) return 0;

        // Calculate: (tokenAmount * price * 1e18) / (10^tokenDecimals * 10^priceDecimals)
        uint256 scaledAmount = Math.mulDiv(tokenAmount, priceInUsd, 1, Math.Rounding.Floor);
        uint256 denominator = (10 ** uint256(tokenDecimals)) * (10 ** uint256(priceDecimals));

        usdValue = Math.mulDiv(scaledAmount, PRECISION, denominator, Math.Rounding.Floor);

        return usdValue;
    }

    /// @notice Convert token amount to WETH value with safe decimal handling
    /// @dev More efficient than USD conversion - uses direct WETH prices
    /// @param tokenAmount Amount of tokens in native decimals
    /// @param priceInWeth Price per token denominated in WETH (18 decimals)
    /// @param tokenDecimals Token decimals
    /// @return wethValue Value in WETH (18 decimals)
    function tokenToWeth(
        uint256 tokenAmount,
        uint256 priceInWeth,
        uint8 tokenDecimals
    )
        internal
        pure
        returns (uint256 wethValue)
    {
        if (priceInWeth == 0) revert IndexMath_InvalidPrice();
        if (tokenAmount == 0) return 0;

        // Calculate: (tokenAmount * priceInWeth) / 10^tokenDecimals
        // Result is in 18 decimals (WETH precision)
        wethValue = Math.mulDiv(tokenAmount, priceInWeth, 10 ** uint256(tokenDecimals), Math.Rounding.Floor);

        return wethValue;
    }

    /// @notice Convert WETH value to token amount with safe decimal handling
    /// @dev More efficient than USD conversion - uses direct WETH prices
    /// @param wethValue Value in WETH (18 decimals)
    /// @param priceInWeth Price per token denominated in WETH (18 decimals)
    /// @param tokenDecimals Token decimals
    /// @return tokenAmount Amount of tokens in native decimals
    function wethToToken(
        uint256 wethValue,
        uint256 priceInWeth,
        uint8 tokenDecimals
    )
        internal
        pure
        returns (uint256 tokenAmount)
    {
        if (priceInWeth == 0) revert IndexMath_InvalidPrice();
        if (wethValue == 0) return 0;

        // Calculate: (wethValue * 10^tokenDecimals) / priceInWeth
        // Input wethValue is 18 decimals, priceInWeth is 18 decimals
        // Result is in token's native decimals
        tokenAmount = Math.mulDiv(wethValue, 10 ** uint256(tokenDecimals), priceInWeth, Math.Rounding.Floor);

        return tokenAmount;
    }

    /// @notice Calculate expected value based on weight
    /// @param totalValue Total portfolio value
    /// @param weight Asset weight (1e18 = 100%)
    /// @return expectedValue Expected value for the asset
    function calculateExpectedValue(uint256 totalValue, uint256 weight) internal pure returns (uint256 expectedValue) {
        if (weight > MAX_WEIGHT) revert IndexMath_InvalidWeight();

        // Use Floor rounding for conservative calculations
        expectedValue = Math.mulDiv(totalValue, weight, PRECISION, Math.Rounding.Floor);

        return expectedValue;
    }

    /// @notice Calculate market cap in WETH from WETH price and circulating supply
    /// @dev Used for weight calculations - more efficient than USD market cap
    /// @param priceInWeth Price per token in WETH (18 decimals)
    /// @param circulatingSupply Circulating supply in token decimals
    /// @param tokenDecimals Token decimals
    /// @return marketCapInWeth Market cap in WETH (18 decimals)
    function calculateMarketCapInWeth(
        uint256 priceInWeth,
        uint256 circulatingSupply,
        uint8 tokenDecimals
    )
        internal
        pure
        returns (uint256 marketCapInWeth)
    {
        if (priceInWeth == 0) revert IndexMath_InvalidPrice();
        if (circulatingSupply == 0) return 0;

        // Market cap = (priceInWeth * supply) / 10^tokenDecimals
        // Result is in 18 decimals (WETH precision)
        marketCapInWeth = Math.mulDiv(priceInWeth, circulatingSupply, 10 ** uint256(tokenDecimals), Math.Rounding.Floor);

        return marketCapInWeth;
    }

    /// @notice Calculate market cap in USD (for display purposes only)
    /// @param priceInUsd Price per token from USD price feed
    /// @param circulatingSupply Circulating supply with token decimals
    /// @param priceDecimals Price feed decimals
    /// @return marketCapInUsd Market cap in USD normalized to 1e18
    function calculateMarketCapInUsd(
        uint256 priceInUsd,
        uint256 circulatingSupply,
        uint8 priceDecimals
    )
        internal
        pure
        returns (uint256 marketCapInUsd)
    {
        if (priceInUsd == 0) revert IndexMath_InvalidPrice();
        if (circulatingSupply == 0) return 0;

        // Market cap = (price * supply) / 10^priceDecimals
        // Then normalize to 1e18
        marketCapInUsd = Math.mulDiv(priceInUsd, circulatingSupply, 10 ** uint256(priceDecimals), Math.Rounding.Floor);

        return marketCapInUsd;
    }

    /// @notice Check if rebalancing is needed based on threshold
    /// @param currentValue Current value
    /// @param targetValue Target value
    /// @param thresholdBps Threshold in basis points (1 bp = 0.01%)
    /// @return needsRebalance True if rebalancing is needed
    function needsRebalance(
        uint256 currentValue,
        uint256 targetValue,
        uint256 thresholdBps
    )
        internal
        pure
        returns (bool)
    {
        if (targetValue == 0) return currentValue > 0;

        uint256 diff;
        if (currentValue > targetValue) {
            diff = currentValue - targetValue;
        } else {
            diff = targetValue - currentValue;
        }

        // Calculate threshold: targetValue * thresholdBps / 10000
        uint256 threshold = Math.mulDiv(targetValue, thresholdBps, 10_000, Math.Rounding.Ceil);

        return diff > threshold;
    }

    /// @notice Apply slippage tolerance downward (for minimum acceptable outputs)
    /// @param amount Expected amount
    /// @param slippageBps Slippage tolerance in basis points
    /// @return minAmount Minimum acceptable amount after slippage
    function applySlippageDown(uint256 amount, uint256 slippageBps) internal pure returns (uint256 minAmount) {
        if (slippageBps >= 10_000) revert IndexMath_InvalidWeight(); // Can't have 100% or more slippage
        minAmount = (amount * (10_000 - slippageBps)) / 10_000;
    }

    /// @notice Apply slippage tolerance upward (for maximum acceptable inputs)
    /// @param amount Expected amount
    /// @param slippageBps Slippage tolerance in basis points
    /// @return maxAmount Maximum acceptable amount after slippage
    function applySlippageUp(uint256 amount, uint256 slippageBps) internal pure returns (uint256 maxAmount) {
        if (slippageBps >= 10_000) revert IndexMath_InvalidWeight(); // Sanity check
        maxAmount = (amount * (10_000 + slippageBps)) / 10_000;
    }

    /// @notice Calculate minimum output with price conversion and slippage protection
    /// @dev Useful for exact input swaps where you know input amount and want minimum output
    /// @param amountIn Input amount in input token decimals
    /// @param decimalsIn Input token decimals
    /// @param decimalsOut Output token decimals
    /// @param priceRatio Price ratio (output per input token), scaled to 1e18
    /// @param slippageBps Slippage tolerance in basis points
    /// @return minOut Minimum acceptable output amount
    function calculateMinOutputWithSlippage(
        uint256 amountIn,
        uint8 decimalsIn,
        uint8 decimalsOut,
        uint256 priceRatio,
        uint256 slippageBps
    )
        internal
        pure
        returns (uint256 minOut)
    {
        if (priceRatio == 0) revert IndexMath_InvalidPrice();
        if (amountIn == 0) return 0;

        // Calculate expected output: (amountIn * priceRatio * 10^decimalsOut) / 10^decimalsIn
        uint256 expectedOut = Math.mulDiv(
            amountIn, priceRatio * (10 ** uint256(decimalsOut)), 10 ** uint256(decimalsIn), Math.Rounding.Floor
        );

        // Apply slippage tolerance
        minOut = applySlippageDown(expectedOut, slippageBps);
    }

    /// @notice Calculate total portfolio value in WETH from asset balances and prices
    /// @param pricesInWeth Array of prices in WETH (18 decimals)
    /// @param decimals Array of asset decimals
    /// @return totalValueInWeth Total portfolio value in WETH (18 decimals)
    function calculateTotalPortfolioValueInWeth(
        uint256[] memory balances,
        uint256[] memory pricesInWeth,
        uint8[] memory decimals
    )
        internal
        pure
        returns (uint256 totalValueInWeth)
    {
        for (uint256 i = 0; i < balances.length; i++) {
            totalValueInWeth += tokenToWeth(balances[i], pricesInWeth[i], decimals[i]);
        }
    }

    /// @notice Calculate single asset balance value in WETH
    /// @param balance Asset balance in native decimals
    /// @param priceInWeth Price in WETH (18 decimals)
    /// @param tokenDecimals Asset decimals
    /// @return valueInWeth Asset value in WETH (18 decimals)
    function calculateAssetBalanceInWeth(
        uint256 balance,
        uint256 priceInWeth,
        uint8 tokenDecimals
    )
        internal
        pure
        returns (uint256 valueInWeth)
    {
        return tokenToWeth(balance, priceInWeth, tokenDecimals);
    }

    /// @notice Validate Chainlink oracle data for freshness and completeness
    /// @param roundId Round ID from latestRoundData
    /// @param price Price value from oracle
    /// @param updatedAt Timestamp when data was last updated
    /// @param answeredInRound Round ID in which the answer was computed
    function validateOracleData(uint80 roundId, int256 price, uint256 updatedAt, uint80 answeredInRound) internal view {
        // Check price is positive
        if (price <= 0) revert IndexMath_InvalidPrice();

        // Check data is fresh (updated within threshold)
        if (block.timestamp - updatedAt > CHAINLINK_STALENESS_THRESHOLD) {
            revert IndexMath_StaleOraclePrice(updatedAt, block.timestamp);
        }

        // Check round is complete
        if (answeredInRound < roundId) {
            revert IndexMath_IncompleteOracleRound(roundId, answeredInRound);
        }
    }
}
