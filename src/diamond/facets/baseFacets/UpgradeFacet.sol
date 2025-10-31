//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title Upgrade Facet
    @author BLOK Capital DAO
    @notice External facet exposing upgrade entrypoints. It delegates the heavy lifting
            to UpgradeBase internal helpers and registers the IUpgrade interface id on init.
    @dev The `upgrade()` entrypoint is intentionally left unrestricted in this file to mirror
         your original code.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/IDiamondLoupe.sol";
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/DiamondLoupeFacet.sol";

error UpgradeFacet_InvalidRegistryAddress();
error UpgradeFacet_AlreadyAtLatestVersion();

contract UpgradeFacet is DiamondLoupeFacet {
    uint256 private latestRegistryVersion;
    IDiamondCut.FacetCut[] private latestFacetCuts;

    event GardenUpgraded(uint256 indexed newVersion);

    function upgradeDetails() external returns (IDiamondCut.FacetCut[] memory) {
        address registry = LibDiamond.facetRegistry();
        if (registry == address(0)) revert UpgradeFacet_InvalidRegistryAddress();
        uint256 registryVersion = IFacetRegistry(registry).getCurrentVersion();
        uint256 diamondCurrentVersion = LibDiamond.currentVersion();
        if (diamondCurrentVersion == registryVersion) {
            return new IDiamondCut.FacetCut[](0);
        }

        address[] memory registryFacets = IFacetRegistry(registry).getFacetAddresses();
        IDiamondCut.FacetCut[] memory facetCuts = _buildFacetCuts(registry, registryFacets);
        latestFacetCuts = facetCuts;
        latestRegistryVersion = registryVersion;
        return facetCuts;
    }

    function upgrade() external {
        LibDiamond.diamondCut(latestFacetCuts, address(0), bytes(""));
        LibDiamond.setCurrentVersion(latestRegistryVersion);
        emit GardenUpgraded(latestRegistryVersion);
    }

    function _buildFacetCuts(
        address registry,
        address[] memory registryFacets
    )
        internal
        view
        returns (IDiamondCut.FacetCut[] memory)
    {
        (uint256 removeFacetCount, uint256 addCutCount, uint256 replaceCutCount) =
            _countFacetActions(registry, registryFacets);

        uint256 totalCuts = removeFacetCount + addCutCount + replaceCutCount;
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](totalCuts);

        uint256 cutIndex = 0;

        cutIndex = _fillRemoveFacetCuts(registry, registryFacets, facetCuts, cutIndex);
        cutIndex = _fillAddReplaceFacetCuts(registry, registryFacets, facetCuts, cutIndex);

        return facetCuts;
    }

    function _countFacetActions(
        address registry,
        address[] memory registryFacets
    )
        internal
        view
        returns (uint256 removeFacetCount, uint256 addCutCount, uint256 replaceCutCount)
    {
        address[] memory currentFacets = IDiamondLoupe(address(this)).facetAddresses();
        for (uint256 i = 0; i < currentFacets.length; i++) {
            address currentFacet = currentFacets[i];
            if (!_addressInArray(currentFacet, registryFacets)) {
                removeFacetCount += 1;
            } else {
                bytes4[] memory regSelectors = IFacetRegistry(registry).getFacetFunctionSelectors(currentFacet);
                bytes4[] memory currentSelectors = IDiamondLoupe(address(this)).facetFunctionSelectors(currentFacet);
                uint256 toRemove = _countSelectorsNotInRegistry(currentSelectors, regSelectors);
                if (toRemove > 0) {
                    removeFacetCount += 1;
                }
            }
        }
        (addCutCount, replaceCutCount) = _countRegistryFacetActions(registry, registryFacets);
    }

    function _countRegistryFacetActions(
        address registry,
        address[] memory registryFacets
    )
        internal
        view
        returns (uint256 addCutCount, uint256 replaceCutCount)
    {
        for (uint256 i = 0; i < registryFacets.length; i++) {
            address regFacet = registryFacets[i];
            bytes4[] memory regSelectors = IFacetRegistry(registry).getFacetFunctionSelectors(regFacet);
            if (_countSelectorsToAdd(regSelectors) > 0) addCutCount += 1;
            if (_countSelectorsToReplace(regSelectors, regFacet) > 0) replaceCutCount += 1;
        }
    }

    function _fillRemoveFacetCuts(
        address registry,
        address[] memory registryFacets,
        IDiamondCut.FacetCut[] memory facetCuts,
        uint256 cutIndex
    )
        internal
        view
        returns (uint256)
    {
        address[] memory currentFacets = IDiamondLoupe(address(this)).facetAddresses();
        for (uint256 i = 0; i < currentFacets.length; i++) {
            address currentFacet = currentFacets[i];
            if (!_addressInArray(currentFacet, registryFacets)) {
                bytes4[] memory selectorsAll = IDiamondLoupe(address(this)).facetFunctionSelectors(currentFacet);
                facetCuts[cutIndex] = IDiamondCut.FacetCut({
                    facetAddress: address(0),
                    action: IDiamondCut.FacetCutAction.Remove,
                    functionSelectors: selectorsAll
                });
                cutIndex++;
            } else {
                bytes4[] memory regSelectors = IFacetRegistry(registry).getFacetFunctionSelectors(currentFacet);
                bytes4[] memory currentSelectors = IDiamondLoupe(address(this)).facetFunctionSelectors(currentFacet);
                bytes4[] memory toRemove = _selectorsInSetButNotInArray(currentSelectors, regSelectors);
                if (toRemove.length > 0) {
                    facetCuts[cutIndex] = IDiamondCut.FacetCut({
                        facetAddress: address(0),
                        action: IDiamondCut.FacetCutAction.Remove,
                        functionSelectors: toRemove
                    });
                    cutIndex++;
                }
            }
        }
        return cutIndex;
    }

    function _fillAddReplaceFacetCuts(
        address registry,
        address[] memory registryFacets,
        IDiamondCut.FacetCut[] memory facetCuts,
        uint256 cutIndex
    )
        internal
        view
        returns (uint256)
    {
        for (uint256 i = 0; i < registryFacets.length; i++) {
            address regFacet = registryFacets[i];
            bytes4[] memory regSelectors = IFacetRegistry(registry).getFacetFunctionSelectors(regFacet);
            bytes4[] memory addSelectors = _selectorsInArrayThatAreMissing(regSelectors);
            if (addSelectors.length > 0) {
                facetCuts[cutIndex] = IDiamondCut.FacetCut({
                    facetAddress: regFacet,
                    action: IDiamondCut.FacetCutAction.Add,
                    functionSelectors: addSelectors
                });
                cutIndex++;
            }
            bytes4[] memory replaceSelectors = _selectorsToReplaceForFacet(regSelectors, regFacet);
            if (replaceSelectors.length > 0) {
                facetCuts[cutIndex] = IDiamondCut.FacetCut({
                    facetAddress: regFacet,
                    action: IDiamondCut.FacetCutAction.Replace,
                    functionSelectors: replaceSelectors
                });
                cutIndex++;
            }
        }
        return cutIndex;
    }

    // Count number of selectors in set that are NOT present in the provided regSelectors array
    function _countSelectorsNotInRegistry(
        bytes4[] memory currentSelectors,
        bytes4[] memory regSelectors
    )
        internal
        pure
        returns (uint256)
    {
        uint256 counter = 0;
        for (uint256 i = 0; i < currentSelectors.length; i++) {
            bytes4 s = currentSelectors[i];
            if (!_bytes4InArray(s, regSelectors)) counter++;
        }
        return counter;
    }

    // Return array of selectors which are in the Bytes32Set but not in the regSelectors array
    function _selectorsInSetButNotInArray(
        bytes4[] memory currentSelectors,
        bytes4[] memory regSelectors
    )
        internal
        pure
        returns (bytes4[] memory)
    {
        uint256 count = _countSelectorsNotInRegistry(currentSelectors, regSelectors);
        if (count == 0) return new bytes4[](0);

        bytes4[] memory out = new bytes4[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < currentSelectors.length; i++) {
            bytes4 s = currentSelectors[i];
            if (!_bytes4InArray(s, regSelectors)) {
                out[idx] = s;
                idx++;
            }
        }
        return out;
    }

    // Count selectors that are present in regSelectors but missing from diamond (selectorToFacet == address(0))
    function _countSelectorsToAdd(bytes4[] memory regSelectors) internal view returns (uint256) {
        uint256 c = 0;
        for (uint256 i = 0; i < regSelectors.length; i++) {
            if (IDiamondLoupe(address(this)).facetAddress(regSelectors[i]) == address(0)) c++;
        }
        return c;
    }

    // Return array of regSelectors that are missing from diamond (selectorToFacet == address(0))
    function _selectorsInArrayThatAreMissing(bytes4[] memory regSelectors) internal view returns (bytes4[] memory) {
        uint256 count = _countSelectorsToAdd(regSelectors);
        if (count == 0) return new bytes4[](0);
        bytes4[] memory out = new bytes4[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < regSelectors.length; i++) {
            if (IDiamondLoupe(address(this)).facetAddress(regSelectors[i]) == address(0)) {
                out[idx] = regSelectors[i];
                idx++;
            }
        }
        return out;
    }

    // Count selectors that need replacement for regFacet: currently assigned to other facet != regFacet and !=
    function _countSelectorsToReplace(bytes4[] memory regSelectors, address regFacet) internal view returns (uint256) {
        uint256 c = 0;
        for (uint256 i = 0; i < regSelectors.length; i++) {
            address prev = IDiamondLoupe(address(this)).facetAddress(regSelectors[i]);
            if (prev != address(0) && prev != regFacet) c++;
        }
        return c;
    }

    // Return array of selectors to replace for regFacet
    function _selectorsToReplaceForFacet(
        bytes4[] memory regSelectors,
        address regFacet
    )
        internal
        view
        returns (bytes4[] memory)
    {
        uint256 count = _countSelectorsToReplace(regSelectors, regFacet);
        if (count == 0) return new bytes4[](0);
        bytes4[] memory out = new bytes4[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < regSelectors.length; i++) {
            address prev = IDiamondLoupe(address(this)).facetAddress(regSelectors[i]);
            if (prev != address(0) && prev != regFacet) {
                out[idx] = regSelectors[i];
                idx++;
            }
        }
        return out;
    }

    function _addressInArray(address addr, address[] memory arr) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (addr == arr[i]) {
                return true;
            }
        }
        return false;
    }

    function _bytes4InArray(bytes4 val, bytes4[] memory arr) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (val == arr[i]) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice View helper that returns the locally-tracked upgrade version.
     * @return The current upgrade version number.
     */
    function getCurrentVersion() external view returns (uint256) { }
}
