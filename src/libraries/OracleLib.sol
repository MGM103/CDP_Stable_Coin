// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author MGM103
 * @notice The purpose of this library is to check for chainlink stale data.
 * If a price is stale, the function will revert and pause the DSCEngine to prevent user losses.
 */
library OracleLib {
    error OracleLib__StalePriceData();

    uint256 private constant TIMEOUT = 1 hours;

    function stalePriceCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSinceUpdate = block.timestamp - updatedAt;
        if (secondsSinceUpdate >= TIMEOUT) revert OracleLib__StalePriceData();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
