// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../testing/FloatTest.t.sol";

import "../oracles/OracleManager.t.sol";

import "forge-std/console2.sol";

contract OracleManagerTest is FloatTest {
  int256 constant ORACLE_FIRST_PRICE = 1e18;
  uint80 constant ORACLE_FIRST_ROUND_ID = 1000;

  OracleManager oracleManager;
  AggregatorV3Mock chainlinkOracleMock;

  constructor() {
    vm.startPrank(ADMIN);

    chainlinkOracleMock = new AggregatorV3Mock(ORACLE_FIRST_PRICE, ORACLE_FIRST_ROUND_ID, DEFAULT_ORACLE_DECIMALS);

    oracleManager = new OracleManager(address(chainlinkOracleMock), DEFAULT_FIXED_EPOCH_LENGTH, DEFAULT_MINIMUM_EXECUTION_WAITING_TIME);
  }

  function broken_testMultiEpochReturn() public {
    uint80 startOraclePriceIdentifier = ORACLE_FIRST_ROUND_ID;

    // dummy variables to simulate fake epoch excution when calling oracleManagerFixedEpoch contract
    uint80 dummyPreviousExecutionPriceOracleIdentifier;
    uint32 dummyLatestExecutedEpochIndex;

    uint256 maxNumberOfOracleUpdates = 40;

    (uint256 startEpoch, RandomnessHelper.TestOracleInfo[] memory epochExecutions, uint256 numberOfEpochsToExecute) = rand
      .generateRandomOracleUpdatesAndGetEpochToExecuteInformation(oracleManager, chainlinkOracleMock, maxNumberOfOracleUpdates);

    dummyLatestExecutedEpochIndex = uint32(startEpoch - 1);

    // TODO: below this line was broken.
    // (OracleManager.MissedEpochExecutionInfo[] memory epochsToExecute, ) = oracleManager
    //   .getMissedEpochPriceUpdates(
    //     uint32(startEpoch - 1),
    //     startOraclePriceIdentifier,
    //     type(uint256).max
    //   );

    // assertEq(
    //   epochsToExecute.length,
    //   numberOfEpochsToExecute,
    //   "Epochs to execute is incorrect length"
    // );

    // for (uint256 index = 0; index < epochsToExecute.length; index++) {
    //   OracleManager.MissedEpochExecutionInfo memory actualResult = epochsToExecute[index];

    //   RandomnessHelper.TestOracleInfo memory expectedResult = epochExecutions[index];

    //   assertEq(actualResult.oraclePrice, expectedResult.price, "Execution price is different");

    //   assertEq(
    //     actualResult.timestampPriceUpdated,
    //     expectedResult.timestamp,
    //     "Execution timestamp is different"
    //   );
    //   assertEq(
    //     actualResult.oracleUpdateIndex,
    //     expectedResult.oracleRoundId,
    //     "Execution oracleRoundId is different"
    //   );

    //   dummyLatestExecutedEpochIndex++;
    //   dummyPreviousExecutionPriceOracleIdentifier = actualResult.oracleUpdateIndex;
    // }

    // warpToJustBeforeNextEpoch();

    // // recalling getMissedEpochPriceUpdates() assuming we have caught up all the epochs already

    // (
    //   OracleManager.MissedEpochExecutionInfo[] memory epochsToExecuteAfterExecution,

    // ) = oracleManager.getMissedEpochPriceUpdates(
    //     dummyLatestExecutedEpochIndex,
    //     dummyPreviousExecutionPriceOracleIdentifier,
    //     type(uint256).max
    //   );

    // assertEq(epochsToExecuteAfterExecution.length, 0, "There should be no more epochs to execute");
  }

  function broken_testMissedEpochsFetchesCorrectAmountOfInfo(uint256 epochsToTryFetch) public {
    uint80 startOraclePriceIdentifier = ORACLE_FIRST_ROUND_ID;

    // dummy variables to simulate fake epoch excution when calling oracleManagerFixedEpoch contract
    uint32 dummyLatestExecutedEpochIndex;

    uint256 maxNumberOfOracleUpdates = 300;
    epochsToTryFetch = epochsToTryFetch % maxNumberOfOracleUpdates;

    (uint256 startEpoch, , uint256 numberOfEpochsToExecute) = rand.generateRandomOracleUpdatesAndGetEpochToExecuteInformation(
      oracleManager,
      chainlinkOracleMock,
      maxNumberOfOracleUpdates
    );

    dummyLatestExecutedEpochIndex = uint32(startEpoch - 1);
    // Reassinging this variable for readability
    uint256 numberOfEpochsAvailableToExecute = numberOfEpochsToExecute;

    // (OracleManager.MissedEpochExecutionInfo[] memory epochsToExecute, ) = oracleManager
    //   .getMissedEpochPriceUpdates(
    //     uint32(startEpoch - 1),
    //     startOraclePriceIdentifier,
    //     epochsToTryFetch
    //   );

    // if (epochsToTryFetch > numberOfEpochsAvailableToExecute) {
    //   assertEq(
    //     epochsToExecute.length,
    //     numberOfEpochsAvailableToExecute,
    //     "All epochs avaiable fetched"
    //   );
    // } else {
    //   assertEq(epochsToExecute.length, epochsToTryFetch, "Only n epochs should be fetched");
    // }
  }
}
