//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title IndexCalculationRegistry
    @author BLOK Capital DAO
    @notice Registry contract that manages the registration and tracking of index calculations.

################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

error IndexCalculationRegistry_InvalidInitialOwner(address initialOwner);
error IndexCalculationRegistry_InvalidIndexCalculationAddress(address indexCalculationAddress);
error IndexCalculationRegistry_IndexCalculationAlreadyRegistered(address indexCalculationAddress);
error IndexCalculationRegistry_IndexCalculationNotRegistered(address indexCalculationAddress);

contract IndexCalculationRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private _indexCalculationIdCounter;
    EnumerableSet.AddressSet private _indexCalculationAddresses;
    mapping(address indexCalculationAddress => IndexCalculationInfo indexCalculationInfo) private _indexCalculationInfo;

    struct IndexCalculationInfo {
        uint256 id;
        address indexCalculationAddress;
        uint256 registeredAt;
    }

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert IndexCalculationRegistry_InvalidInitialOwner(initialOwner);
    }

    function registerIndexCalculation(address indexCalculationAddress) external onlyOwner {
        if (_indexCalculationAddresses.contains(indexCalculationAddress)) {
            revert IndexCalculationRegistry_IndexCalculationAlreadyRegistered(indexCalculationAddress);
        }
        _indexCalculationIdCounter++;
        _indexCalculationInfo[indexCalculationAddress] = IndexCalculationInfo({
            id: _indexCalculationIdCounter,
            indexCalculationAddress: indexCalculationAddress,
            registeredAt: block.timestamp
        });
        _indexCalculationAddresses.add(indexCalculationAddress);
    }

    function unregisterIndexCalculation(address indexCalculationAddress) external onlyOwner {
        if (!_indexCalculationAddresses.contains(indexCalculationAddress)) {
            revert IndexCalculationRegistry_IndexCalculationNotRegistered(indexCalculationAddress);
        }
        _indexCalculationAddresses.remove(indexCalculationAddress);
        delete _indexCalculationInfo[indexCalculationAddress];
    }

    function getIndexCalculationInfo(address indexCalculationAddress)
        external
        view
        returns (IndexCalculationInfo memory)
    {
        return _indexCalculationInfo[indexCalculationAddress];
    }

    function getIndexCalculationAddresses() external view returns (address[] memory) {
        return _indexCalculationAddresses.values();
    }

    function isIndexCalculationRegistered(address indexCalculationAddress) external view returns (bool) {
        return _indexCalculationAddresses.contains(indexCalculationAddress);
    }
}
