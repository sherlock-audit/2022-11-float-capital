// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../v0.1ImportantCode/AlphaFLT.sol";
import "../registry/template/Registry.sol";
import "../PoolToken/PoolToken.sol";
import "../components/gamificationFun/GEMS.sol";

import "../testing/generated/MarketTieredLeverageMockable.t.sol";

import "../YieldManagers/MarketLiquidityManagerSimple.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "forge-std/console2.sol";

import "../testing/FloatTest.t.sol";

contract MarketTieredLeverageUnitTest is FloatTest {
  uint32 immutable marketIndex;
  MarketTieredLeverageMockable immutable marketMockable;

  MarketFactory.MarketContractType constant marketType = MarketFactory.MarketContractType.MarketMockable;

  constructor() {
    uint256 initialPoolLiquidity = 1e18;
    MarketFactory.PoolLeverage[] memory poolLeverages = new MarketFactory.PoolLeverage[](5);
    poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
    poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
    poolLeverages[2] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 1);
    poolLeverages[3] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
    poolLeverages[4] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 1);

    marketIndex = deployMarket(
      initialPoolLiquidity,
      poolLeverages,
      DEFAULT_FIXED_EPOCH_LENGTH,
      DEFAULT_MINIMUM_EXECUTION_WAITING_TIME,
      DEFAULT_ORACLE_FIRST_PRICE,
      marketType
    );

    // we know this is of type MarketTieredLeverageMockable because we just deployed it as this type
    marketMockable = MarketTieredLeverageMockable(address(marketFactory.market(marketIndex)));
  }

  function _testPackPoolId(IMarketCommon.PoolType poolType, uint8 poolId) public {
    uint8 poolIdPacked = marketMockable.packPoolIdExposed(poolType, poolId);
    uint8 expectedResult = poolId + (uint8(poolType) * 16);
    assertEq(expectedResult, poolIdPacked, "Incorrect packed pool id");
  }

  function testPackPoolId() public {
    _testPackPoolId(IMarketCommon.PoolType.LONG, 0);
    _testPackPoolId(IMarketCommon.PoolType.LONG, 5);
    _testPackPoolId(IMarketCommon.PoolType.LONG, 15);
    _testPackPoolId(IMarketCommon.PoolType.SHORT, 0);
    _testPackPoolId(IMarketCommon.PoolType.SHORT, 5);
    _testPackPoolId(IMarketCommon.PoolType.SHORT, 15);
  }
}
