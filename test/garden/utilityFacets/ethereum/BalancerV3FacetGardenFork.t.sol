// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Garden } from "src/garden/Garden.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { SwapInstruction } from "src/interfaces/ISwapInstruction.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { DiamondCutFacet } from "src/garden/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/garden/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/garden/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IBalancerV3 } from "src/garden/facets/utilityFacets/ethereum/balancerV3/IBalancerV3.sol";
import { BalancerV3Facet } from "src/garden/facets/utilityFacets/ethereum/balancerV3/BalancerV3Facet.sol";
import { Garden_UnauthorizedCaller } from "src/garden/facets/Facet.sol";

contract BalancerV3FacetGardenForkTest is Test {
    address internal constant POOL_REGISTRY = 0xDe6338E4dd7B0A2076e8CE63cC0443dC6cE7f0B6;
    address internal constant BALANCER_POOL = 0x111ce2A60C30f6058A57D0dBAe1A39A42D998826;
    address internal constant TOKEN_IN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant TOKEN_OUT = 0x4ba01f22827018b4772CD326C7627FB4956A7C00;

    bytes32 internal constant MODULE_DEX = keccak256("DEX");
    bytes32 internal constant GARDEN_TYPE = keccak256("BALANCER_FORK_TEST");
    bytes32 internal constant BALANCER_V3 = keccak256("BALANCER_V3");

    FacetRegistry internal registry;
    ProtocolStatus internal protocolStatus;
    BalancerV3Facet internal balancerFacet;
    Garden internal garden;

    function setUp() public {
        string memory rpcUrl = _mainnetRpcUrl();
        vm.skip(bytes(rpcUrl).length == 0, "MAINNET_RPC_URL or API_KEY_ALCHEMY not set");

        _selectMainnetFork(rpcUrl);

        _installPoolRegistry();
        _registerBalancerDex();
        _registerBalancerPool();

        registry = _deployFacetRegistry();
        protocolStatus = _deployProtocolStatus();
        balancerFacet = new BalancerV3Facet();

        registry.registerModule(MODULE_DEX);
        registry.upgradeModule(MODULE_DEX, _balancerFacetCuts(address(balancerFacet)));

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_DEX;
        registry.addGardenType(GARDEN_TYPE, modules);

        garden = new Garden(
            registry.getBaseFacetCuts(), address(this), address(registry), address(protocolStatus), GARDEN_TYPE
        );
    }

    function testForkUpgradeAddsBalancerFacetAndExecutesExactInputSwap() public {
        assertEq(IDiamondLoupe(address(garden)).facetAddress(IBalancerV3.balancerV3Swap.selector), address(0));

        (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData) = IUpgrade(address(garden)).upgradeDetails();
        assertEq(facetCuts.length, 1);
        IUpgrade(address(garden)).upgrade(hashData);

        assertEq(
            IDiamondLoupe(address(garden)).facetAddress(IBalancerV3.balancerV3Swap.selector), address(balancerFacet)
        );
        assertEq(IUpgrade(address(garden)).getModuleVersion(MODULE_DEX), registry.getModuleVersion(MODULE_DEX));

        uint256 amountIn = 1_000_000;
        deal(TOKEN_IN, address(garden), amountIn);

        uint256 tokenInBalanceBefore = IERC20(TOKEN_IN).balanceOf(address(garden));
        uint256 tokenOutBalanceBefore = IERC20(TOKEN_OUT).balanceOf(address(garden));

        IBalancerV3(address(garden)).balancerV3Swap(_singleHopInstruction(amountIn, 1, false));

        uint256 tokenInSpent = tokenInBalanceBefore - IERC20(TOKEN_IN).balanceOf(address(garden));
        uint256 tokenOutReceived = IERC20(TOKEN_OUT).balanceOf(address(garden)) - tokenOutBalanceBefore;

        assertEq(tokenInSpent, amountIn);
        assertGt(tokenOutReceived, 0);
    }

    function testForkExactOutputSwapThroughGardenUsesLiveBalancer() public {
        _upgradeGarden();

        uint256 amountInMaximum = 1_000_000;
        uint256 amountOut = 0.01 ether;
        deal(TOKEN_IN, address(garden), amountInMaximum);

        uint256 tokenInBalanceBefore = IERC20(TOKEN_IN).balanceOf(address(garden));
        uint256 tokenOutBalanceBefore = IERC20(TOKEN_OUT).balanceOf(address(garden));

        IBalancerV3(address(garden)).balancerV3Swap(_singleHopInstruction(amountInMaximum, amountOut, true));

        uint256 tokenInSpent = tokenInBalanceBefore - IERC20(TOKEN_IN).balanceOf(address(garden));
        uint256 tokenOutReceived = IERC20(TOKEN_OUT).balanceOf(address(garden)) - tokenOutBalanceBefore;

        assertEq(tokenOutReceived, amountOut);
        assertGt(tokenInSpent, 0);
        assertLe(tokenInSpent, amountInMaximum);
    }

    function testForkNonOwnerCannotCallBalancerFacetThroughGarden() public {
        _upgradeGarden();

        vm.prank(makeAddr("nonOwner"));
        vm.expectRevert(Garden_UnauthorizedCaller.selector);
        IBalancerV3(address(garden)).balancerV3Swap(_singleHopInstruction(1_000_000, 1, false));
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    function _singleHopInstruction(
        uint256 amountIn,
        uint256 amountOut,
        bool exactOutput
    )
        internal
        pure
        returns (SwapInstruction memory instruction)
    {
        address[] memory tokens = new address[](2);
        tokens[0] = TOKEN_IN;
        tokens[1] = TOKEN_OUT;

        address[] memory pools = new address[](1);
        pools[0] = BALANCER_POOL;

        instruction = SwapInstruction({
            amountIn: amountIn, amountOut: amountOut, tokens: tokens, pools: pools, exactOutput: exactOutput
        });
    }

    function _upgradeGarden() internal {
        (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData) = IUpgrade(address(garden)).upgradeDetails();
        assertEq(facetCuts.length, 1);
        IUpgrade(address(garden)).upgrade(hashData);
    }

    function _installPoolRegistry() internal {
        LiquidityPoolRegistry registryImplementation = new LiquidityPoolRegistry(address(this));

        vm.etch(POOL_REGISTRY, address(registryImplementation).code);
        vm.store(POOL_REGISTRY, bytes32(0), bytes32(uint256(uint160(address(this)))));

        assertEq(LiquidityPoolRegistry(POOL_REGISTRY).owner(), address(this));
    }

    function _registerBalancerDex() internal {
        LiquidityPoolRegistry(POOL_REGISTRY)
            .registerDex(BALANCER_V3, IBalancerV3.balancerV3Swap.selector, IBalancerV3.balancerV3Quote.selector);
    }

    function _registerBalancerPool() internal {
        LiquidityPoolRegistry(POOL_REGISTRY)
            .addPool(
                ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: BALANCER_POOL,
                tokenA: TOKEN_IN,
                tokenB: TOKEN_OUT,
                dexId: BALANCER_V3,
                pairName: "msUSD/USDC"
            })
            );
    }

    function _deployFacetRegistry() internal returns (FacetRegistry deployedRegistry) {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        UpgradeFacet upgradeFacet = new UpgradeFacet();

        address[4] memory baseFacets =
            [address(cutFacet), address(loupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseFacetSelectors = new bytes4[][](4);
        baseFacetSelectors[0] = new bytes4[](1);
        baseFacetSelectors[0][0] = cutFacet.diamondCut.selector;

        baseFacetSelectors[1] = new bytes4[](5);
        baseFacetSelectors[1][0] = loupeFacet.facets.selector;
        baseFacetSelectors[1][1] = loupeFacet.facetFunctionSelectors.selector;
        baseFacetSelectors[1][2] = loupeFacet.facetAddresses.selector;
        baseFacetSelectors[1][3] = loupeFacet.facetAddress.selector;
        baseFacetSelectors[1][4] = loupeFacet.supportsInterface.selector;

        baseFacetSelectors[2] = new bytes4[](2);
        baseFacetSelectors[2][0] = ownershipFacet.owner.selector;
        baseFacetSelectors[2][1] = ownershipFacet.transferOwnership.selector;

        baseFacetSelectors[3] = new bytes4[](3);
        baseFacetSelectors[3][0] = upgradeFacet.upgrade.selector;
        baseFacetSelectors[3][1] = upgradeFacet.upgradeDetails.selector;
        baseFacetSelectors[3][2] = upgradeFacet.getModuleVersion.selector;

        deployedRegistry = new FacetRegistry(address(this), baseFacets, baseFacetSelectors);
    }

    function _deployProtocolStatus() internal returns (ProtocolStatus deployedProtocolStatus) {
        bytes32[] memory emptyNamehashes = new bytes32[](0);
        string[] memory emptyNames = new string[](0);
        uint256[] memory emptyExpiries = new uint256[](0);

        deployedProtocolStatus =
            new ProtocolStatus(address(this), makeAddr("ensRegistry"), emptyNamehashes, emptyNames, emptyExpiries);
        deployedProtocolStatus.activateProtocol();
    }

    function _balancerFacetCuts(address facetAddress) internal pure returns (IDiamondCut.FacetCut[] memory cuts) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IBalancerV3.balancerV3Swap.selector;
        selectors[1] = IBalancerV3.balancerV3Quote.selector;

        cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facetAddress, action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });
    }

    function _mainnetRpcUrl() internal view returns (string memory rpcUrl) {
        rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length != 0) return rpcUrl;

        string memory alchemyKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyKey).length != 0) {
            return string.concat("https://eth-mainnet.g.alchemy.com/v2/", alchemyKey);
        }

        return "";
    }

    function _selectMainnetFork(string memory rpcUrl) internal {
        uint256 forkBlock = vm.envOr("MAINNET_FORK_BLOCK", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(rpcUrl);
            return;
        }

        vm.createSelectFork(rpcUrl, forkBlock);
    }
}
