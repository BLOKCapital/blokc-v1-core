//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title IndexRegistry
    @author BLOK Capital DAO
    @notice Registry contract that manages the registration and tracking of indices.
    @dev This contract uses the Transparent Proxy pattern and is upgradeable.
         It uses OpenZeppelin's upgradeable contracts library for security and reliability.
         Indices can be added and removed by the owner only.

################################################################################*/

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
