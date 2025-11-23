// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Mock Uniswap V3 Router for testing
contract MockUniswapV3Router {
    uint256 public lastAmountOut;
    bool public shouldRevert;

    function setAmountOut(uint256 amount) external {
        lastAmountOut = amount;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut)
    {
        if (shouldRevert) revert("Mock router revert");

        // Transfer tokens as if swap happened
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        IERC20(params.tokenOut).transfer(params.recipient, lastAmountOut > 0 ? lastAmountOut : params.amountIn / 2);

        return lastAmountOut > 0 ? lastAmountOut : params.amountIn / 2;
    }

    function exactInput(ISwapRouter.ExactInputParams calldata params) external payable returns (uint256 amountOut) {
        if (shouldRevert) revert("Mock router revert");

        // Decode path to get tokens
        address tokenIn = _decodeToken(params.path, 0);
        address tokenOut = _decodeToken(params.path, _getPathLength(params.path) - 1);

        IERC20(tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        IERC20(tokenOut).transfer(params.recipient, lastAmountOut > 0 ? lastAmountOut : params.amountIn / 2);

        return lastAmountOut > 0 ? lastAmountOut : params.amountIn / 2;
    }

    function exactOutputSingle(ISwapRouter.ExactOutputSingleParams calldata)
        external
        payable
        returns (uint256 amountIn)
    {
        revert("Not implemented");
    }

    function exactOutput(ISwapRouter.ExactOutputParams calldata) external payable returns (uint256 amountIn) {
        revert("Not implemented");
    }

    function unwrapWETH9(uint256, address) external pure {
        revert("Not implemented");
    }

    function refundETH() external payable {
        revert("Not implemented");
    }

    function sweepToken(address, uint256, address) external pure {
        revert("Not implemented");
    }

    function _decodeToken(bytes memory path, uint256 index) internal pure returns (address) {
        // Simple decoding: assume path is encoded as address (20 bytes) + fee (3 bytes) + address...
        require(path.length >= 20, "Invalid path");
        address token;
        assembly {
            token := mload(add(add(path, 0x20), mul(index, 23)))
        }
        return token;
    }

    function _getPathLength(bytes memory path) internal pure returns (uint256) {
        // Each hop is 23 bytes (20 for address + 3 for fee)
        return (path.length + 22) / 23;
    }
}
