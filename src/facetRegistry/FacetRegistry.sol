// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title Facet Registry
    @author BLOK Capital DAO
    @notice Registry that registers facets for the DAO

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";

error FacetRegistry_FacetIsNotContract(address facetAddress);

error FacetRegistry_SelectorArrayEmpty();

error FacetRegistry_IncorrectFacetCutAction(IDiamondCut.FacetCutAction);

error FacetRegistry_FacetAddressIsZero();

error FacetRegistry_CannotAddFunctionThatAlreadyExists(bytes4 selector);

error FacetRegistry_CannotReplaceFunctionWithSameFunction(address facetAddress, bytes4 selector);

error FacetRegistry_RemoveFacetAddressMustBeZero(address facetAddress);

error FacetRegistry_CannotRemoveFunctionThatDoesNotExist(address facetAddress, bytes4 selector);

error FacetRegistry_CannotRemoveImmutableFunction(address facetAddress, bytes4 selector);

contract FacetRegistry is Initializable, OwnableUpgradeable, IFacetRegistry {
    uint256 internal currentVersion;
    address[] internal facetAddresses;
    mapping(bytes4 => FacetAddressAndPosition) internal selectorToFacetAndPosition;
    mapping(address => FacetFunctionSelectors) internal facetFunctionSelectors;

    /// @notice Prevent implementation from being initialized directly.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize owner (call via proxy only).
    /// @param initialOwner owner of the registry (use address(0) to keep msg.sender as owner)
    // function initializeV2(address initialOwner) public reinitializer(2) {
    function initialize(address initialOwner) public initializer {
        _transferOwnership(initialOwner);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external {
        if (_functionSelectors.length == 0) {
            revert FacetRegistry_SelectorArrayEmpty();
        }
        if (_facetAddress == address(0)) {
            revert FacetRegistry_FacetAddressIsZero();
        }
        uint96 selectorPosition = uint96(facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert FacetRegistry_CannotAddFunctionThatAlreadyExists(selector);
            }
            addFunction(selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
        currentVersion++;
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external {
        if (_functionSelectors.length == 0) {
            revert FacetRegistry_SelectorArrayEmpty();
        }

        if (_facetAddress == address(0)) {
            revert FacetRegistry_FacetAddressIsZero();
        }
        uint96 selectorPosition = uint96(facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == _facetAddress) {
                revert FacetRegistry_CannotReplaceFunctionWithSameFunction(oldFacetAddress, selector);
            }
            removeFunction(oldFacetAddress, selector);
            addFunction(selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
        currentVersion++;
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external {
        if (_functionSelectors.length == 0) {
            revert FacetRegistry_SelectorArrayEmpty();
        }
        // if function does not exist then do nothing and return
        if (_facetAddress != address(0)) {
            revert FacetRegistry_RemoveFacetAddressMustBeZero(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(oldFacetAddress, selector);
        }
        currentVersion++;
    }

    function addFacet(address _facetAddress) internal {
        if (_facetAddress.code.length == 0) {
            revert FacetRegistry_FacetIsNotContract(_facetAddress);
        }
        facetFunctionSelectors[_facetAddress].facetAddressPosition = facetAddresses.length;
        facetAddresses.push(_facetAddress);
    }

    function addFunction(bytes4 _selector, uint96 _selectorPosition, address _facetAddress) internal {
        selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(address _facetAddress, bytes4 _selector) internal {
        if (_facetAddress == address(0)) {
            revert FacetRegistry_CannotRemoveFunctionThatDoesNotExist(_facetAddress, _selector);
        }
        // an immutable function is a function defined directly in a diamond
        if (_facetAddress == address(this)) {
            revert FacetRegistry_CannotRemoveImmutableFunction(_facetAddress, _selector);
        }
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = facetAddresses.length - 1;
            uint256 facetAddressPosition = facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = facetAddresses[lastFacetAddressPosition];
                facetAddresses[facetAddressPosition] = lastFacetAddress;
                facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            facetAddresses.pop();
            delete facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function getFacets() external view returns (Facet[] memory facets_) {
        uint256 numFacets = facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    function getFacetFunctionSelectors(address _facet) external view returns (bytes4[] memory selectors) {
        selectors = facetFunctionSelectors[_facet].functionSelectors;
    }

    function getFacetAddresses() external view returns (address[] memory facetAddresses_) {
        facetAddresses_ = facetAddresses;
    }

    function getFacetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {
        facetAddress_ = selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    /// @inheritdoc IFacetRegistry
    function isFacetRegistered(address _facet) external view returns (bool) {
        uint256 numFacets = facetAddresses.length;
        for (uint256 i; i < numFacets; i++) {
            if (_facet == facetAddresses[i]) {
                return true;
            }
        }
        return false;
    }

    /// @inheritdoc IFacetRegistry
    function isSelectorRegistered(address _facet, bytes4 _functionSelector) external view returns (bool) {
        address facetAddress_ = selectorToFacetAndPosition[_functionSelector].facetAddress;
        if (facetAddress_ == _facet) {
            return true;
        }
        return false;
    }

    /// @inheritdoc IFacetRegistry
    function getCurrentVersion() external view returns (uint256) {
        return currentVersion;
    }
}
