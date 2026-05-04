//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IndexFactory } from "src/indices/IndexFactory.sol";

contract DeployBlokc10New is BaseScript {
    address INDEX_FACTORY_ADDRESS = 0x91da26BF1a4adDa42355B80502785d3F026d7074;
    address MARKET_CAP_WEIGHTED = 0xaE505b029C9BC7d415Ed38b420585A02363D5d03;

    function run() public broadcaster {
        setUp();
        IndexFactory indexFactory = IndexFactory(INDEX_FACTORY_ADDRESS);

        bytes32[] memory symbols10 = new bytes32[](10);
        symbols10[0] = bytes32("LINK");
        symbols10[1] = bytes32("UNI");
        symbols10[2] = bytes32("ARB");
        symbols10[3] = bytes32("AAVE");
        symbols10[4] = bytes32("DAI");
        symbols10[5] = bytes32("GRT");
        symbols10[6] = bytes32("CRV");
        symbols10[7] = bytes32("ZRO");
        symbols10[8] = bytes32("ETH");
        symbols10[9] = bytes32("PENDLE");

        indexFactory.deployIndex("Blokc10New", MARKET_CAP_WEIGHTED, symbols10);
    }
}
