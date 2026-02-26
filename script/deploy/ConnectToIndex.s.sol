//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";

contract ConnectToIndex is BaseScript {
    function run() public broadcaster {
        setUp();

        IndexFacet(0xc1B38456bfEF0AD6c92D95d853bc97b5Af182133)
            .connectToIndex(0xe1E23cF723e3715a8043486CBFCBB415918f064d);
    }
}
