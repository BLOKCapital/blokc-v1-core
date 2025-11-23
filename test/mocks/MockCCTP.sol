// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ICCTP,
    ITokenMessengerV2,
    IMessageTransmitterV2
} from "src/diamond/facets/utilityFacets/arbitrumOne/cctp/ICCTP.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "./MockERC20.sol";

/// @title Mock CCTP TokenMessenger for testing
contract MockTokenMessengerV2 is ITokenMessengerV2 {
    address public burnToken;
    bool public shouldRevert;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function depositForBurn(
        uint256 amount,
        uint32,
        bytes32,
        address token,
        bytes32,
        uint256,
        uint32
    )
        external
        override
    {
        if (shouldRevert) revert("Mock revert");
        burnToken = token;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        // Burn the tokens
        MockERC20(token).burn(address(this), amount);
    }
}

/// @title Mock CCTP MessageTransmitter for testing
contract MockMessageTransmitterV2 is IMessageTransmitterV2 {
    address public mintToken;
    uint256 public mintAmount;
    bool public shouldRevert;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setMintParams(address token, uint256 amount) external {
        mintToken = token;
        mintAmount = amount;
    }

    function receiveMessage(bytes calldata, bytes calldata) external override {
        if (shouldRevert) revert("Mock revert");
        if (mintToken != address(0) && mintAmount > 0) {
            MockERC20(mintToken).mint(msg.sender, mintAmount);
        }
    }
}
