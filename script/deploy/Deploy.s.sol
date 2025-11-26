//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { DiamondCutFacet } from "src/diamond/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/diamond/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

contract Deploy is BaseScript {
    FacetRegistry internal registryImpl;
    TransparentUpgradeableProxy internal registryProxy;

    PoolRegistry internal poolRegistryImpl;
    TransparentUpgradeableProxy internal poolRegistryProxy;

    GardenFactory internal factoryImpl;
    TransparentUpgradeableProxy internal factoryProxy;

    ProtocolStatus internal protocolStatus;

    function run() public broadcaster {
        setUp();

        // --- Deploy FacetRegistry implementation & transparent proxy ---
        registryImpl = new FacetRegistry{ salt: salt }();

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

        bytes memory initRegistry =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, deployer, baseFacets, baseFacetFunctionSelectors);
        registryProxy = new TransparentUpgradeableProxy{ salt: salt }(address(registryImpl), deployer, initRegistry);

        console2.log("FacetRegistry proxy deployed at:", address(registryProxy));
        console2.log("FacetRegistry implementation at:", address(registryImpl));

        // --- Deploy PoolRegistry implementation & transparent proxy ---
        poolRegistryImpl = new PoolRegistry{ salt: salt }();

        bytes memory initPoolRegistry = abi.encodeWithSelector(PoolRegistry.initialize.selector, deployer);
        poolRegistryProxy =
            new TransparentUpgradeableProxy{ salt: salt }(address(poolRegistryImpl), deployer, initPoolRegistry);
        console2.log("PoolRegistry proxy deployed at:", address(poolRegistryProxy));
        console2.log("PoolRegistry implementation at:", address(poolRegistryImpl));

        // --- Deploy ProtocolStatus (no proxy) ---
        IProtocolStatus.SecurityCouncilMember[] memory securityCouncilMembers =
            new IProtocolStatus.SecurityCouncilMember[](1);
        address sec = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        securityCouncilMembers[0] = IProtocolStatus.SecurityCouncilMember({ memberAddress: sec, name: "Chintan" });
        protocolStatus = new ProtocolStatus{ salt: salt }(securityCouncilMembers, deployer);
        console2.log("ProtocolStatus deployed at:", address(protocolStatus));
        ProtocolStatus(protocolStatus).activateProtocol();
        console2.log("ProtocolStatus activated");

        factoryImpl = new GardenFactory{ salt: salt }();

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector, deployer, address(registryProxy), address(protocolStatus)
        );

        factoryProxy = new TransparentUpgradeableProxy{ salt: salt }(address(factoryImpl), deployer, factoryInitData);

        console2.log("GardenFactory proxy deployed at:", address(factoryProxy));
        console2.log("GardenFactory implementation at:", address(factoryImpl));
    }
}
