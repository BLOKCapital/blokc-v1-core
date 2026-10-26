// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase } from "../../base/DiamondTestBase.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ApproveFacet } from "src/garden/facets/utilityFacets/ApproveFacet.sol";
import { ApproveStorage } from "src/garden/facets/utilityFacets/ApproveStorage.sol";
import { LibStorageSlot } from "src/garden/libraries/LibStorageSlot.sol";
import { MockERC20 } from "../../mock/MockERC20.sol";

interface IApproveTokens {
    function approveTokens(address[] calldata tokens, address spender) external;
    function revokeTokens(address[] calldata tokens, address spender) external;
}

/**
 * @title ApproveFacetTest
 * @notice Exercises the production install path for ApproveFacet: the facet is added to
 *         a module in the real FacetRegistry, the garden is deployed, and the facet is
 *         installed through the two-step upgrade (upgradeDetails -> upgrade) — the same
 *         sequence DeployApproveFacet.s.sol / UpgradeGardens.s.sol run on mainnet.
 *         Asserts the garden (diamond) grants max allowance to the Rebalancer, that the
 *         owner can revoke it (including legacy arbitrary spenders), and that ownership
 *         transfer clears every tracked approval.
 */
contract ApproveFacetTest is DiamondTestBase {
    bytes32 internal constant MODULE = keccak256("APPROVE");
    bytes32 internal constant GARDEN_TYPE = keccak256("INDEX");

    address internal diamondOwner = address(0xA11CE);
    // Spending is restricted to the DAO's canonical rebalancer (external audit H01) —
    // the tests publish the pointer and grant to it
    address internal spender;
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    address internal garden;

    function setUp() public override {
        super.setUp();

        // Publish the canonical rebalancer — approveTokens fails closed while unset
        spender = address(0xB0B);
        registry.setCanonicalRebalancer(spender);

        // -- Module holding the ApproveFacet (mirrors the upgradeModule step) --
        ApproveFacet approveFacet = new ApproveFacet();
        _registerModule(MODULE);

        bytes4[] memory sels = new bytes4[](2);
        sels[0] = approveFacet.approveTokens.selector;
        sels[1] = approveFacet.revokeTokens.selector;
        _addFacetToModule(MODULE, address(approveFacet), sels);

        // -- Garden of the INDEX type; two-step upgrade installs the facet --
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE;
        _addGardenType(GARDEN_TYPE, modules);
        garden = _deployGarden(GARDEN_TYPE, diamondOwner);

        vm.startPrank(diamondOwner);
        (, bytes32 hashData) = IUpgrade(garden).upgradeDetails();
        IUpgrade(garden).upgrade(hashData);
        vm.stopPrank();

        tokenA = new MockERC20("TokenA", "TKNA", 18);
        tokenB = new MockERC20("TokenB", "TKNB", 18);
    }

    function _twoTokens() internal view returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
    }

    function _singleToken(address token) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = token;
    }

    function test_owner_approvesTokensToSpender() public {
        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);

        assertEq(IERC20(tokenA).allowance(garden, spender), type(uint256).max, "tokenA allowance");
        assertEq(IERC20(tokenB).allowance(garden, spender), type(uint256).max, "tokenB allowance");
    }

    function test_approveTokens_initialisesStorageLayoutVersion() public {
        bytes32 slot = LibStorageSlot.deriveStorageSlot(type(ApproveStorage).name);
        assertEq(uint256(vm.load(garden, slot)), 0, "version must be uninitialised before first grant");

        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_singleToken(address(tokenA)), spender);

        assertEq(
            uint256(vm.load(garden, slot)),
            ApproveStorage.STORAGE_LAYOUT_VERSION,
            "version must be initialised on first grant"
        );
    }

    function test_approveTokens_isIdempotent() public {
        vm.startPrank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);
        // Re-running must not revert on a non-zero-to-non-zero allowance.
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);
        vm.stopPrank();

        assertEq(IERC20(tokenA).allowance(garden, spender), type(uint256).max);
        assertEq(IERC20(tokenB).allowance(garden, spender), type(uint256).max);
    }

    function test_nonOwner_reverts() public {
        vm.expectRevert(abi.encodeWithSignature("Garden_UnauthorizedCaller()"));
        vm.prank(address(0xBEEF));
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);
    }

    function test_approveTokens_revertsOnZeroSpender() public {
        vm.expectRevert(abi.encodeWithSignature("ApproveFacet_ZeroSpender()"));
        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), address(0));
    }

    function test_approveTokens_revertsOnZeroToken() public {
        address[] memory tokens = _twoTokens();
        tokens[1] = address(0);

        vm.expectRevert(abi.encodeWithSignature("ApproveFacet_ZeroToken()"));
        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(tokens, spender);
    }

    // ── External audit H01: pre-session allowances to arbitrary spenders were a fee-free
    //    exit rail — spending is now restricted to the canonical rebalancer ──

    function test_approveTokens_revertsOnNonCanonicalSpender() public {
        address attacker = address(0xdead);
        vm.expectRevert(
            abi.encodeWithSignature("ApproveFacet_SpenderNotCanonicalRebalancer(address,address)", attacker, spender)
        );
        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), attacker);
    }

    function test_approveTokens_followsCanonicalRotation() public {
        // DAO rotates the canonical rebalancer: the old spender loses the rail instantly,
        // the new one is grantable — the migration path for a rebalancer redeployment
        address newRebalancer = address(0xC0DE);
        registry.setCanonicalRebalancer(newRebalancer);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ApproveFacet_SpenderNotCanonicalRebalancer(address,address)", spender, newRebalancer
            )
        );
        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);

        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), newRebalancer);
        assertEq(IERC20(tokenA).allowance(garden, newRebalancer), type(uint256).max);
    }

    // ── C02: explicit revocation and ownership-transfer cleanup ──

    function test_revokeTokens_clearsAllowance() public {
        vm.startPrank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);
        IApproveTokens(garden).revokeTokens(_twoTokens(), spender);
        vm.stopPrank();

        assertEq(IERC20(tokenA).allowance(garden, spender), 0, "tokenA allowance");
        assertEq(IERC20(tokenB).allowance(garden, spender), 0, "tokenB allowance");
    }

    function test_revokeTokens_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSignature("Garden_UnauthorizedCaller()"));
        vm.prank(address(0xBEEF));
        IApproveTokens(garden).revokeTokens(_twoTokens(), spender);
    }

    function test_revokeTokens_revertsOnZeroSpender() public {
        vm.expectRevert(abi.encodeWithSignature("ApproveFacet_ZeroSpender()"));
        vm.prank(diamondOwner);
        IApproveTokens(garden).revokeTokens(_twoTokens(), address(0));
    }

    function test_revokeTokens_revertsOnZeroToken() public {
        address[] memory tokens = _twoTokens();
        tokens[1] = address(0);

        vm.expectRevert(abi.encodeWithSignature("ApproveFacet_ZeroToken()"));
        vm.prank(diamondOwner);
        IApproveTokens(garden).revokeTokens(tokens, spender);
    }

    function test_revokeTokens_clearsLegacyArbitrarySpender() public {
        // Simulate an allowance granted by an older facet (never recorded in ApproveStorage)
        vm.prank(garden);
        IERC20(tokenA).approve(attacker, type(uint256).max);
        assertEq(IERC20(tokenA).allowance(garden, attacker), type(uint256).max, "legacy allowance");

        vm.prank(diamondOwner);
        IApproveTokens(garden).revokeTokens(_singleToken(address(tokenA)), attacker);

        assertEq(IERC20(tokenA).allowance(garden, attacker), 0, "legacy allowance cleared");
    }

    function test_transferOwnership_clearsTrackedApprovals() public {
        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);
        assertEq(IERC20(tokenA).allowance(garden, spender), type(uint256).max);

        vm.prank(diamondOwner);
        IERC173(garden).transferOwnership(bob);

        assertEq(IERC173(garden).owner(), bob, "new owner");
        assertEq(IERC20(tokenA).allowance(garden, spender), 0, "tokenA allowance cleared");
        assertEq(IERC20(tokenB).allowance(garden, spender), 0, "tokenB allowance cleared");

        // The new owner must re-approve the canonical rebalancer after the handover
        vm.prank(bob);
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);
        assertEq(IERC20(tokenA).allowance(garden, spender), type(uint256).max, "bob re-approved");
    }

    function test_formerOwnerAllowanceCannotPullAfterTransfer() public {
        tokenA.mint(garden, 100e18);

        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_singleToken(address(tokenA)), spender);

        vm.prank(diamondOwner);
        IERC173(garden).transferOwnership(bob);
        assertEq(IERC20(tokenA).allowance(garden, spender), 0, "allowance cleared");

        // The old canonical spender can no longer move garden balances
        vm.prank(spender);
        vm.expectRevert();
        IERC20(tokenA).transferFrom(garden, spender, 1);
        assertEq(tokenA.balanceOf(garden), 100e18, "garden balance untouched");
    }
}
