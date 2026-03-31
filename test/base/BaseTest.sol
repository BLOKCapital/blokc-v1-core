// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

/// @title BaseTest
/// @author BLOK Capital DAO
/// @notice Root test contract shared by every test suite. Provides:
///         - Named test addresses (owner, users, attacker, etc.)
///         - Common labels for trace readability
///         - Utility helpers used across all test categories
abstract contract BaseTest is Test {
    // ═══════════════════════════════════════════════════════════════════════
    //                         NAMED ADDRESSES
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Protocol / contract deployer
    address public deployer = makeAddr("deployer");

    /// @notice Generic owner used for Ownable contracts
    address public owner = makeAddr("owner");

    /// @notice Secondary owner (for multi-garden / multi-contract tests)
    address public owner2 = makeAddr("owner2");

    /// @notice Non-privileged user (should be rejected by access control)
    address public nonOwner = makeAddr("nonOwner");

    /// @notice Attacker address for negative-path security tests
    address public attacker = makeAddr("attacker");

    /// @notice Generic user accounts for multi-user scenarios
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    /// @notice Garden owner — used specifically for Diamond proxy tests
    address public gardenOwner = makeAddr("gardenOwner");

    /// @notice Updater role (e.g. CirculatingSupply updater)
    address public updater = makeAddr("updater");

    // ═══════════════════════════════════════════════════════════════════════
    //                         MODULE / TYPE CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════

    bytes32 public constant BASE_MODULE = keccak256("BASE");
    bytes32 public constant DEX_MODULE = keccak256("DEX");
    bytes32 public constant LENDING_MODULE = keccak256("LENDING");
    bytes32 public constant INDEX_MODULE = keccak256("INDEX");
    bytes32 public constant WITHDRAW_MODULE = keccak256("WITHDRAW");
    bytes32 public constant CCTP_MODULE = keccak256("CCTP");
    bytes32 public constant REWARD_MODULE = keccak256("REWARD");

    bytes32 public constant GARDEN_TYPE_STANDARD = keccak256("STANDARD");
    bytes32 public constant GARDEN_TYPE_INDEX = keccak256("INDEX");

    bytes32 public constant MODULE_1 = keccak256("MODULE_1");
    bytes32 public constant MODULE_2 = keccak256("MODULE_2");
    bytes32 public constant MODULE_3 = keccak256("MODULE_3");

    bytes32 public constant GARDEN_TYPE_1 = keccak256("GARDEN_TYPE_1");
    bytes32 public constant GARDEN_TYPE_2 = keccak256("GARDEN_TYPE_2");

    // ═══════════════════════════════════════════════════════════════════════
    //                         SETUP
    // ═══════════════════════════════════════════════════════════════════════

    function setUp() public virtual {
        // Fund test addresses with ETH for gas
        vm.deal(deployer, 100 ether);
        vm.deal(owner, 100 ether);
        vm.deal(owner2, 100 ether);
        vm.deal(gardenOwner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(attacker, 100 ether);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         UTILITIES
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Create a single-element bytes4 array (for selector arrays)
    function _singleSelector(bytes4 sel) internal pure returns (bytes4[] memory arr) {
        arr = new bytes4[](1);
        arr[0] = sel;
    }

    /// @notice Create a two-element bytes4 array
    function _twoSelectors(bytes4 a, bytes4 b) internal pure returns (bytes4[] memory arr) {
        arr = new bytes4[](2);
        arr[0] = a;
        arr[1] = b;
    }

    /// @notice Create a single-element bytes32 array (for module ID arrays)
    function _singleModule(bytes32 moduleId) internal pure returns (bytes32[] memory arr) {
        arr = new bytes32[](1);
        arr[0] = moduleId;
    }

    /// @notice Create a two-element bytes32 array
    function _twoModules(bytes32 a, bytes32 b) internal pure returns (bytes32[] memory arr) {
        arr = new bytes32[](2);
        arr[0] = a;
        arr[1] = b;
    }

    /// @notice Create an empty bytes32 array
    function _noModules() internal pure returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    /// @notice Warp forward by a given number of seconds
    function _skipTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @notice Bound a fuzzed address to exclude zero, precompiles, and test contract
    function _boundAddress(address addr) internal view returns (address) {
        return address(uint160(bound(uint160(addr), 100, type(uint160).max)));
    }
}
