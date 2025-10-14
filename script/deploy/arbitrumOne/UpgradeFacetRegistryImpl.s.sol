// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

// import { BaseScript } from "../Base.s.sol";
// import { console } from "forge-std/console.sol";
// import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
// import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
// import { ITransparentUpgradeableProxy } from
// "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// contract UpgradeFacetRegistryImpl is BaseScript {
//     function run() external broadcaster {
//         //         // address proxyAdminAddress = 0xc4a18abc75965da24B246dE2cf21f0eE5E89aD01;
//         //         // address facetRegistryProxyAddress = 0xC81871AE98503fd047A1B49A9813007eDfdD2B61;
//         bytes memory initRegistry = abi.encodeWithSelector(FacetRegistry.initialize.selector, deployer);
//         console.logBytes(initRegistry);

//         //         // address proxyAdminOwner = ProxyAdmin(proxyAdminAddress).owner();

//         //         // console.log("ProxyAdmin owner:    ", proxyAdminOwner);
//         //         address newFacetRegistryImplAddress = address(new FacetRegistry());
//         //         console.log("new implementation address deployed at: ", newFacetRegistryImplAddress);

//         //         // ProxyAdmin(proxyAdminAddress).upgradeAndCall(
//         //         //     ITransparentUpgradeableProxy(facetRegistryProxyAddress), newFacetRegistryImplAddress,
//         // initRegistry
//         //         // );
//     }
// }
