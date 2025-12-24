//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title IndexFacet
    @author BLOK Capital DAO
    @notice Facet that manages portfolio rebalancing according to connected
            index contracts.
    @dev Implements automated rebalancing functionality for Diamond (garden)
         contracts. Connects to Index contracts to obtain target weights and
         rebalances portfolio holdings via Uniswap V3 swaps. Uses WETH as base
         currency for efficient swaps.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { Facet } from "src/garden/facets/Facet.sol";
import { IIndex } from "src/garden/facets/indexFacets/IIndex.sol";
import {IndexBase} from "src/garden/facets/indexFacets/IndexBase.sol";

contract IndexFacet is IIndex, IndexBase, Facet {


    // ========================================================================
    // External Functions
    // ========================================================================

    /// @notice Connects the garden to an index for automated rebalancing
    /// @param indexAddress Address of the index contract to track
    /// @dev Only callable by garden owner. Validates index is registered in IndexFactory
    ///      and calls the index to register this garden as connected.
    function connectToIndex(address indexAddress) external nonReentrant onlyGardenOwner ifIndexNotConnected {
        _connectToIndex(indexAddress);
    }

    /// @notice Disconnects the garden from its currently connected index
    /// @dev Only callable by garden owner. Notifies the index of disconnection
    ///      and clears the stored index address.
    function disconnectFromIndex() external nonReentrant onlyGardenOwner {
        _disconnectFromIndex();
    }

    /// @notice Manually triggers a rebalance of the portfolio to match index weights
    /// @dev Only callable by garden owner. Requires index to be connected.
    ///      Performs full rebalance including USDC->WETH conversion and component rebalancing.
    function rebalance() external nonReentrant onlyGardenOwner {
        _rebalance();
    }

    /// @notice Checks if the garden is currently connected to an index
    /// @return True if connected to an index, false otherwise
    function isConnectedToIndex() external view returns (bool) {
        return _isConnectedToIndex();
    }
}
