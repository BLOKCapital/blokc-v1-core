// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title PoolRegistry
    @author BLOK Capital DAO
    @notice Concrete owner-controlled registry for liquidity pools.
    @dev Inherits from OpenZeppelin Ownable for ownership management.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PoolRegistry is Initializable, OwnableUpgradeable, IPoolRegistry {
    // set of pool addresses
    address[] private pools;
    // mapping to metadata
    mapping(address pool => PoolInfo) poolInfo;

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize owner (call via proxy only).
    /// @param initialOwner owner of the registry (use address(0) to keep msg.sender as owner)
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    /// @inheritdoc IPoolRegistry
    function addPool(address poolAddress, string calldata pairName, string calldata dexId) external {
        pools.push(poolAddress);
        poolInfo[poolAddress] = PoolInfo({ pairName: pairName, dexId: dexId });
    }

    /// @inheritdoc IPoolRegistry
    function removePool(address poolAddress) external {
        uint256 length = pools.length;
        for (uint256 i; i < length;) {
            if (pools[i] == poolAddress) {
                pools[i] = pools[length - 1];
                pools.pop();
                delete poolInfo[poolAddress];
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IPoolRegistry
    function poolDetails(address poolAddress) external view returns (string memory pairName, string memory dexId) {
        PoolInfo memory info = poolInfo[poolAddress];
        return (info.pairName, info.dexId);
    }

    /// @inheritdoc IPoolRegistry
    function poolAddresses() external view returns (address[] memory) {
        return pools;
    }

    /// @inheritdoc IPoolRegistry
    function isPoolRegistered(address poolAddress) external view returns (bool) {
        return bytes(poolInfo[poolAddress].pairName).length != 0;
    }
}
