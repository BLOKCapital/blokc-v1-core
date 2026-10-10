// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IFeeFacet } from "src/interfaces/IFeeFacet.sol";
import { FeeBase } from "src/garden/facets/feeBase/FeeBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";
import { FeeStorage } from "src/garden/facets/indexFacets/FeeStorage.sol";
import { IndexStorage } from "src/garden/facets/indexFacets/IndexStorage.sol";

/**
 * @title FeeFacet
 * @author BLOK Capital DAO
 * @notice Garden-level fee module (FEES module): wires the DAO fee registries into the garden,
 *         records deposits into an active fee session, and exposes the fee-session views.
 *         Tool-agnostic — the INDEX module is the first consumer of this layer (its connect
 *         records the basis, its unwind settles fees), and future wealth-management modules
 *         hook into the same session primitives.
 *
 * @dev IMPORTANT: gardens hold index component tokens AND a deposit token (USDC). Any other
 *      non-index, non-USDC token is invisible to fee valuations. Fees settle only in USDC and
 *      only on realized profit at session exit.
 */
contract FeeFacet is IFeeFacet, FeeBase, Facet {
    /// @inheritdoc IFeeFacet
    /// @dev First-time configuration is allowed in any garden state (live gardens adopt fees
    ///      without disconnecting); re-configuration requires no active fee session.
    function configureFeeModule(
        address feeRegistry,
        address treasuryRegistry,
        address onboarderRegistry
    )
        external
        onlyGardenOwner
    {
        _configureFeeModule(feeRegistry, treasuryRegistry, onboarderRegistry);
    }

    /// @inheritdoc IFeeFacet
    function depositUsdc(uint256 amount) external nonReentrant onlyGardenOwner {
        _recordDeposit(_USDC_SYMBOL, amount);
    }

    /// @inheritdoc IFeeFacet
    /// @dev Symbol-keyed: the ComponentRegistry has no token→symbol reverse lookup, and
    ///      keying by symbol keeps deposits restricted to registered components.
    function depositComponent(bytes32 symbol, uint256 amount) external nonReentrant onlyGardenOwner {
        _recordDeposit(symbol, amount);
    }

    /// @inheritdoc IFeeFacet
    function getFeeBasis()
        external
        view
        returns (
            bool basisRecorded,
            uint256 entryUSDC,
            uint256 depositUSDC,
            uint64 connectedAtBlock,
            uint64 connectedAtTimestamp,
            address onboarder,
            uint256 performanceFeeBps,
            uint256 protocolFeeBps,
            uint256 onboarderShareBps,
            uint8 applyRateAtMode
        )
    {
        FeeStorage.Layout storage fs = FeeStorage.layout();
        return (
            fs.basisRecorded,
            fs.entryUSDC,
            fs.depositUSDC,
            fs.connectedAtBlock,
            fs.connectedAtTimestamp,
            fs.onboarderAddress,
            fs.lockedSchedule.performanceFeeBps,
            fs.lockedSchedule.protocolFeeBps,
            fs.lockedSchedule.onboarderShareBps,
            fs.lockedSchedule.applyRateAtMode
        );
    }

    /// @inheritdoc IFeeFacet
    function getFeeRegistries()
        external
        view
        returns (address feeRegistry, address treasuryRegistry, address onboarderRegistry)
    {
        FeeStorage.Layout storage fs = FeeStorage.layout();
        return (fs.feeRegistry, fs.treasuryRegistry, fs.onboarderRegistry);
    }

    /// @inheritdoc IFeeFacet
    function getLastSettlement() external view returns (uint256 lastExitUSDC, int256 lastRealizedProfitUSDC) {
        FeeStorage.Layout storage fs = FeeStorage.layout();
        return (fs.lastExitUSDC, fs.lastRealizedProfitUSDC);
    }
}
