// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when initial owner address is zero
/// @param initialOwner The invalid owner address
error IndexCalculationRegistry_InvalidInitialOwner(address initialOwner);

/// @notice Thrown when calculation contract address is invalid
/// @param indexCalculationAddress The invalid calculation address
error IndexCalculationRegistry_InvalidIndexCalculationAddress(address indexCalculationAddress);

/// @notice Thrown when attempting to register an already registered calculation
/// @param indexCalculationAddress The already registered calculation address
error IndexCalculationRegistry_IndexCalculationAlreadyRegistered(address indexCalculationAddress);

/// @notice Thrown when attempting to operate on an unregistered calculation
/// @param indexCalculationAddress The unregistered calculation address
error IndexCalculationRegistry_IndexCalculationNotRegistered(address indexCalculationAddress);

/**
 * @title IndexCalculationRegistry
 * @notice Registry contract for managing index calculation strategies. This contract allows the owner to register and
 * unregister index calculation contracts, which can be used by Index contracts to determine component weights during
 * rebalancing. The registry maintains a mapping of registered calculation addresses to their metadata, including a
 * unique ID and registration timestamp. It also provides functions for retrieving registered calculations and their
 * metadata, as well as checking if a calculation is registered. The contract uses OpenZeppelin's Ownable for access
 * control and EnumerableSet for efficient management of registered calculation addresses.
 */
contract IndexCalculationRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Counter for assigning unique IDs to registered calculations
    /// @dev Incremented for each new registration
    uint256 private _indexCalculationIdCounter;

    /// @notice Set of all registered calculation contract addresses
    /// @dev Provides efficient lookup and iteration
    EnumerableSet.AddressSet private _indexCalculationAddresses;

    /// @notice Mapping of calculation addresses to their metadata
    /// @dev Stores registration info including ID and timestamp
    mapping(address indexCalculationAddress => IndexCalculationInfo indexCalculationInfo) private _indexCalculationInfo;

    /// @notice Metadata for a registered index calculation strategy
    /// @param id Unique identifier assigned during registration
    /// @param indexCalculationAddress Address of the calculation contract
    /// @param registeredAt Block timestamp when the calculation was registered
    struct IndexCalculationInfo {
        uint256 id;
        address indexCalculationAddress;
        uint256 registeredAt;
    }

    /// @notice Emitted when a new index calculation strategy is registered
    /// @param indexCalculationAddress Address of the registered calculation contract
    /// @param id Unique ID assigned to this calculation
    event IndexCalculationRegistered(address indexed indexCalculationAddress, uint256 id);

    /// @notice Emitted when an index calculation strategy is unregistered
    /// @param indexCalculationAddress Address of the unregistered calculation contract
    event IndexCalculationUnregistered(address indexed indexCalculationAddress);

    /// @notice Constructs the IndexCalculationRegistry
    /// @param initialOwner Address of the contract owner
    /// @dev Validates owner is not zero address
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert IndexCalculationRegistry_InvalidInitialOwner(initialOwner);
    }

    /// @notice Registers a new index calculation strategy
    /// @param indexCalculationAddress Address of the calculation contract to register
    /// @dev Only callable by owner. Assigns a unique ID and records registration timestamp
    function registerIndexCalculation(address indexCalculationAddress) external onlyOwner {
        if (indexCalculationAddress == address(0)) {
            revert IndexCalculationRegistry_InvalidIndexCalculationAddress(indexCalculationAddress);
        }
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
        emit IndexCalculationRegistered(indexCalculationAddress, _indexCalculationIdCounter);
    }

    /// @notice Unregisters an index calculation strategy
    /// @param indexCalculationAddress Address of the calculation contract to unregister
    /// @dev Only callable by owner. Removes calculation from whitelist
    function unregisterIndexCalculation(address indexCalculationAddress) external onlyOwner {
        if (!_indexCalculationAddresses.contains(indexCalculationAddress)) {
            revert IndexCalculationRegistry_IndexCalculationNotRegistered(indexCalculationAddress);
        }
        emit IndexCalculationUnregistered(indexCalculationAddress);
        _indexCalculationAddresses.remove(indexCalculationAddress);
        delete _indexCalculationInfo[indexCalculationAddress];
    }

    /// @notice Retrieves metadata for a registered calculation
    /// @param indexCalculationAddress Address of the calculation contract
    /// @return IndexCalculationInfo struct containing ID, address, and registration timestamp
    function getIndexCalculationInfo(address indexCalculationAddress)
        external
        view
        returns (IndexCalculationInfo memory)
    {
        return _indexCalculationInfo[indexCalculationAddress];
    }

    /// @notice Returns all registered calculation contract addresses
    /// @return Array of registered calculation addresses
    function getIndexCalculationAddresses() external view returns (address[] memory) {
        return _indexCalculationAddresses.values();
    }

    /// @notice Checks if a calculation contract is registered
    /// @param indexCalculationAddress Address to check
    /// @return True if the calculation is registered, false otherwise
    function isIndexCalculationRegistered(address indexCalculationAddress) external view returns (bool) {
        return _indexCalculationAddresses.contains(indexCalculationAddress);
    }
}
