// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { ApproveFacet } from "src/garden/facets/utilityFacets/ApproveFacet.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

/**
 * @title DeployApproveFacet
 * @notice Adds the ApproveFacet to the INDEX module of the FacetRegistry (bumping the
 *         module version). The deployed gardens then pick it up through their normal
 *         two-step upgrade (upgradeDetails -> upgrade), after which the garden owner
 *         approves the CumulativeRebalancer to pull component tokens.
 *
 *         Env (all required):
 *         - FACET_REGISTRY_ADDRESS
 */
contract DeployApproveFacet is BaseScript {
    bytes32 constant MODULE_INDEX = keccak256("INDEX");

    function run() public broadcaster {
        setUp();

        IFacetRegistry registry = IFacetRegistry(vm.envAddress("FACET_REGISTRY_ADDRESS"));

        // =====================================================================
        // Deploy the facet and add it to the INDEX module
        // =====================================================================
        ApproveFacet approveFacet = new ApproveFacet();
        console2.log("ApproveFacet deployed at:", address(approveFacet));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = approveFacet.approveTokens.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(approveFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });

        registry.upgradeModule(MODULE_INDEX, cuts);
        console2.log("INDEX module upgraded with ApproveFacet (version bumped)");

        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Per garden: garden.upgradeDetails() -> garden.upgrade(hashData) to install the facet");
        console2.log("2. Per garden (owner): garden.approveTokens([<components + USDC>], <rebalancer-address>)");
    }
}
