// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title KillSwitch
    @author BLOK Capital DAO
    @notice Exposes Kill Switch functions to be used by the DAO.
    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IKillSwitch } from "src/interfaces/IKillSwitch.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

error AlreadyKilled();
error NotKilled();

contract KillSwitch is IKillSwitch, Ownable(msg.sender) {
    /// @notice Whether the contract is killed or not.
    bool private killed;

    /// @notice Emitted when the contract is killed.
    event Killed(address indexed owner);
    /// @notice Emitted when the contract is revived.
    event Revived(address indexed owner);

    /// @inheritdoc IKillSwitch
    function kill() external onlyOwner {
        if (killed) revert AlreadyKilled();
        killed = true;
        emit Killed(msg.sender);
    }

    /// @inheritdoc IKillSwitch
    function revive() external onlyOwner {
        if (!killed) revert NotKilled();
        killed = false;
        emit Revived(msg.sender);
    }

    /// @inheritdoc IKillSwitch
    function isKilled() external view returns (bool) {
        return killed;
    }
}
