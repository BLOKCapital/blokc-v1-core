// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/**
 * @title ArbitrumOneAddresses
 * @notice Single source of truth for Arbitrum One deployment addresses baked into
 *         compile-time constants. The arbitrumOne DEX bases re-export
 *         POOL_REGISTRY_ADDRESS from here, and the deployment scripts assert against
 *         this library — so a deploy with stale values aborts instead of shipping
 *         silently while the facets point at the old protocol.
 */
library ArbitrumOneAddresses {
    /// @notice LiquidityPoolRegistry contract address (for DEX selector resolution)
    address internal constant POOL_REGISTRY_ADDRESS = 0xA3178280c191dD46c551b91c651F337E47594d85;
}
