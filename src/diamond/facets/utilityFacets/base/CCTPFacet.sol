// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title CCTPFacet
    @author BLOK Capital DAO
    @notice Facet exposing Circle Cross-Chain Transfer Protocol (CCTP) functions
    @dev This facet provides integration with Circle's CCTP for cross-chain USDC
         transfers. All operations are protected by owner-only access control.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Local Interfaces
import { ICCTP, IMessageTransmitterV2, ITokenMessengerV2 } from "src/interfaces/ICCTP.sol";

// Local Libraries
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when amount is zero
error CCTPFacet_ZeroAmount();

/// @notice Thrown when no USDC was minted after redemption
error CCTPFacet_NoUSDCMinted();

/// @notice Thrown when message bytes are empty
error CCTPFacet_InvalidMessage();

/// @notice Thrown when attestation bytes are empty
error CCTPFacet_InvalidAttestation();

/// @notice Thrown when contract has insufficient USDC balance
error CCTPFacet_InsufficientBalance();

/// @notice Thrown when token transfer from caller fails
error CCTPFacet_TransferFailed();

// ============================================================================
// CCTPFacet
// ============================================================================

/**
 * @title CCTPFacet
 * @notice Facet providing Circle Cross-Chain Transfer Protocol (CCTP) integration
 * @dev This facet allows the diamond owner to:
 *      - Send USDC to other chains via Circle's CCTP (burn and mint)
 *      - Redeem USDC from other chains (mint on this chain after attestation)
 *
 *      All operations are protected by owner-only access control. Uses SafeERC20
 *      for secure token transfers and approvals.
 *
 *      Constants are hardcoded for Base deployment. For other chains,
 *      these would need to be updated or made configurable.
 */
contract CCTPFacet is ICCTP {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice Circle TokenMessengerV2 address on Base
    address public constant TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;

    /// @notice Circle MessageTransmitterV2 address on Base
    address public constant MESSAGE_TRANSMITTER_V2 = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;

    /// @notice USDC token address on Base
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when USDC is sent to another chain via CCTP
    /// @param sender The address that initiated the send (msg.sender, not diamond)
    /// @param amount The amount of USDC sent
    /// @param destinationDomain The Circle domain ID of the destination chain
    /// @param mintRecipient The recipient address on the destination chain (bytes32 encoded)
    event CCTPFacetUSDCSent(address indexed sender, uint256 amount, uint32 destinationDomain, bytes32 mintRecipient);

    /// @notice Emitted when USDC is redeemed (minted) from another chain
    /// @param mintedAmount The amount of USDC minted to this contract
    event CCTPFacetUSDCRedeemed(uint256 mintedAmount);

    // ========================================================================
    // Modifiers
    // ========================================================================

    /// @notice Restricts function to diamond owner only
    modifier onlyDiamondOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // ========================================================================
    // External Functions
    // ========================================================================

    /**
     * @notice Sends (burns) native USDC and instructs Circle to mint on destination chain
     * @dev Transfers USDC from caller, approves TokenMessenger, then calls depositForBurn.
     *      The caller must have approved this facet to spend their USDC.
     *
     *      IMPORTANT: The USDC is transferred from msg.sender (the caller), not from
     *      the diamond's balance. This allows users to send their own USDC directly.
     *
     * @param amount USDC amount to send (usually 6 decimals)
     * @param destinationDomain Circle domain ID of the destination chain
     * @param mintRecipient Bytes32-encoded recipient address on destination chain
     */
    function sendUSDC(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient) external onlyDiamondOwner {
        if (amount == 0) {
            revert CCTPFacet_ZeroAmount();
        }

        IERC20 usdc = IERC20(USDC);

        // Transfer USDC from caller (msg.sender) to this contract
        // Note: The caller must have approved this facet to spend their USDC
        // In this case, msg.sender is the diamond owner, so they approve the diamond
        // The diamond then calls this function, so the approval is for the diamond address
        uint256 balanceBefore = usdc.balanceOf(address(this));
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = usdc.balanceOf(address(this));

        // Verify transfer succeeded (defense in depth)
        if (balanceAfter - balanceBefore < amount) {
            revert CCTPFacet_TransferFailed();
        }

        // Approve TokenMessenger to burn the tokens
        // Use forceApprove which handles non-standard ERC20 tokens that require resetting allowance
        usdc.forceApprove(TOKEN_MESSENGER_V2, amount);

        // Call Circle TokenMessengerV2.depositForBurn
        // This burns the USDC and produces a message for the destination chain
        ITokenMessengerV2(TOKEN_MESSENGER_V2).depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            USDC,
            bytes32(0), // destinationCaller (optional, not used)
            0, // maxFee (0 = use default)
            0 // minFinalityThreshold (0 = use default)
        );

        emit CCTPFacetUSDCSent(msg.sender, amount, destinationDomain, mintRecipient);
    }

    /**
     * @notice Redeems (mints) USDC from another chain using Circle attestation
     * @dev Submits message and attestation to MessageTransmitterV2, which routes
     *      to TokenMinterV2 to mint USDC to this contract. Verifies USDC was
     *      actually minted before emitting event.
     *
     * @param message Raw message bytes from Circle attestation flow
     * @param attestation Attestation bytes from Circle network
     */
    function redeemUSDC(bytes calldata message, bytes calldata attestation) external onlyDiamondOwner {
        if (message.length == 0) {
            revert CCTPFacet_InvalidMessage();
        }
        if (attestation.length == 0) {
            revert CCTPFacet_InvalidAttestation();
        }

        IERC20 usdc = IERC20(USDC);
        uint256 beforeBalance = usdc.balanceOf(address(this));

        // Submit the attestation -> MessageTransmitterV2 routes to TokenMinterV2 and mints USDC
        IMessageTransmitterV2(MESSAGE_TRANSMITTER_V2).receiveMessage(message, attestation);

        uint256 afterBalance = usdc.balanceOf(address(this));

        // Verify USDC was actually minted
        if (afterBalance <= beforeBalance) {
            revert CCTPFacet_NoUSDCMinted();
        }

        uint256 mintedAmount = afterBalance - beforeBalance;

        emit CCTPFacetUSDCRedeemed(mintedAmount);
    }
}
