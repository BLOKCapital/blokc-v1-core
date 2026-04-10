//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IndexFactory } from "src/indices/IndexFactory.sol";

contract DeployBlokc5New is BaseScript {
    address INDEX_FACTORY_ADDRESS = 0x91da26BF1a4adDa42355B80502785d3F026d7074;
    address MARKET_CAP_WEIGHTED = 0xaE505b029C9BC7d415Ed38b420585A02363D5d03;

    function run() public broadcaster {
        setUp();
        IndexFactory indexFactory = IndexFactory(INDEX_FACTORY_ADDRESS);

        bytes32[] memory symbols5 = new bytes32[](5);
        symbols5[0] = bytes32("LINK");
        symbols5[1] = bytes32("UNI");
        symbols5[2] = bytes32("ARB");
        symbols5[3] = bytes32("AAVE");
        symbols5[4] = bytes32("DAI");

        indexFactory.deployIndex("Blokc5Alt", MARKET_CAP_WEIGHTED, symbols5);
    }
}
