// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*###############################################################################

    @title CCTP Facet
    @author BLOK Capital DAO
    @notice Facet exposing Circle Cross-Chain Transfer Protocol (CCTP) functions (send / redeem).
    @dev This facet wires the Circle CCTP interfaces to internal implementations and
         registers the interface id during initialization.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ICCTP, IMessageTransmitterV2, ITokenMessengerV2 } from "src/interfaces/ICCTP.sol";
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

error CCTPFacet_ZeroAmount();
error CCTPFacet_NoUSDCMinted();

contract CCTPFacet is ICCTP {
    using SafeERC20 for IERC20;

    address public constant TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address public constant MESSAGE_TRANSMITTER_V2 = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    event CCTPFacetUSDCSent(address indexed sender, uint256 amount, uint32 destinationDomain, bytes32 mintRecipient);
    event CCTPFacetUSDCRedeemed(uint256 mintedAmount);

    /// @notice Send (burn) native USDC here and instruct Circle to mint on destination
    /// @param amount USDC amount (USDC usually 6 decimals)
    /// @param destinationDomain Circle domain id of destination chain
    /// @param mintRecipient bytes32-encoded recipient on destination chain
    function sendUSDC(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient) external {
        if (amount == 0) {
            revert CCTPFacet_ZeroAmount();
        }

        // pull USDC from caller
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);

        // approve TokenMessenger to burn the tokens
        IERC20(USDC).approve(TOKEN_MESSENGER_V2, 0);
        IERC20(USDC).approve(TOKEN_MESSENGER_V2, amount);

        // call Circle TokenMessengerV2.depositForBurn
        ITokenMessengerV2(TOKEN_MESSENGER_V2).depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            USDC,
            bytes32(0), // destinationCaller (optional)
            0, // maxFee
            0 // minFinalityThreshold
        );

        emit CCTPFacetUSDCSent(msg.sender, amount, destinationDomain, mintRecipient);
    }

    /// @notice Redeem (submit Circle attestation) to mint USDC to this contract
    /// @param message raw message bytes from Circle attestation flow
    /// @param attestation attestation bytes
    function redeemUSDC(bytes calldata message, bytes calldata attestation) external {
        uint256 beforeBalance = IERC20(USDC).balanceOf(address(this));

        // submit the attestation -> MessageTransmitterV2 will route to TokenMinterV2 and mint USDC here
        IMessageTransmitterV2(MESSAGE_TRANSMITTER_V2).receiveMessage(message, attestation);

        uint256 afterBalance = IERC20(USDC).balanceOf(address(this));
        if (afterBalance <= beforeBalance) {
            revert CCTPFacet_NoUSDCMinted();
        }

        uint256 mintedAmount = afterBalance - beforeBalance;

        emit CCTPFacetUSDCRedeemed(mintedAmount);
    }
}
