//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import {
    RewardCollectionFacet
} from "src/garden/facets/utilityFacets/arbitrumOne/rewardCollection/RewardCollectionFacet.sol";

contract MintNFT is BaseScript {
    function run() public broadcaster {
        setUp();
        address garden = 0xe4A134aAFac77585d0d2D5623a676a8EE2727A2e;
        RewardCollectionFacet(garden).mint(1);
        console2.log("NFT minted");
    }
}
