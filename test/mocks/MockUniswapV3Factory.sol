// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

/// @title Mock Uniswap V3 Factory for testing
contract MockUniswapV3Factory is IUniswapV3Factory {
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    function setPool(address tokenA, address tokenB, uint24 fee, address pool) external {
        getPool[tokenA][tokenB][fee] = pool;
        getPool[tokenB][tokenA][fee] = pool; // Uniswap pools are bidirectional
    }

    function owner() external pure override returns (address) {
        return address(0);
    }

    function feeAmountTickSpacing(uint24) external pure override returns (int24) {
        return 0;
    }

    function createPool(address, address, uint24) external pure override returns (address) {
        return address(0);
    }

    function setOwner(address) external pure override { }

    function enableFeeAmount(uint24, int24) external pure override { }
}
