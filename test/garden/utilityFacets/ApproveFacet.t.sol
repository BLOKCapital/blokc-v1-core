// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase } from "../../base/DiamondTestBase.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ApproveFacet } from "src/garden/facets/utilityFacets/ApproveFacet.sol";
import { MockERC20 } from "../../mock/MockERC20.sol";

interface IApproveTokens {
    function approveTokens(address[] calldata tokens, address spender) external;
}

/**
 * @title ApproveFacetTest
 * @notice Exercises the production install path for ApproveFacet: the facet is added to
 *         a module in the real FacetRegistry, the garden is deployed, and the facet is
 *         installed through the two-step upgrade (upgradeDetails -> upgrade) — the same
 *         sequence DeployApproveFacet.s.sol / UpgradeGardens.s.sol run on mainnet.
 *         Asserts the garden (diamond) grants max allowance to the Rebalancer and that
 *         access control holds.
 */
contract ApproveFacetTest is DiamondTestBase {
    bytes32 internal constant MODULE = keccak256("APPROVE");
    bytes32 internal constant GARDEN_TYPE = keccak256("INDEX");

    address internal diamondOwner = address(0xA11CE);
    address internal spender = address(0xB0B);
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    address internal garden;

    function setUp() public override {
        super.setUp();

        // -- Module holding the ApproveFacet (mirrors the upgradeModule step) --
        ApproveFacet approveFacet = new ApproveFacet();
        _registerModule(MODULE);

        bytes4[] memory sels = new bytes4[](1);
        sels[0] = approveFacet.approveTokens.selector;
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

    function test_owner_approvesTokensToSpender() public {
        vm.prank(diamondOwner);
        IApproveTokens(garden).approveTokens(_twoTokens(), spender);

        assertEq(IERC20(tokenA).allowance(garden, spender), type(uint256).max, "tokenA allowance");
        assertEq(IERC20(tokenB).allowance(garden, spender), type(uint256).max, "tokenB allowance");
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
}
