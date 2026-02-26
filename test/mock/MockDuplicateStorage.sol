// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

/**
 * @title MockDuplicateStorage
 * @author BLOK Capital DAO
 * @notice Mock storage library that deliberately uses the same name as GmxV2Storage
 *         to produce a storage slot collision. Used by StorageSlotCollisionGuard tests.
 * @dev DO NOT use this in production. This exists solely to verify that the
 *      collision guard test catches duplicate type(X).name declarations.
 */
library GmxV2Storage {
    struct Layout {
        uint256 fakeData;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = keccak256(bytes(type(GmxV2Storage).name)) & ~bytes32(uint256(0xff));
        assembly {
            l.slot := position
        }
    }
}
