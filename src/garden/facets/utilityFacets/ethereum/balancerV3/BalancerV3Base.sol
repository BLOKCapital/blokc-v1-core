// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";
import { IBalancerRouter } from "src/garden/facets/utilityFacets/ethereum/balancerV3/IBalancerRouter.sol";
import { IBalancerVault } from "src/garden/facets/utilityFacets/ethereum/balancerV3/IBalancerVault.sol";
import {
    IPermit2AllowanceTransfer
} from "src/garden/facets/utilityFacets/ethereum/balancerV3/IPermit2AllowanceTransfer.sol";

error BalancerV3Facet_InvalidPath();
error BalancerV3Facet_MultiHopUnsupported();
error BalancerV3Facet_InvalidPoolAddress();
error BalancerV3Facet_InvalidTokenAddress();
error BalancerV3Facet_IdenticalTokens();
error BalancerV3Facet_InvalidAmount();
error BalancerV3Facet_DexInactive();
error BalancerV3Facet_UnregisteredPool();
error BalancerV3Facet_UninitializedPool();
error BalancerV3Facet_PoolDexMismatch();
error BalancerV3Facet_PoolTokenMismatch();
error BalancerV3Facet_UnsupportedPoolTokenCount(uint256 tokenCount);
error BalancerV3Facet_Permit2AmountTooLarge(uint256 amount);

/**
 * @title BalancerV3Base
 * @notice Shared Balancer V3 swap / quote logic. One swap selector and one quote selector,
 *         both using the standardised SwapInstruction / QuoteInstruction structs. Single-hop only.
 */
