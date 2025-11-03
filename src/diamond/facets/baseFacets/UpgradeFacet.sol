// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title UpgradeFacet
    @author BLOK Capital DAO
    @notice Facet that manages Diamond upgrades by syncing with the FacetRegistry.
    @dev This facet allows upgrading the diamond to match the latest state of the FacetRegistry.
         It supports a two-step upgrade process: first get upgrade details with hash, then execute
         the upgrade with the hash for verification. This ensures upgrades can be verified
         before execution.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/IDiamondLoupe.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IUpgrade } from "src/interfaces/IUpgrade.sol";

// Local Contracts
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/DiamondLoupeFacet.sol";

// Local Libraries
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when facet registry address is not set or is zero
error UpgradeFacet_InvalidRegistryAddress();

/// @notice Thrown when attempting to upgrade but already at the latest version
/// @param registryVersion The registry version that is already applied
error UpgradeFacet_AlreadyAtLatestVersion(uint256 registryVersion);

/// @notice Thrown when the computed hash does not match the provided hash data
error UpgradeFacet_HashMismatch();

/// @notice Thrown when no facet cuts are required for upgrade
error UpgradeFacet_NoFacetCutsRequired();

// ============================================================================
// UpgradeFacet
// ============================================================================

/**
 * @title UpgradeFacet
 * @notice Facet that manages Diamond upgrades by syncing with the FacetRegistry
 * @dev This facet allows upgrading the diamond to match the latest state of the FacetRegistry.
 *      It supports a hash-verified upgrade process for safety. Get the hash from upgradeDetails()
 *      first, then call upgrade(bytes32) with the hash to verify the upgrade plan before execution.
 *      Note: Passing bytes32(0) will skip hash verification (not recommended for production).
 */
