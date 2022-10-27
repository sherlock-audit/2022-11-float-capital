// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import "../interfaces/chainlink/AggregatorV3Interface.sol";

/*
 * AggregatorV3Mock is an implementation of a chainlink oracle that allows prices
 * to be set arbitrarily for testing.
 */
contract AggregatorV3Mock is AggregatorV3Interface, Test {
  uint8 public override decimals;
  uint256 public override version;

  string public override description = "This is a mock chainlink oracle";

  struct RoundData {
    uint80 answeredInRound;
    int256 answer;
    uint256 setAt;
  }
  mapping(uint80 => RoundData) public roundData;
  uint80 public currentRoundId;

  ////////////////////////////////////
  ///// CONTRACT SET-UP //////////////
  ////////////////////////////////////

  constructor(
    int256 _price,
    uint80 _roundId,
    uint8 _decimals
  ) {
    decimals = (_decimals != 0) ? _decimals : 18;
    version = 1;
    currentRoundId = _roundId;
    roundData[currentRoundId] = RoundData(currentRoundId, _price, block.timestamp);
  }

  ////////////////////////////////////
  ///// IMPLEMENTATION ///////////////
  ////////////////////////////////////

  function getRoundData(uint80 _roundId)
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    RoundData storage round = roundData[_roundId];
    return (_roundId, round.answer, round.setAt, round.setAt, 1);
  }

  function latestRoundData()
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    RoundData storage round = roundData[currentRoundId];
    return (currentRoundId, round.answer, round.setAt, round.setAt, 1);
  }

  /*
   * Sets the mock rate for the oracle.
   */
  function pushPrice(int256 price) public {
    currentRoundId++;
    roundData[currentRoundId] = RoundData(currentRoundId, price, block.timestamp);
  }

  function pushPricePercentMovement(
    int256 percent // e.g. 1e18 is 100%
  ) public {
    RoundData storage round = roundData[currentRoundId];
    int256 currentPrice = round.answer;
    int256 price = currentPrice + ((currentPrice * percent) / 1e18);
    return pushPrice(price);
  }
}
