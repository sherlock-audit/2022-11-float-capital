// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../../testing/FloatTest.t.sol";

import "../../oracles/OracleManager.t.sol";

contract OracleManagerScenarioOne is FloatTest {
  OracleManager oracleManager;
  AggregatorV3Mock chainlinkOracleMock;
  uint256 immutable maxNumberOfOracleUpdates = type(uint256).max;

  mapping(uint256 => int128) prices;
  mapping(uint256 => uint256) oracleTimes;
  mapping(uint256 => uint256) epochStartTime;

  uint256 checkPointA;
  uint256 checkPointB;
  uint256 checkPointC;
  uint256 checkPointD;
  uint256 checkPointE;
  uint256 checkPointF;
  uint256 checkPointG;
  uint256 checkPointH;

  constructor() {
    prices[0] = 1e18;
    prices[1] = 101e16;
    prices[2] = 102e16;
    prices[3] = 100e16;
    prices[4] = 98e16;
    prices[5] = 97e16;
    prices[6] = 99e16;
    prices[7] = 102e16;
    prices[8] = 101e16;
    prices[9] = 103e16;
    prices[10] = 105e16;
    prices[11] = 102e16;
    prices[12] = 101e16;
    prices[13] = 102e16;
    prices[14] = 104e16;
    prices[15] = 101e16;
  }

  /// @dev this test follows this excalidraw image exactly: https://app.excalidraw.com/l/2big5WYTyfh/2vF2M9LXpoy
  function broken_testScenarioOne() public {
    oracleTimes[0] = 46;
    epochStartTime[0] = 50;
    oracleTimes[1] = 52;
    oracleTimes[2] = 56;
    oracleTimes[3] = 59;
    epochStartTime[1] = 60;
    oracleTimes[4] = 61;
    oracleTimes[5] = 68;
    checkPointA = 69;
    epochStartTime[2] = 70;
    checkPointB = 71;
    checkPointC = 73;
    oracleTimes[6] = 75;
    checkPointD = 78;
    epochStartTime[3] = 80;
    oracleTimes[7] = 81;
    checkPointE = 82;
    oracleTimes[8] = 84;
    checkPointF = 87;
    epochStartTime[4] = 90;
    oracleTimes[9] = 90;
    oracleTimes[10] = 94;
    oracleTimes[11] = 96;
    epochStartTime[5] = 100;
    oracleTimes[12] = 101;
    checkPointG = 103;
    oracleTimes[13] = 107;
    checkPointH = 109;
    epochStartTime[6] = 110;

    vm.warp(oracleTimes[0]);
    uint80 oracleFirstRoundId = 0;
    chainlinkOracleMock = new AggregatorV3Mock(prices[0], oracleFirstRoundId, DEFAULT_ORACLE_DECIMALS);

    uint256 fixedEpochLength = 10;
    uint256 minimumExecutionWaitingTime = 2;

    vm.startPrank(ADMIN);

    vm.warp(oracleTimes[1]);
    chainlinkOracleMock.pushPrice(prices[1]);

    vm.warp(oracleTimes[2]);
    chainlinkOracleMock.pushPrice(prices[2]);

    vm.warp(oracleTimes[3]);
    chainlinkOracleMock.pushPrice(prices[3]);

    vm.warp(oracleTimes[4]);
    chainlinkOracleMock.pushPrice(prices[4]);

    vm.warp(oracleTimes[5]);
    chainlinkOracleMock.pushPrice(prices[5]);

    vm.warp(checkPointA);
    oracleManager = new OracleManager(address(chainlinkOracleMock), fixedEpochLength, minimumExecutionWaitingTime);

    assertEq(oracleManager.initialEpochStartTimestamp(), epochStartTime[0], "initial epoch start time stamp not correct");
    assertEq(oracleManager.getEpochStartTimestamp(), epochStartTime[1], "current epoch start time stamp not correct");
    assertEq(oracleManager.getEpochStartTimestamp() + oracleManager.EPOCH_LENGTH(), epochStartTime[2], "current epoch start time stamp not correct");
    assertEq(oracleManager.getCurrentEpochIndex(), 1, "current epoch index not correct");
    {
      uint32 currentEpochTimestamp = uint32(oracleManager.getEpochStartTimestamp());
      assertEq(currentEpochTimestamp, oracleManager.getEpochStartTimestamp(), "current epoch timestamp not correct");
    }
    {
      uint32 currentEpochTimestamp = uint32(oracleManager.getEpochStartTimestamp());
      assertEq(currentEpochTimestamp, oracleManager.getEpochStartTimestamp(), "current epoch timestamp not correct");
    }

    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 60, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[1],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 0, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");
    //   assertEq(_missedEpochOracleRoundIds.length, 0, "missed epoch index not correct");
    // }

    vm.warp(checkPointB);
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 60, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[2],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 1, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");
    //   assertEq(_missedEpochOracleRoundIds.length, 0, "---missed epoch index not correct");
    // }
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 70, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[2],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 0, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");
    //   assertEq(_missedEpochOracleRoundIds.length, 0, "missed epoch index not correct");
    // }

    vm.warp(checkPointC);
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 70, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[2],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 0, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");
    //   assertEq(_missedEpochOracleRoundIds.length, 0, "---missed epoch index not correct");
    // }

    vm.warp(oracleTimes[6]);
    chainlinkOracleMock.pushPrice(prices[6]);

    vm.warp(checkPointD);
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 70, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[2],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 0, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");
    //   assertEq(_missedEpochOracleRoundIds.length, 1, "---missed epoch index not correct");

    //   // checking for both length and contents of MissedEpochExecutionInfo[]

    //   OracleManager.MissedEpochExecutionInfo[]
    //     memory expectedEpochInfos = new OracleManager.MissedEpochExecutionInfo[](1);
    //   expectedEpochInfos[0].oracleUpdateIndex = 6;
    //   expectedEpochInfos[0].oraclePrice = prices[6];
    //   expectedEpochInfos[0].timestampPriceUpdated = oracleTimes[6];
    //   expectedEpochInfos[0].associatedEpochIndex = 1;

    //   _assertMissedEpochExecutionInfoArrayEq(_missedEpochOracleRoundIds, expectedEpochInfos);
    // }
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(1, 6, 70, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[2],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 0, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[6], "previous price not correct");
    //   assertEq(_missedEpochOracleRoundIds.length, 0, "---missed epoch index not correct");
    // }

    vm.warp(oracleTimes[7]);
    chainlinkOracleMock.pushPrice(prices[7]);

    vm.warp(checkPointE);
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(1, 6, 70, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[3],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 1, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[6], "previous price not correct");
    //   assertEq(_missedEpochOracleRoundIds.length, 0, "---missed epoch index not correct");
    // }
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(1, 6, 80, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[3],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 0, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[6], "previous price not correct");
    //   assertEq(_missedEpochOracleRoundIds.length, 0, "---missed epoch index not correct");
    // }
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 60, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[3],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 2, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");

    //   OracleManager.MissedEpochExecutionInfo[]
    //     memory expectedEpochInfos = new OracleManager.MissedEpochExecutionInfo[](1);
    //   expectedEpochInfos[0].oracleUpdateIndex = 6;
    //   expectedEpochInfos[0].oraclePrice = prices[6];
    //   expectedEpochInfos[0].timestampPriceUpdated = oracleTimes[6];
    //   expectedEpochInfos[0].associatedEpochIndex = 1;

    //   _assertMissedEpochExecutionInfoArrayEq(_missedEpochOracleRoundIds, expectedEpochInfos);
    // }

    vm.warp(oracleTimes[8]);
    chainlinkOracleMock.pushPrice(prices[8]);

    vm.warp(checkPointF);
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 60, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[3],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 2, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");

    //   OracleManager.MissedEpochExecutionInfo[]
    //     memory expectedEpochInfos = new OracleManager.MissedEpochExecutionInfo[](2);
    //   expectedEpochInfos[0].oracleUpdateIndex = 6;
    //   expectedEpochInfos[0].oraclePrice = prices[6];
    //   expectedEpochInfos[0].timestampPriceUpdated = oracleTimes[6];
    //   expectedEpochInfos[0].associatedEpochIndex = 1;
    //   expectedEpochInfos[1].oracleUpdateIndex = 8;
    //   expectedEpochInfos[1].oraclePrice = prices[8];
    //   expectedEpochInfos[1].timestampPriceUpdated = oracleTimes[8];
    //   expectedEpochInfos[1].associatedEpochIndex = 2;

    //   _assertMissedEpochExecutionInfoArrayEq(_missedEpochOracleRoundIds, expectedEpochInfos);
    // }

    vm.warp(oracleTimes[9]);
    chainlinkOracleMock.pushPrice(prices[7]);
    vm.warp(oracleTimes[10]);
    chainlinkOracleMock.pushPrice(prices[10]);
    vm.warp(oracleTimes[11]);
    chainlinkOracleMock.pushPrice(prices[11]);
    vm.warp(oracleTimes[12]);
    chainlinkOracleMock.pushPrice(prices[12]);

    vm.warp(checkPointG);
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 60, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[5],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 4, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");

    //   OracleManager.MissedEpochExecutionInfo[]
    //     memory expectedEpochInfos = new OracleManager.MissedEpochExecutionInfo[](3);
    //   expectedEpochInfos[0].oracleUpdateIndex = 6;
    //   expectedEpochInfos[0].oraclePrice = prices[6];
    //   expectedEpochInfos[0].timestampPriceUpdated = oracleTimes[6];
    //   expectedEpochInfos[0].associatedEpochIndex = 1;
    //   expectedEpochInfos[1].oracleUpdateIndex = 8;
    //   expectedEpochInfos[1].oraclePrice = prices[8];
    //   expectedEpochInfos[1].timestampPriceUpdated = oracleTimes[8];
    //   expectedEpochInfos[1].associatedEpochIndex = 2;
    //   expectedEpochInfos[2].oracleUpdateIndex = 10;
    //   expectedEpochInfos[2].oraclePrice = prices[10];
    //   expectedEpochInfos[2].timestampPriceUpdated = oracleTimes[10];
    //   expectedEpochInfos[2].associatedEpochIndex = 3;

    //   _assertMissedEpochExecutionInfoArrayEq(_missedEpochOracleRoundIds, expectedEpochInfos);
    // }
    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(1, 6, 70, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[5],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 3, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[6], "previous price not correct");

    //   OracleManager.MissedEpochExecutionInfo[]
    //     memory expectedEpochInfos = new OracleManager.MissedEpochExecutionInfo[](2);
    //   expectedEpochInfos[0].oracleUpdateIndex = 8;
    //   expectedEpochInfos[0].oraclePrice = prices[8];
    //   expectedEpochInfos[0].timestampPriceUpdated = oracleTimes[8];
    //   expectedEpochInfos[0].associatedEpochIndex = 2;
    //   expectedEpochInfos[1].oracleUpdateIndex = 10;
    //   expectedEpochInfos[1].oraclePrice = prices[10];
    //   expectedEpochInfos[1].timestampPriceUpdated = oracleTimes[10];
    //   expectedEpochInfos[1].associatedEpochIndex = 3;

    //   _assertMissedEpochExecutionInfoArrayEq(_missedEpochOracleRoundIds, expectedEpochInfos);
    // }

    vm.warp(oracleTimes[13]);
    chainlinkOracleMock.pushPrice(prices[13]);

    vm.warp(checkPointH);

    // {
    //   (
    //     uint32 currentEpochStartTimestamp,
    //     uint32 numberOfEpochsSinceLastEpoch,
    //     int256 previousPrice,
    //     ,
    //     OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //   ) = oracleManager.getOracleInfoForSystemStateUpdate(0, 5, 60, maxNumberOfOracleUpdates);

    //   assertEq(
    //     currentEpochStartTimestamp,
    //     epochStartTime[5],
    //     "current epoch start time stamp not correct"
    //   );
    //   assertEq(numberOfEpochsSinceLastEpoch, 4, "number of epochs since last epoch not correct");
    //   assertEq(previousPrice, prices[5], "previous price not correct");

    //   OracleManager.MissedEpochExecutionInfo[]
    //     memory expectedEpochInfos = new OracleManager.MissedEpochExecutionInfo[](4);
    //   expectedEpochInfos[0].oracleUpdateIndex = 6;
    //   expectedEpochInfos[0].oraclePrice = prices[6];
    //   expectedEpochInfos[0].timestampPriceUpdated = oracleTimes[6];
    //   expectedEpochInfos[0].associatedEpochIndex = 1;
    //   expectedEpochInfos[1].oracleUpdateIndex = 8;
    //   expectedEpochInfos[1].oraclePrice = prices[8];
    //   expectedEpochInfos[1].timestampPriceUpdated = oracleTimes[8];
    //   expectedEpochInfos[1].associatedEpochIndex = 2;
    //   expectedEpochInfos[2].oracleUpdateIndex = 10;
    //   expectedEpochInfos[2].oraclePrice = prices[10];
    //   expectedEpochInfos[2].timestampPriceUpdated = oracleTimes[10];
    //   expectedEpochInfos[2].associatedEpochIndex = 3;
    //   expectedEpochInfos[3].oracleUpdateIndex = 13;
    //   expectedEpochInfos[3].oraclePrice = prices[13];
    //   expectedEpochInfos[3].timestampPriceUpdated = oracleTimes[13];
    //   expectedEpochInfos[3].associatedEpochIndex = 4;

    //   _assertMissedEpochExecutionInfoArrayEq(_missedEpochOracleRoundIds, expectedEpochInfos);
    // }
    //   {
    //     (
    //       uint32 currentEpochStartTimestamp,
    //       uint32 numberOfEpochsSinceLastEpoch,
    //       int256 previousPrice,
    //       ,
    //       OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIds
    //     ) = oracleManager.getOracleInfoForSystemStateUpdate(1, 6, 80, maxNumberOfOracleUpdates);

    //     assertEq(
    //       currentEpochStartTimestamp,
    //       epochStartTime[5],
    //       "current epoch start time stamp not correct"
    //     );
    //     assertEq(numberOfEpochsSinceLastEpoch, 2, "number of epochs since last epoch not correct");
    //     assertEq(previousPrice, prices[6], "previous price not correct");

    //     OracleManager.MissedEpochExecutionInfo[]
    //       memory expectedEpochInfos = new OracleManager.MissedEpochExecutionInfo[](3);
    //     expectedEpochInfos[0].oracleUpdateIndex = 8;
    //     expectedEpochInfos[0].oraclePrice = prices[8];
    //     expectedEpochInfos[0].timestampPriceUpdated = oracleTimes[8];
    //     expectedEpochInfos[0].associatedEpochIndex = 2;
    //     expectedEpochInfos[1].oracleUpdateIndex = 10;
    //     expectedEpochInfos[1].oraclePrice = prices[10];
    //     expectedEpochInfos[1].timestampPriceUpdated = oracleTimes[10];
    //     expectedEpochInfos[1].associatedEpochIndex = 3;
    //     expectedEpochInfos[2].oracleUpdateIndex = 13;
    //     expectedEpochInfos[2].oraclePrice = prices[13];
    //     expectedEpochInfos[2].timestampPriceUpdated = oracleTimes[13];
    //     expectedEpochInfos[2].associatedEpochIndex = 4;

    //     _assertMissedEpochExecutionInfoArrayEq(_missedEpochOracleRoundIds, expectedEpochInfos);
    //   }
  }

  // function _assertMissedEpochExecutionInfoEq(
  //   OracleManager.MissedEpochExecutionInfo memory actualEpochInfo,
  //   OracleManager.MissedEpochExecutionInfo memory expectedEpochInfo
  // ) internal {
  //   assertEq(
  //     actualEpochInfo.oracleUpdateIndex,
  //     expectedEpochInfo.oracleUpdateIndex,
  //     "oracleUpdateIndex not correct"
  //   );
  //   assertEq(actualEpochInfo.oraclePrice, expectedEpochInfo.oraclePrice, "oraclePrice not correct");
  //   assertEq(
  //     actualEpochInfo.timestampPriceUpdated,
  //     expectedEpochInfo.timestampPriceUpdated,
  //     "timestampPriceUpdated not correct"
  //   );
  //   assertEq(
  //     actualEpochInfo.associatedEpochIndex,
  //     expectedEpochInfo.associatedEpochIndex,
  //     "associatedEpochIndex not correct"
  //   );
  // }

  // function _assertMissedEpochExecutionInfoArrayEq(
  //   OracleManager.MissedEpochExecutionInfo[] memory actualEpochInfo,
  //   OracleManager.MissedEpochExecutionInfo[] memory expectedEpochInfo
  // ) internal {
  //   assertEq(actualEpochInfo.length, expectedEpochInfo.length, "---missed epoch index not correct");
  //   for (
  //     uint32 epochToExecuteIndex = 0;
  //     epochToExecuteIndex < actualEpochInfo.length;
  //     epochToExecuteIndex++
  //   ) {
  //     _assertMissedEpochExecutionInfoEq(
  //       actualEpochInfo[epochToExecuteIndex],
  //       expectedEpochInfo[epochToExecuteIndex]
  //     );
  //   }
  // }
}
