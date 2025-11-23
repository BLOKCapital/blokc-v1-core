//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title Index
    @author BLOK Capital DAO
    @notice Implementation of the Index contract

################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IndexComponentRegistry } from "src/BlokcIndices/IndexComponentRegistry.sol";

error Index_InvalidInitialOwner(address initialOwner);
error Index_InvalidIndexCalculationAddress(address indexCalculationAddress);
error Index_InvalidIndexComponentRegistryAddress(address indexComponentRegistryAddress);
error Index_WeightsMismatch(uint256 weightsLength, uint256 componentAddressesLength);
error Index_RebalanceTooSoon();
error Index_GardenAlreadyConnected(address garden);
error Index_GardenNotConnected(address garden);
error Index_ComponentNotRegistered(address componentAddress);

contract Index is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant REBALANCE_INTERVAL = 1 hours;

    IIndexCalculation public immutable indexCalculation;
    IndexComponentRegistry public immutable indexComponentRegistry;

    mapping(address => uint256) private _componentWeights;

    uint256 private _lastRebalanceTimestamp;

    EnumerableSet.AddressSet private _componentAddresses;
    EnumerableSet.AddressSet private _connectedGardens;

    constructor(
        address initialOwner,
        address indexCalculationAddress,
        address indexComponentRegistryAddress,
        address[] memory componentAddresses
    )
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert Index_InvalidInitialOwner(initialOwner);
        if (indexCalculationAddress == address(0)) {
            revert Index_InvalidIndexCalculationAddress(indexCalculationAddress);
        }
        if (indexComponentRegistryAddress == address(0)) {
            revert Index_InvalidIndexComponentRegistryAddress(indexComponentRegistryAddress);
        }

        indexCalculation = IIndexCalculation(indexCalculationAddress);
        indexComponentRegistry = IndexComponentRegistry(indexComponentRegistryAddress);

        for (uint256 i = 0; i < componentAddresses.length; i++) {
            if (!indexComponentRegistry.isComponentRegistered(componentAddresses[i])) {
                revert Index_ComponentNotRegistered(componentAddresses[i]);
            }
            _componentAddresses.add(componentAddresses[i]);
        }

        _rebalance();
    }

    function rebalance() external {
        _rebalance();
    }

    //=======================================================================
    // External Functions
    //=======================================================================

    function connectGardenToIndex() external {
        if (_connectedGardens.contains(msg.sender)) {
            revert Index_GardenAlreadyConnected(msg.sender);
        }

        _connectedGardens.add(msg.sender);
    }

    function disconnectGardenFromIndex() external {
        if (!_connectedGardens.contains(msg.sender)) {
            revert Index_GardenNotConnected(msg.sender);
        }
        _connectedGardens.remove(msg.sender);
    }

    //=======================================================================
    // View Functions
    //=======================================================================

    function getWeights() external view returns (address[] memory componentAddresses, uint256[] memory weights) {
        componentAddresses = new address[](_componentAddresses.length());
        weights = new uint256[](_componentAddresses.length());
        for (uint256 i = 0; i < _componentAddresses.length(); i++) {
            componentAddresses[i] = _componentAddresses.at(i);
            weights[i] = _componentWeights[componentAddresses[i]];
        }
    }

    function getLastUpdatedTimestamp() external view returns (uint256) {
        return _lastRebalanceTimestamp;
    }

    function getConnectedGardens() external view returns (address[] memory) {
        return _connectedGardens.values();
    }

    //=======================================================================
    // Internal Functions
    //=======================================================================

    function _rebalance() internal {
        if (block.timestamp - _lastRebalanceTimestamp < REBALANCE_INTERVAL) {
            revert Index_RebalanceTooSoon();
        }

        // Create array from EnumerableSet
        address[] memory componentAddresses = new address[](_componentAddresses.length());
        for (uint256 i = 0; i < _componentAddresses.length(); i++) {
            componentAddresses[i] = _componentAddresses.at(i);
        }

        uint256[] memory weights = indexCalculation.getWeights(componentAddresses);

        if (weights.length != componentAddresses.length) {
            revert Index_WeightsMismatch(weights.length, componentAddresses.length);
        }

        for (uint256 i = 0; i < componentAddresses.length; i++) {
            _componentWeights[componentAddresses[i]] = weights[i];
        }

        _lastRebalanceTimestamp = block.timestamp;
    }
}
