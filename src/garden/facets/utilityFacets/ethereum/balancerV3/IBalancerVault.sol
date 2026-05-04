// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal Balancer V3 Vault interface used for pool validation and quote approximation.
interface IBalancerVault {
    enum TokenType {
        STANDARD,
        WITH_RATE
    }

    struct TokenInfo {
        TokenType tokenType;
        address rateProvider;
        bool paysYieldFees;
    }

    function isPoolRegistered(address pool) external view returns (bool registered);

    function isPoolInitialized(address pool) external view returns (bool initialized);

    function getPoolTokens(address pool) external view returns (IERC20[] memory tokens);

    /// @notice Returns pool token metadata together with raw and live-scaled balances.
    /// @dev `balancesRaw` is in each token's native decimals. `lastBalancesLiveScaled18`
    ///      is decimal-normalised to 1e18 and pre-multiplied by the rate-provider rate for
    ///      WITH_RATE tokens — do NOT use it for a raw spot quote.
    function getPoolTokenInfo(address pool)
        external
        view
        returns (
            IERC20[] memory tokens,
            TokenInfo[] memory tokenInfo,
            uint256[] memory balancesRaw,
            uint256[] memory lastBalancesLiveScaled18
        );
}
