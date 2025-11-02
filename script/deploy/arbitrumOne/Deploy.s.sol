// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

import { BaseScript } from "../../Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

import { DiamondCutFacet } from "src/diamond/facets/baseFacets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/diamond/facets/baseFacets/OwnershipFacet.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/UpgradeFacet.sol";
import { WithdrawFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/WithdrawFacet.sol";
import { UniswapFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/UniswapFacet.sol";
import { AaveFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/AaveFacet.sol";
import { CCTPFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/CCTPFacet.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

import { IERC165 } from "src/interfaces/IERC165.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract Deploy is BaseScript {
    ProxyAdmin internal registryProxyAdmin;
    FacetRegistry internal registryImpl;
    TransparentUpgradeableProxy internal registryProxy;

    ProxyAdmin internal poolRegistryProxyAdmin;
    PoolRegistry internal poolRegistryImpl;
    TransparentUpgradeableProxy internal poolRegistryProxy;

    ProxyAdmin internal factoryProxyAdmin;
    GardenFactory internal factoryImpl;
    TransparentUpgradeableProxy internal factoryProxy;

    ProtocolStatus internal protocolStatus;

    function run() public broadcaster {
        setUp();

        // --- Deploy FacetRegistry implementation & transparent proxy ---
        registryImpl = new FacetRegistry{ salt: salt }();

        // Deploy ProxyAdmin (separate for each proxy, you can use the same if you want)
        registryProxyAdmin = new ProxyAdmin{ salt: keccak256(abi.encodePacked(salt, "REGISTRY")) }(deployer);

        // Register default facets
        DiamondCutFacet cutFacet = new DiamondCutFacet{ salt: salt }();
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = cutFacet.diamondCut.selector;

        console2.log("DiamondCutFacet deployed at:", address(cutFacet));

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet{ salt: salt }();
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = loupeFacet.facets.selector;
        loupeSelectors[1] = loupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = loupeFacet.facetAddresses.selector;
        loupeSelectors[3] = loupeFacet.facetAddress.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;

        console2.log("DiamondLoupeFacet deployed at:", address(loupeFacet));

        OwnershipFacet ownershipFacet = new OwnershipFacet{ salt: salt }();
        bytes4[] memory ownableSelectors = new bytes4[](2);
        ownableSelectors[0] = ownershipFacet.owner.selector;
        ownableSelectors[1] = ownershipFacet.transferOwnership.selector;

        console2.log("ownershipFacet deployed at:", address(ownershipFacet));

        UpgradeFacet upgradeFacet = new UpgradeFacet{ salt: salt }();
        bytes4[] memory upgradeSelectors = new bytes4[](3);

        upgradeSelectors[0] = upgradeFacet.upgrade.selector;
        upgradeSelectors[1] = upgradeFacet.getCurrentVersion.selector;
        upgradeSelectors[2] = upgradeFacet.upgradeDetails.selector;
        console2.log("UpgradeFacet deployed at:", address(upgradeFacet));

        address[4] memory baseFacets =
            [address(cutFacet), address(loupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseFacetFunctionSelectors = new bytes4[][](4);
        baseFacetFunctionSelectors[0] = cutSelectors;
        baseFacetFunctionSelectors[1] = loupeSelectors;
        baseFacetFunctionSelectors[2] = ownableSelectors;
        baseFacetFunctionSelectors[3] = upgradeSelectors;

        // Use deployer (EOA set in BaseScript) as the owner for the registry initialization
        bytes memory initRegistry =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, deployer, baseFacets, baseFacetFunctionSelectors);
        registryProxy = new TransparentUpgradeableProxy{ salt: salt }(
            address(registryImpl), address(registryProxyAdmin), initRegistry
        );

        console2.log("FacetRegistry proxy deployed at:", address(registryProxy));
        console2.log("FacetRegistry implementation at:", address(registryImpl));
        console2.log("FacetRegistry ProxyAdmin deployed at:", address(registryProxyAdmin));

        // --- Deploy PoolRegistry implementation & transparent proxy ---
        poolRegistryImpl = new PoolRegistry{ salt: salt }();

        poolRegistryProxyAdmin = new ProxyAdmin{ salt: keccak256(abi.encodePacked(salt, "POOL")) }(deployer);

        // Use deployer (EOA set in BaseScript) as the owner for the pool registry initialization
        bytes memory initPoolRegistry = abi.encodeWithSelector(PoolRegistry.initialize.selector, deployer);
        poolRegistryProxy = new TransparentUpgradeableProxy{ salt: salt }(
            address(poolRegistryImpl), address(poolRegistryProxyAdmin), initPoolRegistry
        );
        console2.log("PoolRegistry proxy deployed at:", address(poolRegistryProxy));
        console2.log("PoolRegistry implementation at:", address(poolRegistryImpl));
        console2.log("PoolRegistry ProxyAdmin deployed at:", address(poolRegistryProxyAdmin));

        // --- Deploy ProtocolStatus (no proxy) ---
        IProtocolStatus.SecurityCouncilMember[] memory securityCouncilMembers =
            new IProtocolStatus.SecurityCouncilMember[](1);
        address sec = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        securityCouncilMembers[0] = IProtocolStatus.SecurityCouncilMember({ memberAddress: sec, name: "name" });
        protocolStatus = new ProtocolStatus{ salt: salt }(securityCouncilMembers);
        console2.log("ProtocolStatus deployed at:", address(protocolStatus));

        // --- Deploy GardenFactory implementation & transparent proxy ---
        factoryImpl = new GardenFactory{ salt: salt }();

        // Deploy ProxyAdmin (separate for each proxy, you can use the same if you want)
        factoryProxyAdmin = new ProxyAdmin{ salt: keccak256(abi.encodePacked(salt, "FACTORY")) }(deployer);

        // Initialize GardenFactory with deployer as owner
        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector,
            deployer,
            address(protocolStatus),
            address(registryProxy),
            address(poolRegistryProxy)
        );

        factoryProxy = new TransparentUpgradeableProxy{ salt: salt }(
            address(factoryImpl), address(factoryProxyAdmin), factoryInitData
        );

        console2.log("GardenFactory proxy deployed at:", address(factoryProxy));
        console2.log("GardenFactory implementation at:", address(factoryImpl));
        console2.log("GardenFactory ProxyAdmin deployed at:", address(factoryProxyAdmin));

        // --- Transfer ProxyAdmin ownership to the deployer (or multisig) ---
        registryProxyAdmin.transferOwnership(deployer);
        poolRegistryProxyAdmin.transferOwnership(deployer);
        factoryProxyAdmin.transferOwnership(deployer);

        WithdrawFacet withdrawFacet = new WithdrawFacet();
        bytes4[] memory withdrawSelectors = new bytes4[](1);
        withdrawSelectors[0] = withdrawFacet.withdrawUSDC.selector;

        FacetRegistry(address(registryProxy)).addFunctions(address(withdrawFacet), withdrawSelectors);
        console2.log("WithdrawFacet deployed at:", address(withdrawFacet));

        UniswapFacet uniswapFacet = new UniswapFacet();
        bytes4[] memory uniswapFacetSelectors = new bytes4[](4);
        uniswapFacetSelectors[0] = UniswapFacet.swapExactInputSingleHop.selector;
        uniswapFacetSelectors[1] = UniswapFacet.swapExactInputMultiHop.selector;
        uniswapFacetSelectors[2] = UniswapFacet.getSqrtTwapX96.selector;
        uniswapFacetSelectors[3] = UniswapFacet.getCombinedTwapX96.selector;

        FacetRegistry(address(registryProxy)).addFunctions(address(uniswapFacet), uniswapFacetSelectors);
        console2.log("UniswapFacet deployed at:", address(uniswapFacet));

        AaveFacet aaveFacet = new AaveFacet();
        bytes4[] memory aaveFacetSelectors = new bytes4[](3);
        aaveFacetSelectors[0] = AaveFacet.aaveReserveData.selector;
        aaveFacetSelectors[1] = AaveFacet.lendToAave.selector;
        aaveFacetSelectors[2] = AaveFacet.withdrawFromAave.selector;

        FacetRegistry(address(registryProxy)).addFunctions(address(aaveFacet), aaveFacetSelectors);
        console2.log("AaveFacet deployed at:", address(aaveFacet));
    }
}
