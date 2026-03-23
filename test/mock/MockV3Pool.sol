// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title MockV3Pool
/// @notice A minimal mock of a Uniswap V3 pool that satisfies the interface
///         calls made by UniswapV3QuoteRouter (slot0, token0, token1). Used
///         for testing the optimal-path flow on chains where real V3 pools
///         may not exist (e.g. Base Sepolia).
///
/// sqrtPriceX96 for USDC (token0, 6 dec) / WETH (token1, 18 dec) at ~3000 USDC/WETH:
///   price     = 1e18 WETH-raw / (3000 * 1e6 USDC-raw) ≈ 3.333e8  (token1 per token0)
///   sqrtPrice = sqrt(3.333e8) ≈ 18257
///   sqrtPriceX96 = 18257 * 2^96 ≈ 1.447e33
contract MockV3Pool {
    // =========================================================================
    // Storage
    // =========================================================================

    address public token0;
    address public token1;
    uint160 public sqrtPriceX96;

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _token0       Lower-address token (must be < _token1 in address order)
    /// @param _token1       Higher-address token
    /// @param _sqrtPriceX96 Initial sqrt price in Q64.96 format
    constructor(address _token0, address _token1, uint160 _sqrtPriceX96) {
        require(_token0 < _token1, "MockV3Pool: token0 must be < token1");
        token0 = _token0;
        token1 = _token1;
        sqrtPriceX96 = _sqrtPriceX96;
    }

    // =========================================================================
    // Price admin
    // =========================================================================

    function setSqrtPriceX96(uint160 _sqrtPriceX96) external {
        sqrtPriceX96 = _sqrtPriceX96;
    }

    // =========================================================================
    // IUniswapV3PoolState — slot0
    // =========================================================================

    /// @notice Returns the current pool price and tick.
    ///         Only sqrtPriceX96 is meaningful; other fields are zeroed.
    function slot0()
        external
        view
        returns (
            uint160 _sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        return (sqrtPriceX96, 0, 0, 1, 1, 0, true);
    }

    // =========================================================================
    // IUniswapV3PoolDerivedState — observe (stub; reverts for TWAP)
    // =========================================================================

    /// @notice TWAP observation. Reverts because the mock has no observation history.
    ///         The optimal-path engine always passes twapInterval=0, so this is
    ///         never called in practice during testing.
    function observe(uint32[] calldata)
        external
        pure
        returns (int56[] memory, uint160[] memory)
    {
        revert("MockV3Pool: TWAP not supported; use twapInterval=0");
    }
}
