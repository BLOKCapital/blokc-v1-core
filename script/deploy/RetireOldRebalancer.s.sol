// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title RetireOldRebalancer
 * @notice Phase-4 migration script: removes the OLD indices from the OLD rebalancer's type
 *         maps, permanently disabling its cumulativeRebalance (NoIndicesRegistered). Run only
 *         AFTER every garden has been flipped to the new stack (phase 3) — this is the final
 *         kill switch, and it is what makes the un-revocable old allowances safe.
 *
 *         The old contracts stay on-chain untouched.
 *
 *         Env:
 *           OLD_REBALANCER   the pre-migration Rebalancer address
 *           OLD_INDEX_BLOKC2 / OLD_INDEX_BLOKC5 / OLD_INDEX_BLOKC10
 */
contract RetireOldRebalancer is BaseScript {
    function run() public broadcaster {
        setUp();
        address oldRebalancer = vm.envAddress("OLD_REBALANCER");
        address oldBlokc2 = vm.envAddress("OLD_INDEX_BLOKC2");
        address oldBlokc5 = vm.envAddress("OLD_INDEX_BLOKC5");
        address oldBlokc10 = vm.envAddress("OLD_INDEX_BLOKC10");

        bytes32 t2 = keccak256("BLOKC2");
        bytes32 t5 = keccak256("BLOKC5");
        bytes32 t10 = keccak256("BLOKC10");

        (bool ok2,) = oldRebalancer.call(abi.encodeWithSignature("removeIndexFromType(bytes32,address)", t2, oldBlokc2));
        require(ok2, "removeIndexFromType BLOKC2 failed");
        console2.log("Removed old BLOKC2 index from old rebalancer");

        (bool ok5,) = oldRebalancer.call(abi.encodeWithSignature("removeIndexFromType(bytes32,address)", t5, oldBlokc5));
        require(ok5, "removeIndexFromType BLOKC5 failed");
        console2.log("Removed old BLOKC5 index from old rebalancer");

        (bool ok10,) =
            oldRebalancer.call(abi.encodeWithSignature("removeIndexFromType(bytes32,address)", t10, oldBlokc10));
        require(ok10, "removeIndexFromType BLOKC10 failed");
        console2.log("Removed old BLOKC10 index from old rebalancer");

        // Post-verify: every type map is empty — cumulativeRebalance can never run again there
        _verifyEmpty(oldRebalancer, t2, "BLOKC2");
        _verifyEmpty(oldRebalancer, t5, "BLOKC5");
        _verifyEmpty(oldRebalancer, t10, "BLOKC10");
        console2.log("Old rebalancer fully retired (all index types empty)");
    }

    function _verifyEmpty(address rebalancer, bytes32 indexType, string memory label) internal {
        (bool ok, bytes memory ret) =
            rebalancer.call(abi.encodeWithSignature("getIndexCountForType(bytes32)", indexType));
        require(ok, "getIndexCountForType failed");
        require(abi.decode(ret, (uint256)) == 0, string.concat("type not empty: ", label));
    }
}
