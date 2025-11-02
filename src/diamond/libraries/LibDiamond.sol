// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * \
 * Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 * /*****************************************************************************
 */
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

error DiamondCut_FacetIsNotContract(address facetAddress);

error DiamondCut_SelectorArrayEmpty();

error CallerNotOwner(address caller, address owner);

error DiamondCut_IncorrectFacetCutAction(IDiamondCut.FacetCutAction);

error DiamondCut_FacetAddressIsZero();

error DiamondCut_CannotAddFunctionThatAlreadyExists(bytes4 selector);

error DiamondCut_CannotReplaceFunctionWithSameFunction(address facetAddress, bytes4 selector);

error DiamondCut_RemoveFacetAddressMustBeZero(address facetAddress);

error DiamondCut_CannotRemoveFunctionThatDoesNotExist(address facetAddress, bytes4 selector);

error DiamondCut_CannotRemoveImmutableFunction(address facetAddress, bytes4 selector);

error DiamondCut_InitIsNotContract(address init);

error DiamondCut_FacetRegistryNotSet();

error DiamondCut_FacetNotRegistered(address facetAddress);

error DiamondCut_SelectorNotRegistered(address facetAddress, bytes4 selector);

error DiamondCut_SelectorRegisteredCannotRemove(address facetAddress, bytes4 selector);

library LibDiamond {
    // 32 bytes keccak hash of a string to use as a diamond storage location.
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
        // Registry of facets and selectors allowed to be added to the Diamond
        address facetRegistry;
        // Registry of the Liquidity Pools
        address liquidityPoolRegistry;
        // Kill switch
        address protocolStatus;
        // Version
        uint256 currentVersion;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        // assigns struct storage slot to the storage position
        assembly {
            ds.slot := position
        }
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        address owner = diamondStorage().contractOwner;
        if (msg.sender != owner) {
            revert CallerNotOwner(msg.sender, owner);
        }
    }

    function facetRegistry() internal view returns (address facetRegistry_) {
        facetRegistry_ = diamondStorage().facetRegistry;
    }

    function liquidityPoolRegistry() internal view returns (address liquidityPoolRegistry_) {
        liquidityPoolRegistry_ = diamondStorage().liquidityPoolRegistry;
    }

    function currentVersion() internal view returns (uint256 currentVersion_) {
        currentVersion_ = diamondStorage().currentVersion;
    }

    function setCurrentVersion(uint256 _newVersion) internal {
        DiamondStorage storage ds = diamondStorage();
        ds.currentVersion = _newVersion;
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    // Internal function version of diamondCut
    function diamondCut(IDiamondCut.FacetCut[] memory _diamondCut, address _init, bytes memory _calldata) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert DiamondCut_IncorrectFacetCutAction(action);
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert DiamondCut_SelectorArrayEmpty();
        }
        DiamondStorage storage ds = diamondStorage();
        if (_facetAddress == address(0)) {
            revert DiamondCut_FacetAddressIsZero();
        }
        address registry = facetRegistry();
        if (registry == address(0)) {
            revert DiamondCut_FacetRegistryNotSet();
        }
        // ensure facet is registered in the FacetRegistry
        if (!IFacetRegistry(registry).isFacetRegistered(_facetAddress)) {
            revert DiamondCut_FacetNotRegistered(_facetAddress);
        }
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            // ensure selector is registered for the facet in the FacetRegistry
            if (!IFacetRegistry(registry).isSelectorRegistered(_facetAddress, selector)) {
                revert DiamondCut_SelectorNotRegistered(_facetAddress, selector);
            }
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert DiamondCut_CannotAddFunctionThatAlreadyExists(selector);
            }
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert DiamondCut_SelectorArrayEmpty();
        }
        DiamondStorage storage ds = diamondStorage();

        if (_facetAddress == address(0)) {
            revert DiamondCut_FacetAddressIsZero();
        }
        address registry = facetRegistry();
        if (registry == address(0)) {
            revert DiamondCut_FacetRegistryNotSet();
        }
        // ensure facet is registered in the FacetRegistry
        if (!IFacetRegistry(registry).isFacetRegistered(_facetAddress)) {
            revert DiamondCut_FacetNotRegistered(_facetAddress);
        }
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            // ensure selector is registered for the facet in the FacetRegistry
            if (!IFacetRegistry(registry).isSelectorRegistered(_facetAddress, selector)) {
                revert DiamondCut_SelectorNotRegistered(_facetAddress, selector);
            }
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == _facetAddress) {
                revert DiamondCut_CannotReplaceFunctionWithSameFunction(oldFacetAddress, selector);
            }
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert DiamondCut_SelectorArrayEmpty();
        }
        DiamondStorage storage ds = diamondStorage();
        // if function does not exist then do nothing and return
        if (_facetAddress != address(0)) {
            revert DiamondCut_RemoveFacetAddressMustBeZero(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        if (_facetAddress.code.length == 0) {
            revert DiamondCut_FacetIsNotContract(_facetAddress);
        }
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }

    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    )
        internal
    {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {
        if (_facetAddress == address(0)) {
            revert DiamondCut_CannotRemoveFunctionThatDoesNotExist(_facetAddress, _selector);
        }
        // an immutable function is a function defined directly in a diamond
        if (_facetAddress == address(this)) {
            revert DiamondCut_CannotRemoveImmutableFunction(_facetAddress, _selector);
        }
        address registry = facetRegistry();
        if (registry == address(0)) {
            revert DiamondCut_FacetRegistryNotSet();
        }
        // ensure selector is registered for the facet in the FacetRegistry
        if (IFacetRegistry(registry).isSelectorRegistered(_facetAddress, _selector)) {
            revert DiamondCut_SelectorRegisteredCannotRemove(_facetAddress, _selector);
        }
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address init, bytes memory initData) internal {
        // if no init provided, nothing to do
        if (init == address(0)) return;

        // init must be a contract
        if (init.code.length == 0) {
            revert DiamondCut_InitIsNotContract(init);
        }

        // delegatecall into init contract with provided calldata
        Address.functionDelegateCall(init, initData);
    }
}
