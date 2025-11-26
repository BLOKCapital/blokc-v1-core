// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Mock Uniswap V3 Pool for testing
contract MockUniswapV3Pool {
    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 observationIndex;
        uint16 observationCardinality;
        uint16 observationCardinalityNext;
        uint8 feeProtocol;
        bool unlocked;
    }

    Slot0 public slot0;
    uint128 public liquidity;

    // Mock observation data
    int56[] public tickCumulatives;
    uint160[] public secondsPerLiquidityCumulativeX128s;

    constructor(uint160 _sqrtPriceX96, int24 _tick) {
        slot0 = Slot0({
            sqrtPriceX96: _sqrtPriceX96,
            tick: _tick,
            observationIndex: 0,
            observationCardinality: 1,
            observationCardinalityNext: 1,
            feeProtocol: 0,
            unlocked: true
        });
    }

    function setSlot0(uint160 _sqrtPriceX96, int24 _tick) external {
        slot0.sqrtPriceX96 = _sqrtPriceX96;
        slot0.tick = _tick;
    }

    function setObservationData(
        int56[] memory _tickCumulatives,
        uint160[] memory _secondsPerLiquidityCumulativeX128s
    )
        external
    {
        tickCumulatives = _tickCumulatives;
        secondsPerLiquidityCumulativeX128s = _secondsPerLiquidityCumulativeX128s;
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulative, uint160[] memory secondsPerLiquidityCumulativeX128)
    {
        return (tickCumulatives, secondsPerLiquidityCumulativeX128s);
    }

    // Stub implementations for IUniswapV3Pool interface
    function token0() external pure returns (address) {
        return address(0);
    }

    function token1() external pure returns (address) {
        return address(0);
    }

    function fee() external pure returns (uint24) {
        return 0;
    }

    function tickSpacing() external pure returns (int24) {
        return 0;
    }

    function maxLiquidityPerTick() external pure returns (uint128) {
        return 0;
    }

    function protocolFees() external pure returns (uint128 fee0, uint128 fee1) {
        return (0, 0);
    }

    function observations(uint256) external pure returns (uint32, int56, uint160, bool) {
        return (0, 0, 0, false);
    }

    function increaseObservationCardinalityNext(uint16) external pure { }

    function initialize(uint160) external pure { }

    function mint(address, int24, int24, uint128, bytes calldata) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function collect(address, int24, int24, uint128, uint128) external pure returns (uint128, uint128) {
        return (0, 0);
    }

    function burn(int24, int24, uint128) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function swap(address, bool, int256, uint160, bytes calldata) external pure returns (int256, int256) {
        return (0, 0);
    }

    function flash(address, uint256, uint256, bytes calldata) external pure { }

    function collectProtocol(address, uint128, uint128) external pure returns (uint128, uint128) {
        return (0, 0);
    }

    function setFeeProtocol(uint8, uint8) external pure { }

    function snapshotCumulativesInside(int24, int24) external pure returns (int56, uint160, uint32) {
        return (0, 0, 0);
    }
}
