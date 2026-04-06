// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Facet } from "src/garden/facets/Facet.sol";
import { IIndex, SwapStep } from "src/garden/facets/indexFacets/IIndex.sol";
import { IndexBase } from "src/garden/facets/indexFacets/IndexBase.sol";

/**
 * @title IndexFacet
 * @author BLOK Capital DAO
 * @notice Facet that implements the IIndex interface to allow connecting to an Index contract, signaling rebalance
 * intents, and executing rebalances through the Index. This facet provides external functions for garden owners to
 * manage their connection to an Index and for anyone to trigger rebalances when there is an active intent. It inherits
 * from IndexBase which contains the internal logic for interacting with the Index, while IndexFacet itself provides the
 * external interface with appropriate access control and user-facing error messages.
 *
 * @dev IMPORTANT: Gardens using this facet (INDEX type) hold index component tokens and a deposit token (USDC).
 *      Both are accounted for in rebalance value calculations. Any other non-index, non-USDC tokens are invisible
 *      to these calculations and will not be protected during swaps.
 */
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
    /// @dev Does NOT use nonReentrant to avoid conflict with DEX facets' nonReentrant
    ///      during address(this).call(). Uses custom rebalancing flag in IndexStorage instead.
    function rebalance(SwapStep[] calldata steps) external {
        _rebalance(steps);
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

