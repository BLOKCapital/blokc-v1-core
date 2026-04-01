// SPDX-License-Identifier: MIT
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

/**
 * @title IndexFacet
 * @author BLOK Capital DAO
 * @notice Facet that enables gardens to connect to an Index and execute single-transaction rebalances.
 *         CRE (or any caller) submits SwapCall[] and the contract validates the outcome using fresh
 *         Chainlink prices — if balances don't match targets or value is lost, the tx reverts atomically.
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
    /// @dev Does NOT use nonReentrant to avoid conflict with DEX facets' nonReentrant
    ///      during address(this).call(). Uses custom rebalancing flag in IndexStorage instead.
    function rebalance(SwapCall[] calldata swapCalls) external {
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
    function getLastRebalanceTimestamp() external view returns (uint256) {
        return _getLastRebalanceTimestamp();
    }
}
