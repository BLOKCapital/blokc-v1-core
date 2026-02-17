// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title LibStorageSlot
/// @author BLOK Capital DAO
/// @notice Centralised helper for deriving EIP-7201 compliant storage slot positions.
/// @dev All storage libraries in the protocol MUST use this function to derive
///      their storage slot. This ensures:
///        1. Slots are deterministically tied to the library name via type(X).name
///        2. The low byte is masked to avoid collision with Solidity's native layout
///        3. The derivation logic lives in one place for auditability
library LibStorageSlot {
    /// @notice Derives an EIP-7201 compliant storage slot from a library name.
    /// @dev formula: keccak256(bytes(name)) & ~bytes32(uint256(0xff))
    ///      The low byte is zeroed to guarantee the slot cannot collide with
    ///      Solidity's sequential storage layout (slots 0, 1, 2, ...) or
    ///      keccak256-based mapping/array slots.
    /// @param name The library name, typically passed as type(LibName).name
    /// @return slot The derived storage slot position
    function deriveStorageSlot(string memory name) internal pure returns (bytes32 slot) {
        slot = keccak256(bytes(name)) & ~bytes32(uint256(0xff));
    }
}
