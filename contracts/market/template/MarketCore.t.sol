// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "ds-test/test.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../interfaces/chainlink/AggregatorV3Interface.sol";

import "../../oracles/OracleManager.t.sol";

import "../../testing/FloatTest.t.sol";

import "forge-std/console2.sol";

contract MarketTieredLeverageTest is FloatTest {
  function testSystemStateCannotBeExecutedTwiceInSameEpoch() public {
    int256 percent = 1e16;

    uint32 epochIndexBefore = uint32(defaultMarket.get_oracleManager().getCurrentEpochIndex());

    mockChainlinkOraclePercentPriceMovement(percent);
    warpForwardOneSecond();
    updateSystemStateSingleMarket(defaultMarketIndex);

    mockChainlinkOraclePercentPriceMovement(percent);
    warpForwardOneSecond();
    updateSystemStateSingleMarket(defaultMarketIndex);

    mockChainlinkOraclePercentPriceMovement(percent);
    warpForwardOneSecond();
    updateSystemStateSingleMarket(defaultMarketIndex);

    uint32 epochIndexAfter = uint32(defaultMarket.get_oracleManager().getCurrentEpochIndex());

    assertEq(epochIndexBefore, epochIndexAfter, "Epoch index incorrectly changed");

    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(percent);
    updateSystemStateSingleMarket(defaultMarketIndex);

    uint32 epochIndexAfterCorrectStateChange = uint32(defaultMarket.get_oracleManager().getCurrentEpochIndex());

    assertEq(epochIndexBefore + 1, epochIndexAfterCorrectStateChange, "Epoch index incorrectly changed");
  }
}

contract MarketTieredLeverage_ARITHMETIC_Tests is FloatTest {
  MarketTieredLeverageMockable marketMockable;

  constructor() {
    uint256 initialPoolLiquidity = 100e18;
    MarketFactory.PoolLeverage[] memory poolLeverages = new MarketFactory.PoolLeverage[](5);
    poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
    poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
    poolLeverages[2] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 1);
    poolLeverages[3] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
    poolLeverages[4] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 1);

    deal(address(defaultPaymentToken), ADMIN, 1e22);
    deal(address(defaultPaymentToken), ALICE, 1e22);
    deal(address(defaultPaymentToken), BOB, 1e22);

    uint32 marketMockableIndex = deployMarket(
      initialPoolLiquidity,
      poolLeverages,
      DEFAULT_FIXED_EPOCH_LENGTH,
      DEFAULT_MINIMUM_EXECUTION_WAITING_TIME,
      DEFAULT_ORACLE_FIRST_PRICE,
      MarketFactory.MarketContractType.MarketMockable
    );

    marketMockable = MarketTieredLeverageMockable(marketFactory.marketAddress(marketMockableIndex));
  }

  function abs(int256 n) internal pure returns (uint256) {
    unchecked {
      // must be unchecked in order to support `n = type(int256).min`
      return uint256(n >= 0 ? n : -n);
    }
  }

  function FIX_ME_test_reference__getEffectiveValueChange(
    uint256 effectiveValueLong,
    uint256 effectiveValueShort,
    int256 previousPrice,
    int256 currentPrice
  ) public {
    vm.assume(previousPrice > 0);
    vm.assume(currentPrice > 0);
    vm.assume(effectiveValueLong != 0);
    vm.assume(effectiveValueShort != 0);

    // price movement can be huuuge, but not that huge:
    vm.assume(abs(currentPrice - previousPrice) < type(uint256).max / 1e19);
    // underbalanced side can't cause overflow when multiplied by max percent change:
    vm.assume(
      Math.min(effectiveValueShort, effectiveValueLong) < uint256(type(int256).max) / uint256(IMarket(address(marketMockable)).get_maxPercentChange())
    );

    // TODO: This is function is out-dated!
    (int256 expectedResult, , , ) = getEffectiveValueChangeReferenceImplementation(
      effectiveValueLong,
      effectiveValueShort,
      1000, // TODO: put a proper value here!
      previousPrice,
      currentPrice,
      IMarket(address(marketMockable))
    );
    // TODO: fix this test - add back below 2 lines.
    // int256 actualResult = marketMockable.getEffectiveValueChangeExposed(effectiveValueLong, effectiveValueShort, previousPrice, currentPrice);
    // assertEq(actualResult, expectedResult, "getEffectiveValueChange result differs to expected result.");
  }
}
