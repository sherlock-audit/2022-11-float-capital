// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import "../testing/MarketFactory.t.sol";
import "../testing/FloatTest.t.sol";

contract HardCodedTest is FloatTest {
  uint32 marketIndex;
  IMarket market;
  MarketLiquidityManagerSimple liquidityManager;

  uint256 poolIndexL1 = 0;
  uint256 poolIndexL2 = 1;
  uint256 poolIndexS1 = 0;
  uint256 poolIndexS2 = 1;
  uint256 poolIndexF = 0;

  uint256 initialPoolLiquidity;

  int256 maxPercentageChange;

  constructor() {
    initialPoolLiquidity = 100e18;

    MarketFactory.PoolLeverage[] memory poolLeverages = new MarketFactory.PoolLeverage[](5);
    poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
    poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
    poolLeverages[2] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.LONG, 1);
    poolLeverages[3] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
    poolLeverages[4] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.SHORT, 1);

    marketIndex = deployMarket(
      initialPoolLiquidity,
      poolLeverages,
      DEFAULT_FIXED_EPOCH_LENGTH,
      DEFAULT_MINIMUM_EXECUTION_WAITING_TIME,
      DEFAULT_ORACLE_FIRST_PRICE,
      DEFAULT_MARKET_TYPE
    );
    market = marketFactory.market(marketIndex);
    liquidityManager = marketFactory.liquidityManager(marketIndex);

    maxPercentageChange = market.get_maxPercentChange();

    /// CONSTRUCTOR CHECKS:
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 100e18, "Long pool 1 seed value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 100e18, "Long pool 2 seed value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1), 100e18, "Short pool 1 seed value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2), 100e18, "Short pool 2 seed value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 100e18, "Float tranche seed value is incorrect");
    assertEq(defaultPaymentToken.balanceOf(address(liquidityManager)), 500e18, "YieldManagerMock seed value is incorrect");
    assertEq(maxPercentageChange, 199900000000000000, "maxPercentageChange is incorrect");
  }

  function testHardCodedExamplePriceMovementUp() public {
    int256 priceChangePercent = 1e17;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);

    updateSystemStateSingleMarket(marketIndex);

    // l1 - 110
    // l2 - 120
    // s1 - 90
    // s2 - 80
    // f - 100
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 110e18, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 120e18, "Long pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1), 90e18, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2), 80e18, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 100e18, "Float pool 1 value is incorrect");
  }

  function testHardCodedExampleLargePriceMovementUp() public {
    int256 priceChangePercent = 5e17;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);

    updateSystemStateSingleMarket(marketIndex);

    // l1 - 119.99 (using maxPriceChange of 19.99% due to 5x cap on float pool)
    // l2 - 139.98
    // s1 - 80.01
    // s2 - 60.02
    // f - 100
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 119.99e18, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 139.98e18, "Long pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1), 80.01e18, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2), 60.02e18, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 100e18, "Float pool 1 value is incorrect");
  }

  function testHardCodedExampleLargePriceMovementDown() public {
    int256 priceChangePercent = -6e17;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);

    updateSystemStateSingleMarket(marketIndex);

    // totalAmountDueWithoutSafetyMaximum = effectiveLiquidityShort = 200

    // l1 - 80.01 (using maxPriceChange of 19.99% due to 5x cap on float pool)
    // l2 - 60.02
    // s1 - 119.99
    // s2 - 139.98
    // f - 100
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 80.01e18, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 60.02e18, "Long pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1), 119.99e18, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2), 139.98e18, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 100e18, "Float pool 1 value is incorrect");

    console2.log("The large price movement test is passing");
  }

  function testHardCodedExamplePriceMovementDown() public {
    int256 priceChangePercent = -1e17;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);

    assertEq(defaultPaymentToken.balanceOf(address(liquidityManager)), 500e18, "YieldManager seed value is incorrect");

    updateSystemStateSingleMarket(marketIndex);

    // l1 - 90
    // l2 - 80
    // s1 - 110
    // s2 - 120
    // f - 100
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 90e18, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 80e18, "Long pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1), 110e18, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2), 120e18, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 100e18, "Float pool 1 value is incorrect");
  }

  function testHardCodedExampleLargePriceMovementUpWithCappedFloatLeverage() public {
    uint256[3][8] memory tokenTypeLiquidity;

    tokenTypeLiquidity[0][0] = 100e18;
    tokenTypeLiquidity[1][0] = 100e18;
    tokenTypeLiquidity[2][0] = 100e18;
    tokenTypeLiquidity[0][1] = 100e18;
    tokenTypeLiquidity[1][1] = 500e18;

    MarketTieredLeverageInternalStateSetters(address(market)).givePoolsCorrectAmountOfLiquidity(tokenTypeLiquidity);

    int256 priceChangePercent = 0;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);
    updateSystemStateSingleMarket(marketIndex);

    //checking that the pool liquidity is updated correctly
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 100e18, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 500e18, "Long pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1), 100e18, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2), 100e18, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 100e18, "Float pool 1 value is incorrect");

    priceChangePercent = 6e17;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);

    updateSystemStateSingleMarket(marketIndex);

    // l1 - 114.5381818182e18
    // l2 - 645.3818181818e18
    // s1 - 80.01 (using maxPriceChange of 19.99% due to 5x cap on float pool)
    // s2 - 60.02
    // f - 0.05e18
    // dividing by 1e8 to account decimal inprecision in manually calculated value
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexS1) / 1e8, 114.5381818181 ether / 1e8, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexS2) / 1e8, 645.3818181818 ether / 1e8, "Long pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexL1), 80.01e18, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexL2), 60.02e18, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 0.05e18, "Float pool 1 value is incorrect");
  }

  function testHardCodedExampleLargePriceMovementDownWithCappedFloatLeverage() public {
    uint256[3][8] memory tokenTypeLiquidity;

    tokenTypeLiquidity[0][0] = 100e18;
    tokenTypeLiquidity[1][0] = 100e18;
    tokenTypeLiquidity[2][0] = 100e18;
    tokenTypeLiquidity[0][1] = 500e18;
    tokenTypeLiquidity[1][1] = 100e18;

    MarketTieredLeverageInternalStateSetters(address(market)).givePoolsCorrectAmountOfLiquidity(tokenTypeLiquidity);

    int256 priceChangePercent = 0;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);
    updateSystemStateSingleMarket(marketIndex);

    //checking that the pool liquidity is updated correctly
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 100e18, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 100e18, "Long pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1), 100e18, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2), 500e18, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 100e18, "Float pool 1 value is incorrect");

    priceChangePercent = -6e17;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);

    updateSystemStateSingleMarket(marketIndex);

    // l1 - 80.01 (using maxPriceChange of 19.99% due to 5x cap on float pool)
    // l2 - 60.02
    // s1 - 114.5381818182e18
    // s2 - 645.3818181818e18
    // f - 0.05e18
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 80.01e18, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 60.02e18, "Long pool 2 value is incorrect");
    // dividing by 1e8 to account decimal inprecision in manually calculated value
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1) / 1e8, 114.5381818181 ether / 1e8, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2) / 1e8, 645.3818181818 ether / 1e8, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 0.05e18, "Float pool 1 value is incorrect");
  }

  function testHardCodedFundingRateWithMultiplePoolsPerSide() public {
    vm.startPrank(ADMIN);
    market.changeMarketFundingRateMultiplier(
      IMarketExtendedCore.FundingRateUpdate({prevMultiplier: market.get_fundingRateMultiplier(), newMultiplier: 0})
    );

    uint256[3][8] memory tokenTypeLiquidity;

    tokenTypeLiquidity[0][0] = 100e18;
    tokenTypeLiquidity[1][0] = 200e18;
    tokenTypeLiquidity[2][0] = 100e18;
    tokenTypeLiquidity[0][1] = 300e18;
    tokenTypeLiquidity[1][1] = 400e18;

    MarketTieredLeverageInternalStateSetters(address(market)).givePoolsCorrectAmountOfLiquidity(tokenTypeLiquidity);

    uint256 totalSystemLiquidity = market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1) +
      market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2) +
      market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1) +
      market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2) +
      market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF);

    int256 priceChangePercent = 0;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);
    updateSystemStateSingleMarket(marketIndex);

    //checking that the pool liquidity is updated correctly
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1), 200e18, "Long pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2), 400e18, "Long pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1), 100e18, "Short pool 1 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2), 300e18, "Short pool 2 value is incorrect");
    assertEq(market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF), 100e18, "Float pool 1 value is incorrect");
    assertApproxEqAbs(
      market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1) +
        market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2) +
        market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1) +
        market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2) +
        market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF),
      totalSystemLiquidity,
      1,
      "Total System Liquidity should remain the same"
    );

    market.changeMarketFundingRateMultiplier(
      IMarketExtendedCore.FundingRateUpdate({prevMultiplier: market.get_fundingRateMultiplier(), newMultiplier: 10000})
    );

    console2.log("totalSystemLiquidity", totalSystemLiquidity);

    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), priceChangePercent);

    updateSystemStateSingleMarket(marketIndex);

    int256[2] memory fundingAmounts = calculateFundingAmount(uint8(IMarketCommon.PoolType.LONG), 1000e18, 700e18, IMarket(address(market)));

    assertEq(
      market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1),
      200e18 - (uint256(fundingAmounts[1]) * 1e18) / 5e18,
      "Long pool 1 value is incorrect"
    );
    assertEq(
      market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2),
      400e18 - (uint256(fundingAmounts[1]) * 4e18) / 5e18,
      "Long pool 2 value is incorrect"
    );
    assertEq(
      market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1),
      100e18 - (uint256(-fundingAmounts[0]) * 1e18) / 7e18,
      "Short pool 1 value is incorrect"
    );
    assertEq(
      market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2),
      300e18 - (uint256(-fundingAmounts[0]) * 6e18) / 7e18,
      "Short pool 2 value is incorrect"
    );
    assertEq(
      market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF),
      100e18 + uint256(-fundingAmounts[0]) + uint256(fundingAmounts[1]),
      "Float pool 1 value is incorrect"
    );
    assertApproxEqAbs(
      market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL1) +
        market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndexL2) +
        market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS1) +
        market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndexS2) +
        market.get_pool_value(IMarketCommon.PoolType.FLOAT, poolIndexF),
      totalSystemLiquidity,
      5,
      "Total System Liquidity should remain the same"
    );
  }

  function testEpochInfoAtDeployment() public {
    assertEq(
      getPreviousEpochEndTimestamp(),
      defaultOracleManager.getEpochStartTimestamp(),
      "Previous epoch end timetstamp needs to equal start of current epoch start timestamp at deployment."
    );
    (uint80 latestRoundId, , , , ) = defaultOracleManager.chainlinkOracle().latestRoundData();

    assertEq(getPreviousExecutedEpochIndex(), 0, "Latest executed epoch needs be 0 at deployment.");
    assertLe(getPreviousOraclePriceIdentifier(), latestRoundId, "Latest oracle index at deployment cannot be greater than latest round ID");
  }

  function testAddingPoolsToExistingMarket(uint256 poolTypeInt) public {
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);

    uint256 initialEffectiveLiquidityForNewPool = 100e18;

    int96 newPoolLeverage = 3e18;

    IMarketExtended.SinglePoolInitInfo memory newPool = IMarketExtendedCore.SinglePoolInitInfo(
      string.concat(Strings.toString(uint256(int256(newPoolLeverage)) / 1e18), "x PoolToken Long"),
      string.concat(Strings.toString(uint256(int256(newPoolLeverage)) / 1e18), "xML"),
      poolType,
      2,
      address(marketFactory.deployPoolToken(address(market), poolType, 2)),
      uint96(newPoolLeverage)
    );

    uint256 numberOfPoolsOfType = market.numberOfPoolsOfType(poolType);

    uint256 totalActualLiquidityBeforeAddingNewPool = calculateActualLiquidity();

    vm.startPrank(ADMIN);

    defaultPaymentToken.approve(address(market), initialEffectiveLiquidityForNewPool);

    MarketExtended(address(market)).addPoolToExistingMarket(newPool, initialEffectiveLiquidityForNewPool, ADMIN, marketIndex);

    uint128[2] memory totalEffectiveLiquidityAfterAddingNewPool = market.get_effectiveLiquidityForPoolType();
    uint256 floatPoolLiquidity = market.get_pool_value(IMarketCommon.PoolType.FLOAT, 0);

    assertEq(market.numberOfPoolsOfType(poolType), numberOfPoolsOfType + 1, "New pool should have been added");
    assertEq(market.get_pool_value(poolType, numberOfPoolsOfType), initialEffectiveLiquidityForNewPool, "New pool seed value is incorrect");
    assertEq(
      market.get_pool_leverage(poolType, numberOfPoolsOfType),
      poolType == IMarketCommon.PoolType.LONG ? newPoolLeverage : -newPoolLeverage,
      " leverage is incorrect"
    );
    assertEq(
      calculateActualLiquidity(),
      totalActualLiquidityBeforeAddingNewPool + initialEffectiveLiquidityForNewPool,
      "Total liquidity after adding new pool should increase by value of new pool"
    );

    uint256 totalActualLiquidityBeforePriceChange = calculateActualLiquidity();

    int256 previousPrice = 1e18;
    mockChainlinkOracleNextPrice(previousPrice);
    int256 priceMovement = 1e17;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(priceMovement);
    updateSystemStateSingleMarket(defaultMarketIndex);

    initialEffectiveLiquidityForNewPool = uint256(
      int256(initialEffectiveLiquidityForNewPool) +
        valueChangeForPool(
          poolType,
          uint8(numberOfPoolsOfType),
          totalEffectiveLiquidityAfterAddingNewPool,
          floatPoolLiquidity,
          previousPrice,
          initialEffectiveLiquidityForNewPool
        )
    );

    assertEq(
      market.get_pool_value(poolType, numberOfPoolsOfType),
      initialEffectiveLiquidityForNewPool,
      "Pool value after liquidity shift is incorrect"
    );

    // rounding error causes the resultant value to be off by 1, therefore using assertApproxEqAbs
    assertApproxEqAbs(
      calculateActualLiquidity(),
      totalActualLiquidityBeforePriceChange,
      1,
      "Total liquidity should remain the same after a price change"
    );

    vm.stopPrank();
  }

  // This function is purely for testing and can be removed... @jasoons
  function calculateActualLiquidity() public view returns (uint256 actualLiquidity) {
    for (uint8 poolType = uint8(IMarketCommon.PoolType.SHORT); poolType <= uint8(IMarketCommon.PoolType.LONG); poolType++) {
      uint256 maxPoolTier = market.numberOfPoolsOfType(IMarketCommon.PoolType(poolType));
      for (uint256 poolTier = 0; poolTier < maxPoolTier; poolTier++) {
        actualLiquidity += market.get_pool_value(IMarketCommon.PoolType(poolType), poolTier);
      }
    }
  }

  function testAccessControlOnFloatPoolMinting() public {
    address newFloatRoleUser = address(11111);
    address attacker = address(99999);
    uint112 amountToMint = 100e18;

    dealPaymentTokenWithMarketApproval(marketIndex, attacker);
    dealPaymentTokenWithMarketApproval(marketIndex, newFloatRoleUser);
    dealPaymentTokenWithMarketApproval(marketIndex, ADMIN);

    // Attacker can't mint in FLOAT pool.
    vm.startPrank(attacker);
    bytes32 floatPoolRole = market.get_FLOAT_POOL_ROLE();

    string memory message = string.concat(
      "AccessControl: account ",
      string.concat(Strings.toHexString(attacker), string.concat(" is missing role ", Strings.toHexString(uint256(floatPoolRole))))
    );
    vm.expectRevert(bytes(message));
    market.mintFloatPool(amountToMint);
    vm.stopPrank();

    // Admin can mint in FLOAT pool (since they start as a FloatPool user).
    AccessControlledAndUpgradeable marketAccessCortrol = AccessControlledAndUpgradeable(address(market));
    bytes32 floatPoolRoleAdmin = marketAccessCortrol.getRoleAdmin(floatPoolRole);
    assertEq(floatPoolRoleAdmin, marketAccessCortrol.ADMIN_ROLE(), "FloatPool user role admin should be ADMIN_ROLE");

    assertTrue(marketAccessCortrol.hasRole(marketAccessCortrol.ADMIN_ROLE(), ADMIN), "Admin should have ADMIN role");
    assertTrue(marketAccessCortrol.hasRole(floatPoolRole, ADMIN), "Admin should have FloatPool user role");
    assertTrue(marketAccessCortrol.hasRole(floatPoolRole, ADMIN), "Admin should have FloatPool user role");

    vm.startPrank(ADMIN);
    market.mintFloatPool(amountToMint);

    // Remove market as a FloatPool user.
    marketAccessCortrol.revokeRole(floatPoolRole, ADMIN);
    assertFalse(marketAccessCortrol.hasRole(floatPoolRole, ADMIN), "Admin should NOT have FloatPool user role");

    // ADMIN can still grant FloatPool user role since it is role admin
    marketAccessCortrol.grantRole(floatPoolRole, newFloatRoleUser);
    assertTrue(marketAccessCortrol.hasRole(floatPoolRole, newFloatRoleUser), "Admin should have FloatPool user role");

    vm.stopPrank();

    vm.startPrank(newFloatRoleUser);
    // FloatPool user can mint in Float pool.
    market.mintFloatPool(amountToMint);

    // FloatPool user can renounce its own role.
    marketAccessCortrol.renounceRole(floatPoolRole, newFloatRoleUser);
    assertFalse(marketAccessCortrol.hasRole(floatPoolRole, newFloatRoleUser), "FloatPoolUser should NOT have FloatPool user role");
    vm.stopPrank();
  }
}
