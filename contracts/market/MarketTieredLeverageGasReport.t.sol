// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../testing/FloatTest.t.sol";
import "../testing/MarketTieredLeverageInternalStateSetters.sol";

contract MarketTieredLeverageGasReport is FloatTest {
  MarketTieredLeverageInternalStateSetters marketInternalStateSetters;

  constructor() {
    marketInternalStateSetters = marketFactory.marketInternalStateSetters(defaultMarketIndex);
  }

  function testUpdateSystemStateGasReport() public {
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);

    // warpOutsideOfMewt();
    // mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);

    vm.roll(block.timestamp + 1);
    uint256 gasUsed = marketInternalStateSetters.gasReportForSystemStateUpdate();
    console2.log("Gas used for 1 epoch no users updateSystemState:", gasUsed);

    address user = getFreshUser();
    uint112 amountInPaymentToken = 10e18;
    uint32 poolIndex = 0;
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType.SHORT;
    vm.startPrank(user);
    mint(defaultMarketIndex, poolType, poolIndex, amountInPaymentToken);
    vm.stopPrank();
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);

    vm.roll(block.timestamp + 1);
    gasUsed = marketInternalStateSetters.gasReportForSystemStateUpdate();
    console2.log("Gas used for 1 epoch 1 user updateSystemState:", gasUsed);

    address user2 = getFreshUser();

    vm.startPrank(user);
    mint(defaultMarketIndex, poolType, poolIndex, amountInPaymentToken);
    changePrank(user2);
    mint(defaultMarketIndex, poolType, poolIndex, amountInPaymentToken);
    vm.stopPrank();
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);

    vm.roll(block.timestamp + 1);
    gasUsed = marketInternalStateSetters.gasReportForSystemStateUpdate();
    console2.log("Gas used for 1 epoch 2 users same pool updateSystemState:", gasUsed);
  }

  function testUpdateSystemStateManyUsersGasReport() public {
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);

    address user;
    uint112 amountInPaymentToken = 10e18;
    uint32 poolIndex;
    IMarketCommon.PoolType poolType;
    uint8 poolTypeInt;

    for (uint32 i = 0; i < 10; i++) {
      user = getFreshUser();
      poolTypeInt = poolTypeInt + 1;
      poolType = IMarketCommon.PoolType(poolTypeInt % 2);
      poolIndex = (poolIndex + 1) % uint8(marketInternalStateSetters.numberOfPoolsOfType(poolType));
      vm.startPrank(user);
      mint(defaultMarketIndex, poolType, poolIndex, amountInPaymentToken);
      vm.stopPrank();
    }

    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    vm.roll(block.timestamp + 1);
    uint256 gasUsed = marketInternalStateSetters.gasReportForSystemStateUpdate();
    console2.log("Gas used for 1 epoch 10 users different pools updateSystemState:", gasUsed);

    for (uint32 i = 0; i < 10; i++) {
      user = getFreshUser();
      poolIndex = 0;
      poolType = IMarketCommon.PoolType.SHORT;
      vm.startPrank(user);
      mint(defaultMarketIndex, poolType, poolIndex, amountInPaymentToken);
      vm.stopPrank();
    }

    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    vm.roll(block.timestamp + 1);
    gasUsed = marketInternalStateSetters.gasReportForSystemStateUpdate();
    console2.log("Gas used for 1 epoch 10 users same pool updateSystemState:", gasUsed);
  }

  function testUpdateSystemStateGasReportManyOraclePrices() public {
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);

    updateSystemStateSingleMarket(defaultMarketIndex);
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);
    warpToJustBeforeEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);

    updateSystemStateSingleMarket(defaultMarketIndex);
    warpOutsideOfMewt();
    updateSystemStateSingleMarket(defaultMarketIndex);

    for (uint32 i = 0; i < 10; i++) {
      warpForwardOneSecond();
      mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    }

    vm.roll(block.timestamp + 1);
    uint256 gasUsed = marketInternalStateSetters.gasReportForSystemStateUpdate();
    console2.log("Gas used for 1 epoch 10 prices updateSystemState:", gasUsed);

    warpToJustBeforeEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);

    updateSystemStateSingleMarket(defaultMarketIndex);
    warpOutsideOfMewt();
    updateSystemStateSingleMarket(defaultMarketIndex);

    for (uint32 i = 0; i < 30; i++) {
      warpForwardOneSecond();
      mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, ONE_PERCENT);
    }

    vm.roll(block.timestamp + 1);
    gasUsed = marketInternalStateSetters.gasReportForSystemStateUpdate();
    console2.log("Gas used for 1 epoch 30 prices updateSystemState:", gasUsed);
  }
}
