//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { WithdrawFacet } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WithdrawUsdcScript is BaseScript {
    address internal constant GARDEN_ADDRESS = 0xc1B38456bfEF0AD6c92D95d853bc97b5Af182133;

    function run() external broadcaster {
        IERC20 usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831); // Arbitrum One USDC
        uint256 amount = usdc.balanceOf(GARDEN_ADDRESS);
        WithdrawFacet(GARDEN_ADDRESS).withdrawUsdc(amount);
    }
}
