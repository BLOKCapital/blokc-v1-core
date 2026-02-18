// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";

contract MockOracle is AggregatorV3Interface {
    uint80 public roundId;
    int256 public answer;
    int256 public previousAnswer;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound;
    string i_symbol;

    constructor(string memory _symbol, uint256 _answer) {
        roundId = 12_345;
        answer = int256(_answer);
        previousAnswer = int256(_answer);
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 12_345;
        i_symbol = _symbol;
    }

    function setResponse(
        uint80 _roundId,
        int256 _answer,
        uint256 _startedAt,
        uint256 _updatedAt,
        uint80 _answeredInRound
    )
        external
    {
        roundId = _roundId;
        answer = _answer;
        startedAt = _startedAt;
        updatedAt = _updatedAt;
        answeredInRound = _answeredInRound;
    }

    function refresh(int256 _answer) external {
        previousAnswer = answer;
        answer = _answer;
        ++roundId;
        ++answeredInRound;
        updatedAt = block.timestamp;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function description() external view returns (string memory) {
        return i_symbol;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId) external view returns (uint80, int256, uint256, uint256, uint80) {
        int256 roundAnswer = _roundId < roundId ? previousAnswer : answer;
        return (_roundId, roundAnswer, startedAt, updatedAt, _roundId);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
