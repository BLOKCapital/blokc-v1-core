//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Facet } from "src/garden/facets/Facet.sol";
import { IIndex, SwapCall } from "src/garden/facets/indexFacets/IIndex.sol";
import { IndexBase } from "src/garden/facets/indexFacets/IndexBase.sol";

/// @notice Facet that allows gardens to connect to index contracts for automated rebalancing.
///         Gardens can create rebalance intents, which are processed by the CRE to generate swap calls.
///         The facet then executes these swap calls to rebalance the garden's portfolio according to the index's target
///         allocations.
contract IndexFacet is IIndex, IndexBase, Facet {
    /// @inheritdoc IIndex
    function connectToIndex(address indexAddress) external nonReentrant onlyGardenOwner ifIndexNotConnected {
        _connectToIndex(indexAddress);
    }

    /// @inheritdoc IIndex
    function disconnectFromIndex() external nonReentrant onlyGardenOwner {
        _disconnectFromIndex();
    }

    /// @inheritdoc IIndex
    function rebalanceIntent() external nonReentrant {
        _rebalanceIntent();
    }

    /// @inheritdoc IIndex
    function rebalance(SwapCall[] calldata swapCalls) external nonReentrant {
        _rebalance(swapCalls);
    }

    /// @inheritdoc IIndex
    function isConnectedToIndex() external view returns (bool) {
        return _isConnectedToIndex();
    }

    /// @inheritdoc IIndex
    function getConnectedIndex() external view returns (address) {
        return _getConnectedIndex();
    }

    /// @inheritdoc IIndex
    function hasPendingIntent() external view returns (bool) {
        return _hasPendingIntent();
    }

    /// @inheritdoc IIndex
    function getPendingIntent()
        external
        view
        returns (
            bool active,
            uint256 totalValueUsd,
            string[] memory symbols,
            uint256[] memory currentValues,
            uint256[] memory targetValues
        )
    {
        return _getPendingIntent();
    }
}

