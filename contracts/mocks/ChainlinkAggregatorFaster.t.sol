// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "./ChainlinkAggregatorFaster.sol";
import "../testing/FloatTest.t.sol";

contract ChainlinkAggregatorFasterTest is FloatTest {
  uint256 constant TESTNET_SPEEDUP_FACTOR = 5; /* 5x faster */
  uint256 constant TESTNET_FAST_ORACLE_UPDATE_LENGTH = 2; /* 2 seconds per update */

  AggregatorV3Mock chainlinkOracleMock;
  ChainlinkAggregatorFaster testnetChainlinkAggregator;

  uint80 constant ORACLE_FIRST_ROUND_ID = 0;

  function setUp() public {
    vm.warp(0);
    chainlinkOracleMock = new AggregatorV3Mock(ORACLE_PRICE_1, ORACLE_FIRST_ROUND_ID, DEFAULT_ORACLE_DECIMALS);

    testnetChainlinkAggregator = new ChainlinkAggregatorFaster(
      AggregatorV3Interface(address(chainlinkOracleMock)),
      TESTNET_SPEEDUP_FACTOR,
      TESTNET_FAST_ORACLE_UPDATE_LENGTH
    );
  }

  function testChangePriceUpOrDownByLessThan1Percent(uint80 roundId) public {
    int256 change = testnetChainlinkAggregator.changePriceUpOrDownByLessThan1Percent(1e18, roundId);

    assertTrue(change <= 101e16 && change >= 99e16, "change out of range");
  }

  int256 constant ORACLE_PRICE_1 = 1e18;
  int256 constant ORACLE_PRICE_2 = 12e17;
  int256 constant ORACLE_PRICE_3 = 18e17;
  int256 constant ORACLE_PRICE_4 = 15e17;

  /// @dev this test follows this excalidraw image exactly: https://excalidraw.com/#room=2edff232d5c17c2530d5,ftuwKrRydGmYpPb0EW7_9w
  ///    https://github.com/Float-Capital/monorepo/pull/2979#issuecomment-1174050233
  function testFastOracles() public {
    //// CHAINLINK UPDATE 1
    vm.warp(0);
    chainlinkOracleMock.pushPrice(ORACLE_PRICE_1);
    skip(5);

    {
      (uint80 roundId, int256 answer, , uint256 updatedAt, ) = testnetChainlinkAggregator.latestRoundData();

      assertEq(roundId, 7, "roundId incorrect");
      assertEq(updatedAt, 4, "updatedAt incorrect");
      assertEq(answer, testnetChainlinkAggregator.changePriceUpOrDownByLessThan1Percent(ORACLE_PRICE_1, roundId), "incorrect price return by oracle");
    }

    //// CHAINLINK UPDATE 2
    vm.warp(10);
    chainlinkOracleMock.pushPrice(ORACLE_PRICE_2);
    {
      // Test latestRoundData()
      (uint80 roundId, int256 answer, , uint256 updatedAt, ) = testnetChainlinkAggregator.latestRoundData();

      assertEq(roundId, 10, "roundId incorrect");
      assertEq(updatedAt, 10, "updatedAt incorrect");
      assertEq(answer, ORACLE_PRICE_2, "incorrect price return by oracle");
    }

    vm.warp(18);
    {
      // Test latestRoundData()
      (uint80 roundId, int256 answer, , uint256 updatedAt, ) = testnetChainlinkAggregator.latestRoundData();

      assertEq(roundId, 14, "roundId incorrect");
      assertEq(updatedAt, 18, "updatedAt incorrect");
      assertEq(answer, testnetChainlinkAggregator.changePriceUpOrDownByLessThan1Percent(ORACLE_PRICE_2, roundId), "incorrect price return by oracle");
    }

    //// CHAINLINK UPDATE 3
    vm.warp(25); // LATE
    chainlinkOracleMock.pushPrice(ORACLE_PRICE_3);
    {
      // Test latestRoundData()
      (uint80 roundId, int256 answer, , uint256 updatedAt, ) = testnetChainlinkAggregator.latestRoundData();
      assertEq(roundId, 15, "roundId incorrect");
      assertEq(updatedAt, 25, "updatedAt incorrect");
      assertEq(answer, ORACLE_PRICE_3, "incorrect price return by oracle");
    }

    //// CHAINLINK UPDATE 4
    vm.warp(30); // EARLY
    chainlinkOracleMock.pushPrice(ORACLE_PRICE_4);
    {
      (uint80 roundId, int256 answer, , uint256 updatedAt, ) = testnetChainlinkAggregator.latestRoundData();

      assertEq(roundId, 20, "roundId incorrect");
      assertEq(updatedAt, 30, "updatedAt incorrect");
      assertEq(answer, ORACLE_PRICE_4, "incorrect price return by oracle");
    }

    vm.warp(40); // END :D
    chainlinkOracleMock.pushPricePercentMovement((1e16));

    testRoundDataIsCorrect(5, 0, ORACLE_PRICE_1);
    testRoundDataIsCorrect(6, 2, ORACLE_PRICE_1);
    testRoundDataIsCorrect(7, 4, ORACLE_PRICE_1);
    testRoundDataIsCorrect(8, 6, ORACLE_PRICE_1);
    testRoundDataIsCorrect(9, 8, ORACLE_PRICE_1);

    testRoundDataIsCorrect(10, 10, ORACLE_PRICE_2);
    testRoundDataIsCorrect(11, 12, ORACLE_PRICE_2);
    testRoundDataIsCorrect(12, 14, ORACLE_PRICE_2);
    testRoundDataIsCorrect(13, 16, ORACLE_PRICE_2);
    testRoundDataIsCorrect(14, 18, ORACLE_PRICE_2);

    testRoundDataIsCorrect(15, 25, ORACLE_PRICE_3);
    testRoundDataIsCorrect(16, 27, ORACLE_PRICE_3);
    testRoundDataIsCorrect(17, 29, ORACLE_PRICE_3);
    testRoundDataIsCorrect(18, 30, ORACLE_PRICE_3);
    testRoundDataIsCorrect(19, 30, ORACLE_PRICE_3);

    testRoundDataIsCorrect(20, 30, ORACLE_PRICE_4);
    testRoundDataIsCorrect(21, 32, ORACLE_PRICE_4);
    testRoundDataIsCorrect(22, 34, ORACLE_PRICE_4);
    testRoundDataIsCorrect(23, 36, ORACLE_PRICE_4);
    testRoundDataIsCorrect(24, 38, ORACLE_PRICE_4);
  }

  function testRoundDataIsCorrect(
    uint80 expectedRoundId,
    uint256 expectedUpdatedAt,
    int256 currentOraclePrice
  ) internal {
    (uint80 roundId, int256 answer, , uint256 updatedAt, ) = testnetChainlinkAggregator.getRoundData(expectedRoundId);

    assertEq(roundId, expectedRoundId, "roundId incorrect");
    assertEq(updatedAt, expectedUpdatedAt, "updatedAt incorrect");
    int256 expectedPrice;

    if ((expectedRoundId % TESTNET_SPEEDUP_FACTOR) == 0) {
      // CASE 1: it is on the oracle update time
      expectedPrice = currentOraclePrice;
    } else {
      (, int256 nextChainlinkAnswer, , uint256 nextChainlinkUpdatedAt, ) = testnetChainlinkAggregator.getRoundData(
        ((expectedRoundId / uint80(TESTNET_SPEEDUP_FACTOR)) + 1) * uint80(TESTNET_SPEEDUP_FACTOR)
      );

      if (nextChainlinkUpdatedAt <= expectedUpdatedAt) {
        // CASE 2: the next chainlink oracle was early
        expectedPrice = nextChainlinkAnswer;
      } else {
        // CASE 3: a simulated oracle price change between chainlink updates
        expectedPrice = testnetChainlinkAggregator.changePriceUpOrDownByLessThan1Percent(currentOraclePrice, expectedRoundId);
      }
    }
    assertEq(answer, expectedPrice, "incorrect price return by oracle");
  }
}
