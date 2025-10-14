// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { ISBTCollection } from "src/interfaces/ISBTCollection.sol";

error SbtFacet_AlreadyHasSBT();

contract SbtFacet {
    // The collection that will be used to mint SBTs for diamond owners.
    // This is intentionally a constant as requested. Replace with actual deployed collection address.
    address public constant SBT_COLLECTION = address(0x0000000000000000000000000000000000000000);

    event SbtMinted(address indexed to, uint256 tokenId);

    /// @notice Mint a soulbound token for msg.sender in the configured collection.
    /// @dev Each address may own at most one token from this collection as enforced by checking balanceOf.
    function mintSbt() external returns (uint256) {
        address to = msg.sender;

        ISBTCollection collection = ISBTCollection(SBT_COLLECTION);

        // restrict one SBT per address
        if (collection.balanceOf(to) > 0) revert SbtFacet_AlreadyHasSBT();

        uint256 tokenId = collection.mint(to);
        // optional: implementations may return 0 for tokenId; still emit event
        emit SbtMinted(to, tokenId);
        return tokenId;
    }
}
