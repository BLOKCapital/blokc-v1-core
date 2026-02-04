//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

import { IndexFactory } from "src/indices/IndexFactory.sol";
import { Index } from "src/indices/Index.sol";
import { UniswapV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { IndexStorage } from "src/garden/facets/indexFacets/IndexStorage.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IUniswapV3 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IndexMath } from "src/indices/libraries/IndexMath.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when asset address is invalid or zero
/// @param assetAddress The invalid asset address
error IndexFacet_InvalidAssetAddress(address assetAddress);

/// @notice Thrown when a mathematical addition causes overflow
/// @param value1 The first value that caused the overflow
/// @param value2 The second value that caused the overflow
error IndexFacet_MathOverflowedAdd(uint256 value1, uint256 value2);

/// @notice Thrown when attempting to rebalance without a connected index
error IndexFacet_NoIndexConnected();

/// @notice Thrown when asset information is invalid or incomplete
error IndexFacet_InvalidAssetInfo();

/// @notice Thrown when attempting to connect to an unregistered index
/// @param indexAddress The unregistered index address
error IndexFacet_IndexNotRegistered(address indexAddress);

/// @notice Thrown when insufficient balance for operation
error IndexFacet_InsufficientBalance();

abstract contract IndexBase is UniswapV3Base {
    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when garden successfully connects to an index
    /// @param indexAddress Address of the connected index
    event IndexConnected(address indexed indexAddress);

    /// @notice Emitted when garden disconnects from its index
    /// @param indexAddress Address of the disconnected index
    event IndexDisconnected(address indexed indexAddress);

    /// @notice Emitted when rebalance operation begins
    /// @param timestamp Block timestamp when rebalance started
    /// @param garden Address of the garden initiating the rebalance
    /// @param indexAddress Address of the index being tracked
    event RebalanceStarted(uint256 timestamp, address garden, address indexed indexAddress);

    /// @notice Emitted when rebalance operation completes
    /// @param timestamp Block timestamp when rebalance completed
    /// @param totalValue Total portfolio value in USD
    event RebalanceCompleted(uint256 timestamp, uint256 totalValue);

    /// @notice Emitted when tokens are swapped during rebalance
    /// @param tokenIn Address of token being sold
    /// @param tokenOut Address of token being bought
    /// @param amountIn Amount of tokenIn sold
    /// @param amountOut Amount of tokenOut received
    event AssetSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    function _connectToIndex(address indexAddress) internal {
        if (!IndexFactory(IndexStorage.INDEX_FACTORY_ADDRESS).isIndexRegistered(indexAddress)) {
            revert IndexFacet_IndexNotRegistered(indexAddress);
        }
        Index(indexAddress).connectGardenToIndex();

        // Store the connected index address
        IndexStorage.layout().indexAddress = indexAddress;
        LibDiamond.layout().isConnectedToIndex = true;
        _rebalance();
        emit IndexConnected(indexAddress);
    }

    function _disconnectFromIndex() internal {
        address indexAddress = IndexStorage.layout().indexAddress;
        Index(indexAddress).disconnectGardenFromIndex();

        // Clear the connected index address
        IndexStorage.layout().indexAddress = address(0);
        LibDiamond.layout().isConnectedToIndex = false;
        emit IndexDisconnected(indexAddress);
    }

    function _rebalance() internal {
        address indexAddress = IndexStorage.layout().indexAddress;
        if (indexAddress == address(0)) revert IndexFacet_NoIndexConnected();

        // Get assets and weights from the index
        (string[] memory symbols, uint256[] memory weights) = Index(indexAddress).getWeights();
    }

    /// @notice Internal function to check if garden is connected to an index
    /// @return True if connected to an index, false otherwise
    function _isConnectedToIndex() internal view returns (bool) {
        return LibDiamond.layout().isConnectedToIndex;
    }
}
