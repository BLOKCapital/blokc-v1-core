//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title IndexFactory
    @author BLOK Capital DAO
    @notice Factory contract that deploys new index contracts.
    @dev This contract deploys new index contracts using the Index contract.
         Index calculations can be registered and removed by the owner only.
         Assets can be registered and removed by the owner only.

################################################################################*/

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";
import { Index } from "src/BlokcIndices/Index.sol";
import { IndexCalculationRegistry } from "src/BlokcIndices/IndexCalculationRegistry.sol";
import { IndexComponentRegistry } from "src/BlokcIndices/IndexComponentRegistry.sol";

error IndexFactory_InvalidInitialOwner(address owner);
error IndexFactory_InvalidIndexAddress(address indexAddress);
error IndexFactory_IndexAlreadyRegistered(address indexAddress);
error IndexFactory_IndexNotRegistered(address indexAddress);
error IndexFactory_IndexCalculationNotRegistered(address indexCalculationAddress);
error IndexFactory_IndexCalculationAlreadyRegistered(address indexCalculationAddress);
error IndexFactory_ComponentNotRegistered(address component);
error IndexFactory_InvalidIndexCalculationRegistryAddress(address indexCalculationRegistryAddress);
error IndexFactory_InvalidComponentRegistryAddress(address componentRegistryAddress);
error IndexFactory_GardenAlreadyConnectedToIndex(address garden, address indexAddress);
error IndexFactory_GardenNotConnectedToIndex(address garden, address indexAddress);
error IndexFactory_TooManyComponents(uint256 componentCount, uint256 maxComponents);

contract IndexFactory is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant MAX_COMPONENTS_PER_INDEX = 250;

    event GardenConnectedToIndex(address indexed garden, address indexed indexAddress);
    event GardenDisconnectedFromIndex(address indexed garden, address indexed indexAddress);

    struct IndexInfo {
        string name;
        uint256 id;
        address[] components;
        address indexAddress;
        address indexCalculationAddress;
        uint256 createdAt;
    }

    address private immutable i_indexCalculationRegistry;
    address private immutable i_componentRegistry;

    uint256 private _indexIdCounter;

    mapping(address indexAddress => IndexInfo indexInfo) private _indexInfo;

    EnumerableSet.AddressSet private _indexAddresses;

    constructor(
        address initialOwner,
        address indexCalculationRegistry,
        address componentRegistry
    )
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert IndexFactory_InvalidInitialOwner(initialOwner);
        if (indexCalculationRegistry == address(0)) {
            revert IndexFactory_InvalidIndexCalculationRegistryAddress(indexCalculationRegistry);
        }
        if (componentRegistry == address(0)) {
            revert IndexFactory_InvalidComponentRegistryAddress(componentRegistry);
        }
        i_indexCalculationRegistry = indexCalculationRegistry;
        i_componentRegistry = componentRegistry;
    }

    modifier checkCalculationRegistered(address indexCalculationAddress) {
        if (!IndexCalculationRegistry(i_indexCalculationRegistry).isIndexCalculationRegistered(indexCalculationAddress))
        {
            revert IndexFactory_IndexCalculationNotRegistered(indexCalculationAddress);
        }
        _;
    }

    modifier checkComponentsRegistered(address[] memory components) {
        for (uint256 i = 0; i < components.length; i++) {
            if (!IndexComponentRegistry(i_componentRegistry).isComponentRegistered(components[i])) {
                revert IndexFactory_ComponentNotRegistered(components[i]);
            }
        }
        _;
    }

    function deployIndex(
        string calldata name,
        address indexCalculationAddress,
        address[] memory components
    )
        external
        onlyOwner
        checkCalculationRegistered(indexCalculationAddress)
        checkComponentsRegistered(components)
        returns (address indexAddress)
    {
        if (components.length == 0 || components.length > MAX_COMPONENTS_PER_INDEX) {
            revert IndexFactory_TooManyComponents(components.length, MAX_COMPONENTS_PER_INDEX);
        }
        if (bytes(name).length == 0) {
            revert IndexFactory_InvalidIndexAddress(address(0));
        }

        indexAddress = address(new Index(address(this), indexCalculationAddress, i_componentRegistry, components));
        _registerIndex(indexAddress, name, indexCalculationAddress, components);
        return indexAddress;
    }

    function removeIndex(address indexAddress) external onlyOwner {
        if (!_indexAddresses.contains(indexAddress)) revert IndexFactory_IndexNotRegistered(indexAddress);
        _indexAddresses.remove(indexAddress);

        delete _indexInfo[indexAddress];
    }

    function getIndexInfo(address indexAddress) external view returns (IndexInfo memory) {
        return _indexInfo[indexAddress];
    }

    function getAllIndices() public view returns (address[] memory) {
        return _indexAddresses.values();
    }

    function getAllIndexInfos() external view returns (IndexInfo[] memory) {
        IndexInfo[] memory indexInfos = new IndexInfo[](_indexAddresses.length());
        for (uint256 i = 0; i < _indexAddresses.length(); i++) {
            indexInfos[i] = _indexInfo[_indexAddresses.at(i)];
        }
        return indexInfos;
    }

    function isIndexRegistered(address indexAddress) external view returns (bool) {
        return _indexAddresses.contains(indexAddress);
    }

    function _registerIndex(
        address indexAddress,
        string calldata name,
        address indexCalculationAddress,
        address[] memory components
    )
        internal
    {
        if (_indexAddresses.contains(indexAddress)) revert IndexFactory_IndexAlreadyRegistered(indexAddress);
        _indexIdCounter++;
        _indexInfo[indexAddress] = IndexInfo({
            name: name,
            id: _indexIdCounter,
            indexAddress: indexAddress,
            components: components,
            indexCalculationAddress: indexCalculationAddress,
            createdAt: block.timestamp
        });
        _indexAddresses.add(indexAddress);
    }
}
