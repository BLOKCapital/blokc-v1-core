// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

/// @title IFacetRegistry
/// @author BLOK Capital DAO
/// @notice Interface for the modular Facet Registry supporting versioned modules and garden types.
/// @dev Manages facet registration across modules, tracks versions, and defines garden type
///      configurations that determine which modules a deployed Garden diamond can use.
interface IFacetRegistry {
    // ========================================================================
    //                              STRUCTS
    // ========================================================================

    /// @notice Represents a facet address paired with its registered function selectors.
    /// @param facetAddress The deployed address of the facet contract.
    /// @param functionSelectors The four-byte selectors routed to this facet.
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Maps a facet address to its position within the selector array.
    /// @param facetAddress The deployed address of the facet contract.
    /// @param functionSelectorPosition Index within `FacetFunctionSelectors.functionSelectors`.
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

    /// @notice Stores selectors for a facet and the facet's position in the address array.
    /// @param functionSelectors The four-byte selectors registered to this facet.
    /// @param facetAddressPosition Index of the facet in the `facetAddresses` array.
    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition;
    }

    // ========================================================================
    //                         MODULE FUNCTIONS
    // ========================================================================

    /// @notice Registers a new empty module
    /// @param moduleId The bytes32 identifier for the module
    function registerModule(bytes32 moduleId) external;

    /// @notice Upgrades a module by applying facet cuts (reverts for BASE_MODULE)
    /// @param moduleId The module to upgrade
    /// @param facetCuts Array of facet cuts to apply within this module
    function upgradeModule(bytes32 moduleId, IDiamondCut.FacetCut[] memory facetCuts) external;

    // ========================================================================
    //                       GARDEN TYPE FUNCTIONS
    // ========================================================================

    /// @notice Creates a new garden type with an initial set of allowed non-base modules
    /// @dev BASE_MODULE is always implicitly included. Reverts if BASE_MODULE is in allowedModules.
    /// @param gardenTypeId The bytes32 identifier for the garden type
    /// @param allowedModules The initial set of allowed module IDs (must NOT include BASE_MODULE)
    function addGardenType(bytes32 gardenTypeId, bytes32[] memory allowedModules) external;

    /// @notice Adds an allowed module to a garden type (cannot add BASE_MODULE)
    /// @dev BASE_MODULE is always implicit. Reverts if moduleId is BASE_MODULE.
    /// @param gardenTypeId The garden type to modify
    /// @param moduleId The module to add (must not be BASE_MODULE)
    function addAllowedModule(bytes32 gardenTypeId, bytes32 moduleId) external;

    /// @notice Removes an allowed module from a garden type
    /// @dev BASE_MODULE is implicit and cannot appear in the modules list
    /// @param gardenTypeId The garden type to modify
    /// @param moduleId The module to remove
    function removeAllowedModule(bytes32 gardenTypeId, bytes32 moduleId) external;

    // ========================================================================
    //                        MODULE VIEW FUNCTIONS
    // ========================================================================

    /// @notice Returns all facets with their selectors for a specific module
    /// @param moduleId The module to query
    /// @return facets_ Array of Facet structs
    function getModuleFacets(bytes32 moduleId) external view returns (Facet[] memory facets_);

    /// @notice Returns all facet addresses in a module
    /// @param moduleId The module to query
    /// @return facetAddresses_ Array of facet addresses
    function getModuleFacetAddresses(bytes32 moduleId) external view returns (address[] memory facetAddresses_);

    /// @notice Returns facet cuts for a module within a version range
    /// @param moduleId The module to query
    /// @param startVersion The start version (inclusive)
    /// @param endVersion The end version (inclusive)
    /// @return facetCuts Array of facet cuts
    function getModuleFacetCutsByVersionRange(
        bytes32 moduleId,
        uint256 startVersion,
        uint256 endVersion
    )
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts);

    /// @notice Returns the current version of a module
    /// @param moduleId The module to query
    /// @return version The current module version
    function getModuleVersion(bytes32 moduleId) external view returns (uint256 version);

    /// @notice Returns all registered module IDs
    /// @return moduleIds Array of module IDs
    function getAllModuleIds() external view returns (bytes32[] memory moduleIds);

    /// @notice Returns the module a facet belongs to
    /// @param facetAddress The facet address to query
    /// @return moduleId The module the facet belongs to
    function getFacetModule(address facetAddress) external view returns (bytes32 moduleId);

    /// @notice Returns the module that supports a given function selector
    /// @param selector The function selector to query
    /// @return moduleId The module that supports the selector
    function getModuleIdBySelector(bytes4 selector) external view returns (bytes32);

    /// @notice Checks if a module is registered
    /// @param moduleId The module to check
    /// @return True if the module is registered
    function isModuleRegistered(bytes32 moduleId) external view returns (bool);

    // ========================================================================
    //                     GARDEN TYPE VIEW FUNCTIONS
    // ========================================================================

    /// @notice Returns the non-base allowed modules for a garden type
    /// @dev BASE_MODULE is always implicitly included and is not returned here
    /// @param gardenTypeId The garden type to query
    /// @return moduleIds Array of allowed non-base module IDs
    function getGardenTypeModules(bytes32 gardenTypeId) external view returns (bytes32[] memory moduleIds);

    /// @notice Checks if a module is allowed for a garden type
    /// @dev Reverts if the garden type is not registered. Always returns true for BASE_MODULE.
    /// @param gardenTypeId The garden type to check
    /// @param moduleId The module to check
    /// @return True if the module is allowed (always true for BASE_MODULE)
    function isModuleAllowedForGardenType(bytes32 gardenTypeId, bytes32 moduleId) external view returns (bool);

    /// @notice Returns all registered garden type IDs
    /// @return gardenTypeIds Array of garden type IDs
    function getAllGardenTypeIds() external view returns (bytes32[] memory gardenTypeIds);

    /// @notice Checks if a garden type is registered
    /// @param gardenTypeId The garden type to check
    /// @return True if the garden type is registered
    function isGardenTypeRegistered(bytes32 gardenTypeId) external view returns (bool);

    /// @notice Returns Add FacetCuts for only the BASE module facets
    /// @dev Used by the factory to deploy gardens with only BASE facets.
    ///      Utility modules are installed later via upgrade().
    /// @return facetCuts Array of FacetCut structs (all with Add action) for BASE module only
    function getBaseFacetCuts() external view returns (IDiamondCut.FacetCut[] memory facetCuts);

    /// @notice Returns aggregated Add FacetCuts for a garden type (base facets + allowed modules)
    /// @dev BASE_MODULE facets are always prepended. Used by the factory to deploy gardens.
    /// @param gardenTypeId The garden type to query
    /// @return facetCuts Array of FacetCut structs (all with Add action)
    function getGardenTypeFacetCuts(bytes32 gardenTypeId)
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts);

    /// @notice Returns aggregated facets for a garden type (base facets + allowed modules)
    /// @dev BASE_MODULE facets are always prepended implicitly.
    /// @param gardenTypeId The garden type to query
    /// @return facets_ Array of Facet structs
    function getGardenTypeFacets(bytes32 gardenTypeId) external view returns (Facet[] memory facets_);

    // ========================================================================
    //                   GLOBAL VIEW FUNCTIONS
    // ========================================================================

    /// @notice Returns all facets and their selectors
    /// @return facets_ Array of Facet structs containing facet addresses and their function selectors
    function getFacets() external view returns (Facet[] memory facets_);

    /// @notice Returns all the function selectors provided by a facet
    /// @param _facet The facet address
    /// @return selectors Array of function selectors
    function getFacetFunctionSelectors(address _facet) external view returns (bytes4[] memory selectors);

    /// @notice Returns all the facet addresses used by the registry
    /// @return facetAddresses_ Array of facet addresses
    function getFacetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Returns the facet that supports the given selector
    /// @param _functionSelector The function selector
    /// @return facetAddress_ The facet address
    function getFacetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);

    /// @notice Returns base facets
    /// @return baseFacets_ Array of base facet addresses
    function getBaseFacets() external view returns (address[4] memory baseFacets_);

    /// @notice Returns the facet cuts for a global version range (backward compat)
    /// @param _startVersion The start version
    /// @param _endVersion The end version
    /// @return facetCuts The facet cuts for the version range
    function getFacetCutsByVersionRange(
        uint256 _startVersion,
        uint256 _endVersion
    )
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts);

    /// @notice Returns if a facet registered or not
    /// @param facet The address of the facet
    /// @return isRegistered True if the facet is registered, false otherwise
    function isFacetRegistered(address facet) external view returns (bool isRegistered);

    /// @notice Checks if a function selector is registered in the registry (any facet)
    /// @param selector The function selector to check
    /// @return isRegistered True if the selector is registered for any facet, false otherwise
    function isSelectorRegistered(bytes4 selector) external view returns (bool isRegistered);

    /// @notice Checks if a function selector is registered for a specific facet
    /// @param facet The address of the facet to check
    /// @param selector The function selector to check
    /// @return isRegistered True if the selector is registered for the specified facet, false otherwise
    function isSelectorRegisteredWithFacet(address facet, bytes4 selector) external view returns (bool isRegistered);

    /// @notice Returns the current version of the registry
    /// @return version The current version number
    function getCurrentVersion() external view returns (uint256 version);

    /// @notice Validates a selector in a single call for the Garden fallback
    /// @dev Consolidates isSelectorRegistered, isSelectorRegisteredWithFacet,
    ///      getModuleIdBySelector, and isModuleAllowedForGardenType into one call
    /// @param selector The function selector to validate
    /// @param gardenType The garden type to check module allowance against
    /// @return registeredFacet The facet address the selector is registered with (address(0) if not registered)
    /// @return moduleAllowed Whether the selector's module is allowed for the given garden type
    function validateSelector(
        bytes4 selector,
        bytes32 gardenType
    )
        external
        view
        returns (address registeredFacet, bool moduleAllowed);
}
