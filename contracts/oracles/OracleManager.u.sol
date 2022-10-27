// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../v0.1ImportantCode/AlphaFLT.sol";
import "../registry/template/Registry.sol";
import "../PoolToken/PoolToken.sol";
import "../components/gamificationFun/GEMS.sol";

import "../interfaces/IMarket.sol";

import "../testing/FloatTest.t.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../interfaces/chainlink/AggregatorV3Interface.sol";

import "forge-std/console2.sol";

import "../oracles/OracleManager.t.sol";

contract OracleManagerUnit is FloatTest {
  uint32 marketIndex = 1;

  AggregatorV3Mock chainlinkOracleMock;

  OracleManager oracleManagerFixedEpoch;

  function setEverythingUp() internal {
    vm.startPrank(ADMIN);

    chainlinkOracleMock = new AggregatorV3Mock(DEFAULT_ORACLE_FIRST_PRICE, DEFAULT_ORACLE_FIRST_ROUND_ID, DEFAULT_ORACLE_DECIMALS);

    chainlinkOracleMock.pushPricePercentMovement(5e16);

    oracleManagerFixedEpoch = new OracleManager(address(chainlinkOracleMock), DEFAULT_FIXED_EPOCH_LENGTH, DEFAULT_MINIMUM_EXECUTION_WAITING_TIME);

    vm.stopPrank();
  }

  constructor() {
    setEverythingUp();
  }

  function setUp() public {
    // setEverythingUp();
  }

  function broken_testGetOracleInfoForSystemStateUpdate(
    uint32 _latestExecutedEpochIndex,
    uint32 _latestOraclePriceIdentifier,
    uint256 _numberOfUpdatesToTryFetch,
    uint32 _epochTimestamp,
    uint32 currentEpochTimestamp,
    uint32 numberOfEpochsSinceLastEpoch,
    int256 price
  ) public {
    // // TODO: delete this line and change the type of price back to `int128` once forge fixes their bug: https://github.com/foundry-rs/foundry/issues/2560
    // price = price % type(int128).max;
    // vm.assume(_numberOfUpdatesToTryFetch != 0);
    // OracleManager.setFunctionToNotMock("getOracleInfoForSystemStateUpdate");
    // OracleManager.MissedEpochExecutionInfo[]
    //   memory expectedReturnResult = new OracleManager.MissedEpochExecutionInfo[](0);
    // // this should be called before running the function
    // mocker.updateCurrentEpochTimestampMockExpect(
    //   vm,
    //   _epochTimestamp,
    //   currentEpochTimestamp,
    //   numberOfEpochsSinceLastEpoch
    // );
    // mocker.priceAtIndexMockExpect(vm, _latestOraclePriceIdentifier, price);
    // mocker.getMissedEpochPriceUpdatesMockExpect(
    //   vm,
    //   _latestExecutedEpochIndex,
    //   _latestOraclePriceIdentifier,
    //   _numberOfUpdatesToTryFetch,
    //   expectedReturnResult
    // );
    // // use variables for parameters
    // (
    //   uint32 currentEpochTimestampResult,
    //   uint32 numberOfEpochsSinceLastEpochResult, // remove this and use length
    //   int256 previousPrice,
    //   ,
    //   OracleManager.MissedEpochExecutionInfo[] memory _missedEpochOracleRoundIdsResult
    // ) = OracleManager.getOracleInfoForSystemStateUpdate(
    //     _latestExecutedEpochIndex,
    //     _latestOraclePriceIdentifier,
    //     _epochTimestamp,
    //     _numberOfUpdatesToTryFetch
    //   );
    // assertEq(currentEpochTimestampResult, currentEpochTimestamp, "Incorrect currentEpochTimestamp");
    // assertEq(
    //   numberOfEpochsSinceLastEpochResult,
    //   numberOfEpochsSinceLastEpoch,
    //   "Incorrect numberOfEpochsSinceLastEpoch"
    // );
    // assertEq(previousPrice, price, "Incorrect previousPrice");
    // assertEq(
    //   _missedEpochOracleRoundIdsResult.length,
    //   expectedReturnResult.length,
    //   "Incorrect missedEpochPriceUpdates length"
    // );
  }
}