abstract contract BalancerV3Base {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    address internal constant BALANCER_V3_ROUTER_ADDRESS = 0xAE563E3f8219521950555F5962419C8919758Ea2;
    address internal constant BALANCER_V3_VAULT_ADDRESS = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;
    address internal constant BALANCER_V3_PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant POOL_REGISTRY_ADDRESS = 0xDe6338E4dd7B0A2076e8CE63cC0443dC6cE7f0B6;

    bytes32 internal constant BALANCER_V3_DEX_ID = keccak256("BALANCER_V3");

    // Permit2 short-lived approval window for swap execution.
    // The allowance is revoked at the end of the swap path regardless.
    uint48 internal constant PERMIT2_APPROVAL_WINDOW = 300;

    // ========================================================================
    // Events
    // ========================================================================

    event BalancerV3FacetTokensSwapped(
        address indexed pool, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    // ========================================================================
    // Swap Dispatcher
    // ========================================================================

    /// @notice Standardised swap dispatcher used by the rebalance flow.
    ///         Accepts single-hop SwapInstructions only.
    function _balancerV3Swap(SwapInstruction calldata inst) internal {
        (address pool, address tokenIn, address tokenOut) = _unpackSingleHop(inst);
        _validateDexActive();
        _validatePool(pool, tokenIn, tokenOut);

        if (inst.amountIn == 0 || inst.amountOut == 0) revert BalancerV3Facet_InvalidAmount();

        if (!inst.exactOutput) {
            _swapExactIn(pool, tokenIn, tokenOut, inst.amountIn, inst.amountOut);
        } else {
            _swapExactOut(pool, tokenIn, tokenOut, inst.amountOut, inst.amountIn);
        }
    }

    // ========================================================================
    // Swap Internals
    // ========================================================================

    function _swapExactIn(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum
    )
        internal
    {
        _approvePermit2Spending(tokenIn, amountIn);

        uint256 amountOut = IBalancerRouter(BALANCER_V3_ROUTER_ADDRESS)
            .swapSingleTokenExactIn(
                pool, IERC20(tokenIn), IERC20(tokenOut), amountIn, amountOutMinimum, block.timestamp, false, ""
            );

        _clearApprovals(tokenIn);
        emit BalancerV3FacetTokensSwapped(pool, tokenIn, tokenOut, amountIn, amountOut);
    }

    function _swapExactOut(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMaximum
    )
        internal
    {
        _approvePermit2Spending(tokenIn, amountInMaximum);

        uint256 amountIn = IBalancerRouter(BALANCER_V3_ROUTER_ADDRESS)
            .swapSingleTokenExactOut(
                pool, IERC20(tokenIn), IERC20(tokenOut), amountOut, amountInMaximum, block.timestamp, false, ""
            );

        _clearApprovals(tokenIn);
        emit BalancerV3FacetTokensSwapped(pool, tokenIn, tokenOut, amountIn, amountOut);
    }

    // ========================================================================
    // Quote Dispatcher
    // ========================================================================

    /// @notice Best-effort spot quote derived from Balancer Vault live balances.
    ///         Constant-product approximation; not router-consistent for
    ///         weighted / stable / custom pools. See IBalancerV3.balancerV3Quote.
    function _balancerV3Quote(QuoteInstruction calldata inst) internal view returns (uint256 result) {
        (address pool, address tokenIn, address tokenOut) = _unpackSingleHopQuote(inst);
        if (inst.amount == 0) revert BalancerV3Facet_InvalidAmount();
        _validateDexActive();
        _validatePool(pool, tokenIn, tokenOut);

        (uint256 balIn18, uint256 balOut18) = _liveBalances18(pool, tokenIn, tokenOut);
        if (balIn18 == 0 || balOut18 == 0) revert BalancerV3Facet_InvalidAmount();

        uint8 inDecimals = IERC20Metadata(tokenIn).decimals();
        uint8 outDecimals = IERC20Metadata(tokenOut).decimals();

        if (!inst.exactOutput) {
            uint256 amountIn18 = _scaleTo18(inst.amount, inDecimals);
            uint256 amountOut18 = (amountIn18 * balOut18) / balIn18;
            result = _scaleFrom18(amountOut18, outDecimals);
        } else {
            uint256 amountOut18 = _scaleTo18(inst.amount, outDecimals);
            uint256 amountIn18 = (amountOut18 * balIn18) / balOut18;
            result = _scaleFrom18(amountIn18, inDecimals);
        }
    }

    // ========================================================================
    // Path Unpacking
    // ========================================================================

    function _unpackSingleHop(SwapInstruction calldata inst)
        private
        pure
        returns (address pool, address tokenIn, address tokenOut)
    {
        if (inst.pools.length != 1) revert BalancerV3Facet_MultiHopUnsupported();
        if (inst.tokens.length != 2) revert BalancerV3Facet_InvalidPath();
        pool = inst.pools[0];
        tokenIn = inst.tokens[0];
        tokenOut = inst.tokens[1];
    }

    function _unpackSingleHopQuote(QuoteInstruction calldata inst)
        private
        pure
        returns (address pool, address tokenIn, address tokenOut)
    {
        if (inst.pools.length != 1) revert BalancerV3Facet_MultiHopUnsupported();
        if (inst.tokens.length != 2) revert BalancerV3Facet_InvalidPath();
        pool = inst.pools[0];
        tokenIn = inst.tokens[0];
        tokenOut = inst.tokens[1];
    }

    // ========================================================================
    // Validation
    // ========================================================================

    function _validateDexActive() internal view {
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isDexActive(BALANCER_V3_DEX_ID)) {
            revert BalancerV3Facet_DexInactive();
        }
    }

    function _validatePool(address pool, address tokenIn, address tokenOut) internal view {
        if (pool == address(0)) revert BalancerV3Facet_InvalidPoolAddress();
        if (tokenIn == address(0) || tokenOut == address(0)) revert BalancerV3Facet_InvalidTokenAddress();
        if (tokenIn == tokenOut) revert BalancerV3Facet_IdenticalTokens();

        ILiquidityPoolRegistry registry = ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS);
        if (!registry.isPoolRegistered(pool)) revert BalancerV3Facet_UnregisteredPool();

        ILiquidityPoolRegistry.PoolInfo memory poolInfo = registry.getPool(pool);
        if (poolInfo.dexId != BALANCER_V3_DEX_ID) revert BalancerV3Facet_PoolDexMismatch();

        (address token0, address token1) = _sortTokens(tokenIn, tokenOut);
        if (poolInfo.token0 != token0 || poolInfo.token1 != token1) revert BalancerV3Facet_PoolTokenMismatch();

        IBalancerVault vault = IBalancerVault(BALANCER_V3_VAULT_ADDRESS);
        if (!vault.isPoolRegistered(pool)) revert BalancerV3Facet_UnregisteredPool();
        if (!vault.isPoolInitialized(pool)) revert BalancerV3Facet_UninitializedPool();

        IERC20[] memory poolTokens = vault.getPoolTokens(pool);
        if (poolTokens.length != 2) revert BalancerV3Facet_UnsupportedPoolTokenCount(poolTokens.length);

        bool hasTokenIn = address(poolTokens[0]) == tokenIn || address(poolTokens[1]) == tokenIn;
        bool hasTokenOut = address(poolTokens[0]) == tokenOut || address(poolTokens[1]) == tokenOut;
        if (!hasTokenIn || !hasTokenOut) revert BalancerV3Facet_PoolTokenMismatch();
    }

    // ========================================================================
    // Permit2
    // ========================================================================

    /// @notice Grants a short-lived Permit2 allowance to the Balancer Router.
    ///         `_clearApprovals` is called at the end of each swap to revoke
    ///         any residual authority on the `amountInMaximum - amountIn` delta.
    function _approvePermit2Spending(address token, uint256 amount) internal {
        if (amount > type(uint160).max) revert BalancerV3Facet_Permit2AmountTooLarge(amount);
        IERC20(token).forceApprove(BALANCER_V3_PERMIT2_ADDRESS, amount);
        IPermit2AllowanceTransfer(BALANCER_V3_PERMIT2_ADDRESS)
            .approve(
                token, BALANCER_V3_ROUTER_ADDRESS, uint160(amount), uint48(block.timestamp + PERMIT2_APPROVAL_WINDOW)
            );
    }

    /// @notice Revokes Permit2 + ERC20 allowances so no residual authority survives the swap.
    function _clearApprovals(address token) internal {
        IPermit2AllowanceTransfer(BALANCER_V3_PERMIT2_ADDRESS).approve(token, BALANCER_V3_ROUTER_ADDRESS, 0, 0);
        IERC20(token).forceApprove(BALANCER_V3_PERMIT2_ADDRESS, 0);
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _liveBalances18(
        address pool,
        address tokenIn,
        address tokenOut
    )
        private
        view
        returns (uint256 balIn18, uint256 balOut18)
    {
        // getPoolTokenInfo returns (tokens, tokenInfo, balancesRaw, lastBalancesLiveScaled18).
        // We skip tokenInfo (per-token type/rate metadata) and balancesRaw (native-decimal amounts)
        // and use lastBalancesLiveScaled18 directly — already 18-decimal and rate-adjusted —
        // in a single vault call, avoiding a separate getCurrentLiveBalances call.
        (IERC20[] memory tokens,,, uint256[] memory liveBalances) =
            IBalancerVault(BALANCER_V3_VAULT_ADDRESS).getPoolTokenInfo(pool);

        for (uint256 i; i < tokens.length; i++) {
            address tokenAddr = address(tokens[i]);
            if (tokenAddr == tokenIn) balIn18 = liveBalances[i];
            else if (tokenAddr == tokenOut) balOut18 = liveBalances[i];
        }
    }

    function _scaleTo18(uint256 amount, uint8 decimals) private pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount * (10 ** (18 - decimals));
        return amount / (10 ** (decimals - 18));
    }

    function _scaleFrom18(uint256 amount18, uint8 decimals) private pure returns (uint256) {
        if (decimals == 18) return amount18;
        if (decimals < 18) return amount18 / (10 ** (18 - decimals));
        return amount18 * (10 ** (decimals - 18));
    }
}
