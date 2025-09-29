// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title IKillSwitch
    @author BLOK Capital DAO
    @notice Interface for Kill Switch functionality.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IKillSwitch {
    /**
     * @notice Returns whether the kill switch is active or not.
     * @return bool true if the kill switch is active, false otherwise.
     * @dev When the kill switch is active, all the functions in the gardens will be disabled to prevent further
     * actions.
     */
    function isKilled() external view returns (bool);

    /**
     * @notice Activates the kill switch, disabling all the functions in the gardens.
     * @dev Can only be called by the Blok Capital DAO.
     * Once activated, it cannot be deactivated.
     * Emits a {Killed} event.
     */
    function kill() external;

    /**
     * @notice Revives the kill switch, enabling all the functions in the gardens.
     * @dev Can only be called by the Blok Capital DAO.
     * Once revived, it cannot
     * Emits a {Revived} event.
     */
    function revive() external;
}
