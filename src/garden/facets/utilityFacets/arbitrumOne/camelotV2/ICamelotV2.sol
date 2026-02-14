//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title ICamelotV2
    @author BLOK Capital DAO
    @notice Interface for Camelot V2 integration (swaps)
    @dev This interface provides the functionality for Camelot V2 integration (swaps)

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

interface ICamelotV2 {
    /// @notice Camelot V2 exact input single swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of addresses describing the path
    /// @param referrer Address of the referrer
    /// @param deadline Unix timestamp after which the swap is invalid
    function camelotV2ExactInputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        external;

    /// @notice Camelot V2 exact input swap
    /// @param amountInMax Maximum acceptable input amount (slippage protection)
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of addresses describing the path
    /// @param referrer Address of the referrer
    /// @param deadline Unix timestamp after which the swap is invalid
    function camelotV2ExactInput(
        uint256 amountInMax,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        external;

    /// @notice Camelot V2 exact output single swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of addresses describing the path
    /// @param referrer Address of the referrer
    /// @param deadline Unix timestamp after which the swap is invalid
    function camelotV2ExactOutputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        external;
}
