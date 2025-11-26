// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DataTypes } from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "./MockERC20.sol";

/// @title Mock Aave Pool for testing
contract MockAavePool {
    mapping(address => DataTypes.ReserveData) public reserves;
    mapping(address => address) public aTokens; // underlying -> aToken

    function setReserveData(address underlying, address aTokenAddress) external {
        reserves[underlying].aTokenAddress = aTokenAddress;
        aTokens[underlying] = aTokenAddress;
    }

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory) {
        return reserves[asset];
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        address aToken = aTokens[asset];
        if (aToken != address(0)) {
            MockERC20(aToken).mint(onBehalfOf, amount);
        }
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        address aToken = aTokens[asset];
        require(aToken != address(0), "Reserve not configured");

        MockERC20(aToken).burn(msg.sender, amount);
        IERC20(asset).transfer(to, amount);
        return amount;
    }

    // Stub implementations for IPool interface
    function deposit(address, uint256, address, uint16) external pure returns (uint256) {
        return 0;
    }

    function borrow(address, uint256, uint256, uint16, address) external pure returns (uint256) {
        return 0;
    }

    function repay(address, uint256, uint256, address) external pure returns (uint256) {
        return 0;
    }

    function repayWithATokens(address, uint256, uint256) external pure returns (uint256) {
        return 0;
    }

    function repayWithPermit(
        address,
        uint256,
        uint256,
        address,
        uint256,
        uint8,
        bytes32,
        bytes32
    )
        external
        pure
        returns (uint256)
    {
        return 0;
    }

    function swapBorrowRateMode(address, uint256) external pure { }

    function rebalanceStableBorrowRate(address, address) external pure { }

    function setUserUseReserveAsCollateral(address, bool) external pure { }

    function liquidationCall(address, address, address, uint256, bool) external pure { }

    function flashLoan(
        address,
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        address,
        bytes calldata,
        uint16
    )
        external
        pure
    { }

    function flashLoanSimple(address, address, uint256, bytes calldata, uint16) external pure { }

    function getUserAccountData(address) external pure returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        return (0, 0, 0, 0, 0, 0);
    }

    function initReserve(address, address, address, address, address) external pure { }

    function dropReserve(address) external pure { }

    function setReserveInterestRateStrategyAddress(address, address) external pure { }

    function setConfiguration(address, DataTypes.ReserveConfigurationMap calldata) external pure { }

    function getConfiguration(address) external pure returns (DataTypes.ReserveConfigurationMap memory) {
        return DataTypes.ReserveConfigurationMap(0);
    }

    function getUserConfiguration(address) external pure returns (DataTypes.UserConfigurationMap memory) {
        return DataTypes.UserConfigurationMap(0);
    }

    function getReserveNormalizedIncome(address) external pure returns (uint256) {
        return 1e27;
    }

    function getReserveNormalizedVariableDebt(address) external pure returns (uint256) {
        return 0;
    }

    function getReservesList() external pure returns (address[] memory) {
        return new address[](0);
    }

    function ADDRESSES_PROVIDER() external pure returns (address) {
        return address(0);
    }

    function BRIDGE_PROTOCOL_FEE() external pure returns (uint256) {
        return 0;
    }

    function FLASHLOAN_PREMIUM_TOTAL() external pure returns (uint128) {
        return 0;
    }

    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external pure returns (uint128) {
        return 0;
    }

    function MAX_NUMBER_RESERVES() external pure returns (uint16) {
        return 0;
    }

    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external pure returns (uint256) {
        return 0;
    }

    function POOL_REVISION() external pure returns (uint256) {
        return 0;
    }
}
