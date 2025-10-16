// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { console } from "forge-std/console.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { FacetRegistryReceiver } from "src/ccip/Spoke/FacetRegistryReceiver.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BaseDeployment is BaseScript {
    address internal registryDeployer;

    // Base CCIP Router address
    address constant BASE_CCIP_ROUTER = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;

    function run() public broadcaster {
        setUp();
        registryDeployer = msg.sender;

        console.log("Deploying to Base Chain...");
        console.log("registryDeployer:", registryDeployer);
        FacetRegistry facetRegistryImpl = new FacetRegistry();
        console.log("FacetRegistry Implementation:", address(facetRegistryImpl));

        bytes memory facetRegistryInitData = abi.encodeWithSelector(
            FacetRegistry.initialize.selector,
            registryDeployer // msg.sender is the owner for now
        );

        ERC1967Proxy facetRegistryProxy = new ERC1967Proxy(address(facetRegistryImpl), facetRegistryInitData);
        console.log("FacetRegistry Proxy:", address(facetRegistryProxy));
        PoolRegistry poolRegistryImpl = new PoolRegistry();
        console.log("PoolRegistry Implementation:", address(poolRegistryImpl));

        bytes memory poolRegistryInitData = abi.encodeWithSelector(
            PoolRegistry.initialize.selector,
            registryDeployer // its the owner for now
        );

        ERC1967Proxy poolRegistryProxy = new ERC1967Proxy(address(poolRegistryImpl), poolRegistryInitData);
        console.log("PoolRegistry Proxy:", address(poolRegistryProxy));

        FacetRegistryReceiver facetRegistryReceiver = new FacetRegistryReceiver();
        console.log("FacetRegistryReceiver:", address(facetRegistryReceiver));

        facetRegistryReceiver.setFacetRegistry(address(facetRegistryProxy));
        facetRegistryReceiver.setPoolRegistry(address(poolRegistryProxy));

        console.log("=== Base Chain Deployment Complete ===");
        console.log("FacetRegistry Proxy:", address(facetRegistryProxy));
        console.log("PoolRegistry Proxy:", address(poolRegistryProxy));
        console.log("FacetRegistryReceiver:", address(facetRegistryReceiver));
        console.log("CCIP Router Used:", BASE_CCIP_ROUTER);
        console.log("Owner (all contracts):", registryDeployer);
    }
}
