// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title UpgradeGardensFees
 * @notice Live-rollout script for the fee structure on already-deployed gardens:
 *           1. Registry-side (run once, FACET_REGISTRY owner): deploy the new IndexFacet,
 *              Replace its 8 existing selectors + Add the 2 new ones in the INDEX module
 *              (bumps the module version), deploy + register the FeeFacet as a new FEES module,
 *              and allow it on the INDEX_GARDEN type.
 *           2. Garden-side (per garden): pull pending module cuts via the two-step upgrade
 *              flow, then wire the fee registries via configureFeeModule — first-time
 *              configuration is allowed while connected.
 *
 *         Env:
 *           FACET_REGISTRY_ADDRESS      live FacetRegistry
 *           GARDEN_FACTORY_ADDRESS      live GardenFactory (for garden-type lookups)
 *           FEE_REGISTRY_ADDRESS        from DeployFeeRegistries
 *           TREASURY_REGISTRY_ADDRESS   from DeployFeeRegistries
 *           ONBOARDER_REGISTRY_ADDRESS  from DeployFeeRegistries
 *           GARDENS                     comma-separated garden addresses (no spaces)
 */
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";
import { FeeFacet } from "src/garden/facets/feeFacet/FeeFacet.sol";

contract UpgradeGardensFees is BaseScript {
    bytes32 constant MODULE_INDEX = keccak256("INDEX");
    bytes32 constant MODULE_FEES = keccak256("FEES");
    bytes32 constant INDEX_GARDEN = keccak256("INDEX");

    function run() public broadcaster {
        setUp();
        address facetRegistryAddress = vm.envAddress("FACET_REGISTRY_ADDRESS");
        address feeRegistry = vm.envAddress("FEE_REGISTRY_ADDRESS");
        address treasuryRegistry = vm.envAddress("TREASURY_REGISTRY_ADDRESS");
        address onboarderRegistry = vm.envAddress("ONBOARDER_REGISTRY_ADDRESS");
        IFacetRegistry registry = IFacetRegistry(facetRegistryAddress);

        // =====================================================================
        // 1. Registry-side: INDEX module upgrade (Replace 8 + Add 2)
        // =====================================================================
        IndexFacet indexFacet = new IndexFacet();

        // Existing 8 selectors — Replace keeps the same dispatch, now with fee-aware internals
        bytes4[] memory replacedSelectors = new bytes4[](8);
        replacedSelectors[0] = indexFacet.configureIndexModule.selector;
        replacedSelectors[1] = indexFacet.connectToIndex.selector;
        replacedSelectors[2] = indexFacet.disconnectFromIndex.selector;
        replacedSelectors[3] = indexFacet.rebalanceIntent.selector;
        replacedSelectors[4] = indexFacet.rebalance.selector;
        replacedSelectors[5] = indexFacet.isConnectedToIndex.selector;
        replacedSelectors[6] = indexFacet.getConnectedIndex.selector;
        replacedSelectors[7] = indexFacet.hasPendingIntent.selector;

        // New 2 selectors — Add (must not pre-exist)
        bytes4[] memory addedSelectors = new bytes4[](2);
        addedSelectors[0] = indexFacet.connectToIndexWithOnboarder.selector;
        addedSelectors[1] = indexFacet.unwindAndDisconnect.selector;

        IDiamondCut.FacetCut[] memory indexCuts = new IDiamondCut.FacetCut[](2);
        indexCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(indexFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: replacedSelectors
        });
        indexCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(indexFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: addedSelectors
        });

        registry.upgradeModule(MODULE_INDEX, indexCuts);
        console2.log("INDEX module upgraded (Replace 8 + Add 2), new IndexFacet at:", address(indexFacet));

        // =====================================================================
        // 2. Registry-side: FEES module (Add) + garden-type allowance
        // =====================================================================
        FeeFacet feeFacet = new FeeFacet();
        bytes4[] memory feeSelectors = new bytes4[](6);
        feeSelectors[0] = feeFacet.configureFeeModule.selector;
        feeSelectors[1] = feeFacet.depositUsdc.selector;
        feeSelectors[2] = feeFacet.depositComponent.selector;
        feeSelectors[3] = feeFacet.getFeeBasis.selector;
        feeSelectors[4] = feeFacet.getFeeRegistries.selector;
        feeSelectors[5] = feeFacet.getLastSettlement.selector;

        IDiamondCut.FacetCut[] memory feeCuts = new IDiamondCut.FacetCut[](1);
        feeCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(feeFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: feeSelectors
        });

        if (!registry.isModuleRegistered(MODULE_FEES)) {
            registry.registerModule(MODULE_FEES);
            console2.log("FEES module registered");
        }
        registry.upgradeModule(MODULE_FEES, feeCuts);
        console2.log("FEES module upgraded with FeeFacet at:", address(feeFacet));

        // Publish the DAO's canonical fee registries — gardens validate every
        // configureFeeModule against these (fail-closed while unpublished)
        registry.setCanonicalFeeRegistries(feeRegistry, treasuryRegistry, onboarderRegistry);
        console2.log("Canonical fee registries published on FacetRegistry");

        // Allow the FEES module on the INDEX_GARDEN type (append to the allowed list)
        bytes32[] memory currentModules = registry.getGardenTypeModules(INDEX_GARDEN);
        bool alreadyAllowed = false;
        for (uint256 i = 0; i < currentModules.length; i++) {
            if (currentModules[i] == MODULE_FEES) alreadyAllowed = true;
        }
        if (!alreadyAllowed) {
            bytes32[] memory newModules = new bytes32[](currentModules.length + 1);
            for (uint256 i = 0; i < currentModules.length; i++) {
                newModules[i] = currentModules[i];
            }
            newModules[currentModules.length] = MODULE_FEES;
            registry.addGardenType(INDEX_GARDEN, newModules);
            console2.log("FEES module allowed on INDEX_GARDEN");
        }

        // =====================================================================
        // 3. Garden-side: pull pending cuts + wire the fee registries
        // =====================================================================
        address[] memory gardens = _parseGardens(vm.envString("GARDENS"));
        for (uint256 i = 0; i < gardens.length; i++) {
            address garden = gardens[i];
            console2.log("Upgrading garden:", garden);

            // Pull pending module cuts (two-step upgrade flow)
            (bool okDetails, bytes memory details) = garden.call(abi.encodeWithSignature("upgradeDetails()"));
            if (!okDetails) revert("upgradeDetails failed");
            (bool okUpgrade,) = garden.call(abi.encodeWithSignature("upgrade(bytes)", details));
            if (!okUpgrade) revert("garden upgrade failed");
            console2.log("  module cuts pulled");

            // Wire the fee registries (first-time config is allowed while connected)
            (bool okCfg,) = garden.call(
                abi.encodeWithSignature(
                    "configureFeeModule(address,address,address)", feeRegistry, treasuryRegistry, onboarderRegistry
                )
            );
            if (!okCfg) revert("configureFeeModule failed");
            console2.log("  fee module configured");
        }
        console2.log("Fee rollout complete");
    }

    function _parseGardens(string memory raw) internal pure returns (address[] memory) {
        bytes memory b = bytes(raw);
        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }
        address[] memory out = new address[](count);
        uint256 idx;
        uint256 start;
        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == ",") {
                out[idx++] = vm.parseAddress(_slice(raw, start, i));
                start = i + 1;
            }
        }
        return out;
    }

    function _slice(string memory raw, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory b = bytes(raw);
        bytes memory out = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = b[i];
        }
        return string(out);
    }
}