contract UpgradeFacet is DiamondLoupeFacet, IUpgrade {
    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when a garden upgrade is successfully completed
    /// @param newVersion The new version number after upgrade
    event GardenUpgraded(uint256 indexed newVersion);

    // ========================================================================
    // Modifier
    // ========================================================================

    modifier onlyDiamondOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /**
     * @notice Returns upgrade details including facet cuts, registry version, and verification hash
     * @dev This function calculates the facet cuts needed to upgrade the diamond to match
     *      the latest state of the FacetRegistry. The hash can be used to verify the upgrade
     *      plan before execution using upgrade(bytes32).
     * @return facetCuts Array of facet cuts required for the upgrade
     * @return registryVersion The target registry version for the upgrade
     * @return hashData Hash of the facet cuts and registry version for verification
     */
    function upgradeDetails()
        external
        view
        onlyDiamondOwner
        returns (IDiamondCut.FacetCut[] memory facetCuts, uint256 registryVersion, bytes32 hashData)
    {
        address registry = LibDiamond.facetRegistry();
        if (registry == address(0)) {
            revert UpgradeFacet_InvalidRegistryAddress();
        }

        registryVersion = IFacetRegistry(registry).getCurrentVersion();
        uint256 diamondCurrentVersion = LibDiamond.currentVersion();

        if (diamondCurrentVersion == registryVersion) {
            revert UpgradeFacet_AlreadyAtLatestVersion(registryVersion);
        }

        address[] memory registryFacets = IFacetRegistry(registry).getFacetAddresses();
        facetCuts = _buildFacetCuts(registry, registryFacets);
        hashData = keccak256(abi.encode(facetCuts, registryVersion));

        return (facetCuts, registryVersion, hashData);
    }

    /**
     * @notice Returns the current upgrade version of the diamond
     * @dev Returns the version number tracked in diamond storage
     * @return The current version number tracked in the diamond storage
     */
    function getCurrentVersion() external view returns (uint256) {
        return LibDiamond.currentVersion();
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /**
     * @notice Executes the upgrade to sync the diamond with the FacetRegistry (hash-verified version)
     * @dev Verifies the hash before executing to ensure the upgrade plan hasn't changed.
     *      This is the recommended method for upgrades as it provides safety through verification.
     *      Get the hash from upgradeDetails() first, then call this function with the hash.
     *      Note: Passing bytes32(0) will skip hash verification (not recommended for production).
     * @param _hashData The hash of the upgrade details from upgradeDetails() for verification.
     *                  Pass bytes32(0) to skip verification (not recommended for production use)
     */
    function upgrade(bytes32 _hashData) external onlyDiamondOwner {
        bool verifyHash = _hashData != bytes32(0);
        _executeUpgrade(address(0), _hashData, verifyHash);
    }

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /**
     * @notice Internal function that executes the upgrade logic
     * @dev Handles both hash-verified and non-verified upgrades
     * @param _init The initialization contract address (unused, for future extensibility)
     * @param _hashData The hash for verification, or bytes32(0) if no verification
     * @param _verifyHash Whether to verify the hash before executing
     */
    function _executeUpgrade(address _init, bytes32 _hashData, bool _verifyHash) internal {
        address registry = LibDiamond.facetRegistry();
        if (registry == address(0)) {
            revert UpgradeFacet_InvalidRegistryAddress();
        }

        uint256 latestRegistryVersion = IFacetRegistry(registry).getCurrentVersion();
        uint256 diamondCurrentVersion = LibDiamond.currentVersion();

        if (diamondCurrentVersion == latestRegistryVersion) {
            revert UpgradeFacet_AlreadyAtLatestVersion(latestRegistryVersion);
        }

        address[] memory registryFacets = IFacetRegistry(registry).getFacetAddresses();
        IDiamondCut.FacetCut[] memory latestFacetCuts = _buildFacetCuts(registry, registryFacets);

        // Validate that there are facet cuts to apply
        if (latestFacetCuts.length == 0) {
            revert UpgradeFacet_NoFacetCutsRequired();
        }

        // Verify hash if requested
        if (_verifyHash) {
            bytes32 computedHash = keccak256(abi.encode(latestFacetCuts, latestRegistryVersion));
            if (computedHash != _hashData) {
                revert UpgradeFacet_HashMismatch();
            }
        }

        // Execute the upgrade
        LibDiamond.diamondCut(latestFacetCuts, _init, bytes(""));
        LibDiamond.setCurrentVersion(latestRegistryVersion);

        emit GardenUpgraded(latestRegistryVersion);
    }

    /**
     * @notice Builds the array of facet cuts needed for the upgrade
     * @dev Analyzes the difference between current diamond state and registry state,
     *      then builds appropriate add, replace, and remove operations.
     * @param _registry The address of the FacetRegistry
     * @param _registryFacets Array of facet addresses from the registry
     * @return Array of facet cuts to apply
     */
    function _buildFacetCuts(
        address _registry,
        address[] memory _registryFacets
    )
        internal
        view
        returns (IDiamondCut.FacetCut[] memory)
    {
        (uint256 removeFacetCount, uint256 addCutCount, uint256 replaceCutCount) =
            _countFacetActions(_registry, _registryFacets);

        uint256 totalCuts = removeFacetCount + addCutCount + replaceCutCount;
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](totalCuts);

        uint256 cutIndex = 0;

        cutIndex = _fillRemoveFacetCuts(_registry, _registryFacets, facetCuts, cutIndex);
        cutIndex = _fillAddReplaceFacetCuts(_registry, _registryFacets, facetCuts, cutIndex);

        return facetCuts;
    }

    /**
     * @notice Counts the number of facet actions needed for upgrade
     * @param _registry The address of the FacetRegistry
     * @param _registryFacets Array of facet addresses from the registry
     * @return removeFacetCount Number of facets/selectors to remove
     * @return addCutCount Number of facets to add
     * @return replaceCutCount Number of facets to replace
     */
    function _countFacetActions(
        address _registry,
        address[] memory _registryFacets
    )
        internal
        view
        returns (uint256 removeFacetCount, uint256 addCutCount, uint256 replaceCutCount)
    {
        address[] memory currentFacets = IDiamondLoupe(address(this)).facetAddresses();

        for (uint256 i = 0; i < currentFacets.length; i++) {
            address currentFacet = currentFacets[i];
            if (!_addressInArray(currentFacet, _registryFacets)) {
                // Facet not in registry, remove entire facet
                removeFacetCount += 1;
            } else {
                // Facet exists in registry, check for selector differences
                bytes4[] memory regSelectors = IFacetRegistry(_registry).getFacetFunctionSelectors(currentFacet);
                bytes4[] memory currentSelectors = IDiamondLoupe(address(this)).facetFunctionSelectors(currentFacet);
                uint256 toRemove = _countSelectorsNotInRegistry(currentSelectors, regSelectors);
                if (toRemove > 0) {
                    removeFacetCount += 1;
                }
            }
        }

        (addCutCount, replaceCutCount) = _countRegistryFacetActions(_registry, _registryFacets);
    }

    /**
     * @notice Counts add and replace actions needed for registry facets
     * @param _registry The address of the FacetRegistry
     * @param _registryFacets Array of facet addresses from the registry
     * @return addCutCount Number of facets to add
     * @return replaceCutCount Number of facets to replace
     */
    function _countRegistryFacetActions(
        address _registry,
        address[] memory _registryFacets
    )
        internal
        view
        returns (uint256 addCutCount, uint256 replaceCutCount)
    {
        for (uint256 i = 0; i < _registryFacets.length; i++) {
            address regFacet = _registryFacets[i];
            bytes4[] memory regSelectors = IFacetRegistry(_registry).getFacetFunctionSelectors(regFacet);

            if (_countSelectorsToAdd(regSelectors) > 0) {
                addCutCount += 1;
            }
            if (_countSelectorsToReplace(regSelectors, regFacet) > 0) {
                replaceCutCount += 1;
            }
        }
    }

    /**
     * @notice Fills the facet cuts array with remove operations
     * @param _registry The address of the FacetRegistry
     * @param _registryFacets Array of facet addresses from the registry
     * @param _facetCuts Array to fill with facet cuts
     * @param _cutIndex Starting index in the facet cuts array
     * @return Updated cut index after filling
     */
    function _fillRemoveFacetCuts(
        address _registry,
        address[] memory _registryFacets,
        IDiamondCut.FacetCut[] memory _facetCuts,
        uint256 _cutIndex
    )
        internal
        view
        returns (uint256)
    {
        address[] memory currentFacets = IDiamondLoupe(address(this)).facetAddresses();

        for (uint256 i = 0; i < currentFacets.length; i++) {
            address currentFacet = currentFacets[i];
            if (!_addressInArray(currentFacet, _registryFacets)) {
                // Remove entire facet - all its selectors
                bytes4[] memory selectorsAll = IDiamondLoupe(address(this)).facetFunctionSelectors(currentFacet);
                _facetCuts[_cutIndex] = IDiamondCut.FacetCut({
                    facetAddress: address(0),
                    action: IDiamondCut.FacetCutAction.Remove,
                    functionSelectors: selectorsAll
                });
                _cutIndex++;
            } else {
                // Facet exists in registry, but some selectors may need removal
                bytes4[] memory regSelectors = IFacetRegistry(_registry).getFacetFunctionSelectors(currentFacet);
                bytes4[] memory currentSelectors = IDiamondLoupe(address(this)).facetFunctionSelectors(currentFacet);
                bytes4[] memory toRemove = _selectorsInSetButNotInArray(currentSelectors, regSelectors);
                if (toRemove.length > 0) {
                    _facetCuts[_cutIndex] = IDiamondCut.FacetCut({
                        facetAddress: address(0),
                        action: IDiamondCut.FacetCutAction.Remove,
                        functionSelectors: toRemove
                    });
                    _cutIndex++;
                }
            }
        }

        return _cutIndex;
    }

    /**
     * @notice Fills the facet cuts array with add and replace operations
     * @param _registry The address of the FacetRegistry
     * @param _registryFacets Array of facet addresses from the registry
     * @param _facetCuts Array to fill with facet cuts
     * @param _cutIndex Starting index in the facet cuts array
     * @return Updated cut index after filling
     */
    function _fillAddReplaceFacetCuts(
        address _registry,
        address[] memory _registryFacets,
        IDiamondCut.FacetCut[] memory _facetCuts,
        uint256 _cutIndex
    )
        internal
        view
        returns (uint256)
    {
        for (uint256 i = 0; i < _registryFacets.length; i++) {
            address regFacet = _registryFacets[i];
            bytes4[] memory regSelectors = IFacetRegistry(_registry).getFacetFunctionSelectors(regFacet);

            // Add selectors that are missing from diamond
            bytes4[] memory addSelectors = _selectorsInArrayThatAreMissing(regSelectors);
            if (addSelectors.length > 0) {
                _facetCuts[_cutIndex] = IDiamondCut.FacetCut({
                    facetAddress: regFacet,
                    action: IDiamondCut.FacetCutAction.Add,
                    functionSelectors: addSelectors
                });
                _cutIndex++;
            }

            // Replace selectors that are currently on different facets
            bytes4[] memory replaceSelectors = _selectorsToReplaceForFacet(regSelectors, regFacet);
            if (replaceSelectors.length > 0) {
                _facetCuts[_cutIndex] = IDiamondCut.FacetCut({
                    facetAddress: regFacet,
                    action: IDiamondCut.FacetCutAction.Replace,
                    functionSelectors: replaceSelectors
                });
                _cutIndex++;
            }
        }

        return _cutIndex;
    }

    /**
     * @notice Counts selectors in current set that are not in registry
     * @param _currentSelectors Array of current selectors
     * @param _regSelectors Array of registry selectors
     * @return Count of selectors to remove
     */
    function _countSelectorsNotInRegistry(
        bytes4[] memory _currentSelectors,
        bytes4[] memory _regSelectors
    )
        internal
        pure
        returns (uint256)
    {
        uint256 counter = 0;
        for (uint256 i = 0; i < _currentSelectors.length; i++) {
            bytes4 s = _currentSelectors[i];
            if (!_bytes4InArray(s, _regSelectors)) {
                counter++;
            }
        }
        return counter;
    }

    /**
     * @notice Returns array of selectors in current set but not in registry array
     * @param _currentSelectors Array of current selectors
     * @param _regSelectors Array of registry selectors
     * @return Array of selectors to remove
     */
    function _selectorsInSetButNotInArray(
        bytes4[] memory _currentSelectors,
        bytes4[] memory _regSelectors
    )
        internal
        pure
        returns (bytes4[] memory)
    {
        uint256 count = _countSelectorsNotInRegistry(_currentSelectors, _regSelectors);
        if (count == 0) {
            return new bytes4[](0);
        }

        bytes4[] memory out = new bytes4[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < _currentSelectors.length; i++) {
            bytes4 s = _currentSelectors[i];
            if (!_bytes4InArray(s, _regSelectors)) {
                out[idx] = s;
                idx++;
            }
        }
        return out;
    }

    /**
     * @notice Counts selectors in registry that need to be added
     * @param _regSelectors Array of registry selectors
     * @return Count of selectors to add
     */
    function _countSelectorsToAdd(bytes4[] memory _regSelectors) internal view returns (uint256) {
        uint256 c = 0;
        for (uint256 i = 0; i < _regSelectors.length; i++) {
            if (IDiamondLoupe(address(this)).facetAddress(_regSelectors[i]) == address(0)) {
                c++;
            }
        }
        return c;
    }

    /**
     * @notice Returns array of registry selectors that are missing from diamond
     * @param _regSelectors Array of registry selectors
     * @return Array of selectors to add
     */
    function _selectorsInArrayThatAreMissing(bytes4[] memory _regSelectors) internal view returns (bytes4[] memory) {
        uint256 count = _countSelectorsToAdd(_regSelectors);
        if (count == 0) {
            return new bytes4[](0);
        }

        bytes4[] memory out = new bytes4[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < _regSelectors.length; i++) {
            if (IDiamondLoupe(address(this)).facetAddress(_regSelectors[i]) == address(0)) {
                out[idx] = _regSelectors[i];
                idx++;
            }
        }
        return out;
    }

    /**
     * @notice Counts selectors that need replacement for a registry facet
     * @param _regSelectors Array of registry selectors
     * @param _regFacet The registry facet address
     * @return Count of selectors to replace
     */
    function _countSelectorsToReplace(
        bytes4[] memory _regSelectors,
        address _regFacet
    )
        internal
        view
        returns (uint256)
    {
        uint256 c = 0;
        for (uint256 i = 0; i < _regSelectors.length; i++) {
            address prev = IDiamondLoupe(address(this)).facetAddress(_regSelectors[i]);
            if (prev != address(0) && prev != _regFacet) {
                c++;
            }
        }
        return c;
    }

    /**
     * @notice Returns array of selectors to replace for a registry facet
     * @param _regSelectors Array of registry selectors
     * @param _regFacet The registry facet address
     * @return Array of selectors to replace
     */
    function _selectorsToReplaceForFacet(
        bytes4[] memory _regSelectors,
        address _regFacet
    )
        internal
        view
        returns (bytes4[] memory)
    {
        uint256 count = _countSelectorsToReplace(_regSelectors, _regFacet);
        if (count == 0) {
            return new bytes4[](0);
        }

        bytes4[] memory out = new bytes4[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < _regSelectors.length; i++) {
            address prev = IDiamondLoupe(address(this)).facetAddress(_regSelectors[i]);
            if (prev != address(0) && prev != _regFacet) {
                out[idx] = _regSelectors[i];
                idx++;
            }
        }
        return out;
    }

    /**
     * @notice Checks if an address exists in an array
     * @param _addr Address to search for
     * @param _arr Array to search in
     * @return True if address is found, false otherwise
     */
    function _addressInArray(address _addr, address[] memory _arr) internal pure returns (bool) {
        for (uint256 i = 0; i < _arr.length; i++) {
            if (_addr == _arr[i]) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Checks if a bytes4 value exists in an array
     * @param _val Bytes4 value to search for
     * @param _arr Array to search in
     * @return True if value is found, false otherwise
     */
    function _bytes4InArray(bytes4 _val, bytes4[] memory _arr) internal pure returns (bool) {
        for (uint256 i = 0; i < _arr.length; i++) {
            if (_val == _arr[i]) {
                return true;
            }
        }
        return false;
    }
}
