// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { DiamondTestBase } from "test/diamond/DiamondTestBase.sol";
import { UniswapV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import { AaveV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";
import { WithdrawFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import { CCTPFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/cctp/CCTPFacet.sol";
import { IUniswapV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { IAaveV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/IAaveV3.sol";
import { IWithdraw } from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/IWithdraw.sol";
import { ICCTP } from "src/diamond/facets/utilityFacets/arbitrumOne/cctp/ICCTP.sol";
import { IUpgrade } from "src/diamond/facets/baseFacets/upgrade/IUpgrade.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Base test contract for Arbitrum One utility facets
/// @notice Provides common setup and helper functions for utility facet tests
abstract contract UtilityFacetsTestBase is DiamondTestBase {
    // Utility Facets
    UniswapV3Facet internal uniswapV3Facet;
    AaveV3Facet internal aaveV3Facet;
    WithdrawFacet internal withdrawFacet;
    CCTPFacet internal cctpFacet;

    // PoolRegistry
    PoolRegistry internal poolRegistry;
    PoolRegistry internal poolRegistryImpl;
    ProxyAdmin internal poolRegistryProxyAdmin;
    TransparentUpgradeableProxy internal poolRegistryProxy;

    // Mock tokens
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    MockERC20 internal usdc;

    // Constants
    address internal constant ARBITRUM_UNISWAP_ROUTER = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal constant ARBITRUM_UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal constant ARBITRUM_AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address internal constant ARBITRUM_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant ARBITRUM_CCTP_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address internal constant ARBITRUM_CCTP_MESSAGE_TRANSMITTER = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;

    // Hardcoded addresses that need forwarding
    address internal constant HARDCODED_POOL_REGISTRY_ADDRESS = 0x0000000000000000000000000000000000000000;

    function setUp() public virtual override {
        super.setUp();

        // Deploy utility facets
        uniswapV3Facet = new UniswapV3Facet();
        aaveV3Facet = new AaveV3Facet();
        withdrawFacet = new WithdrawFacet();
        cctpFacet = new CCTPFacet();

        // Deploy mock tokens
        tokenA = new MockERC20("Token A", "TKNA", 18);
        tokenB = new MockERC20("Token B", "TKNB", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy PoolRegistry
        _deployPoolRegistry();

        // Mock hardcoded PoolRegistry address if needed
        _setupHardcodedAddresses();
    }

    function _deployPoolRegistry() internal {
        poolRegistryImpl = new PoolRegistry();
        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner);

        poolRegistryProxy = new TransparentUpgradeableProxy(address(poolRegistryImpl), owner, initData);

        poolRegistry = PoolRegistry(payable(address(poolRegistryProxy)));

        // Get ProxyAdmin reference
        bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address admin = address(uint160(uint256(vm.load(address(poolRegistryProxy), ADMIN_SLOT))));
        poolRegistryProxyAdmin = ProxyAdmin(admin);
    }

    function _setupHardcodedAddresses() internal {
        // If PoolRegistry address is hardcoded as zero, we need to mock it
        // For now, we'll register pools directly in the PoolRegistry we deployed
        // and handle forwarding in the actual facet tests if needed
    }

    /// @notice Helper to add utility facets to the diamond
    function _addUtilityFacetsToDiamond() internal {
        // Collect selectors for each utility facet
        bytes4[] memory uniswapSelectors = new bytes4[](4);
        uniswapSelectors[0] = uniswapV3Facet.swapExactInputSingleHop.selector;
        uniswapSelectors[1] = uniswapV3Facet.swapExactInputMultiHop.selector;
        uniswapSelectors[2] = uniswapV3Facet.getSqrtTwapX96.selector;
        uniswapSelectors[3] = uniswapV3Facet.getCombinedTwapX96.selector;

        bytes4[] memory aaveSelectors = new bytes4[](3);
        aaveSelectors[0] = aaveV3Facet.lend.selector;
        aaveSelectors[1] = aaveV3Facet.withdraw.selector;
        aaveSelectors[2] = aaveV3Facet.getReserveData.selector;

        bytes4[] memory withdrawSelectors = new bytes4[](1);
        withdrawSelectors[0] = withdrawFacet.withdrawUSDC.selector;

        bytes4[] memory cctpSelectors = new bytes4[](2);
        cctpSelectors[0] = cctpFacet.sendUSDC.selector;
        cctpSelectors[1] = cctpFacet.redeemUSDC.selector;

        // Add facets to registry
        vm.startPrank(owner);
        facetRegistry.addFunctions(address(uniswapV3Facet), uniswapSelectors);
        facetRegistry.addFunctions(address(aaveV3Facet), aaveSelectors);
        facetRegistry.addFunctions(address(withdrawFacet), withdrawSelectors);
        facetRegistry.addFunctions(address(cctpFacet), cctpSelectors);
        vm.stopPrank();

        // Upgrade diamond to include new facets
        // Get upgrade details first to get the hash
        (,,, bytes32 hashData) = IUpgrade(address(diamond)).upgradeDetails();
        vm.prank(owner);
        IUpgrade(address(diamond)).upgrade(hashData);

        // Verify facets are added
        address[] memory facets = IDiamondLoupe(address(diamond)).facetAddresses();
        bool foundUniswap = false;
        bool foundAave = false;
        bool foundWithdraw = false;
        bool foundCCTP = false;

        for (uint256 i = 0; i < facets.length; i++) {
            if (facets[i] == address(uniswapV3Facet)) foundUniswap = true;
            if (facets[i] == address(aaveV3Facet)) foundAave = true;
            if (facets[i] == address(withdrawFacet)) foundWithdraw = true;
            if (facets[i] == address(cctpFacet)) foundCCTP = true;
        }

        require(foundUniswap, "UniswapV3Facet not added");
        require(foundAave, "AaveV3Facet not added");
        require(foundWithdraw, "WithdrawFacet not added");
        require(foundCCTP, "CCTPFacet not added");
    }

    /// @notice Helper to get UniswapV3Facet interface from diamond
    function getUniswapV3Facet() internal view returns (IUniswapV3) {
        return IUniswapV3(address(diamond));
    }

    /// @notice Helper to get AaveV3Facet interface from diamond
    function getAaveV3Facet() internal view returns (IAaveV3) {
        return IAaveV3(address(diamond));
    }

    /// @notice Helper to get WithdrawFacet interface from diamond
    function getWithdrawFacet() internal view returns (IWithdraw) {
        return IWithdraw(address(diamond));
    }

    /// @notice Helper to get CCTPFacet interface from diamond
    function getCCTPFacet() internal view returns (ICCTP) {
        return ICCTP(address(diamond));
    }

    /// @notice Helper to register a pool in PoolRegistry
    function _registerPool(address poolAddress, string memory pairName) internal {
        vm.prank(owner);
        poolRegistry.addPool(poolAddress, bytes32("UNISWAPV3"), pairName);
    }

    /// @notice Helper to mint tokens to diamond
    function _mintTokensToDiamond(address token, uint256 amount) internal {
        MockERC20(token).mint(address(diamond), amount);
    }

    /// @notice Helper to mint tokens to user
    function _mintTokensToUser(address token, address user, uint256 amount) internal {
        MockERC20(token).mint(user, amount);
    }
}
