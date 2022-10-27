// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../../testing/FloatTest.t.sol";
import "forge-std/console2.sol";

contract MarketTieredLeveragePauseAndDeprecationTest is FloatTest {
  uint256 initialPoolLiquidity;
  // MarketFactory.PoolLeverage[] poolLeverages;

  uint32 marketIndex;
  IMarket market;
  IMarketExtended marketExtended;
  address marketAddress;
  IERC20 paymentToken;

  constructor() {
    initialPoolLiquidity = 100e18;
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
      DEFAULT_MARKET_TYPE
    );

    market = marketFactory.market(marketIndex);
    marketExtended = marketFactory.marketExtended(marketIndex);
    marketAddress = marketFactory.marketAddress(marketIndex);
    paymentToken = marketFactory.paymentToken(marketIndex);
    deal(address(paymentToken), ADMIN, 1e22);

    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    updateSystemStateSingleMarket(marketIndex);
  }

  function testMintingNotCallableAfterMintingIsPaused() public {
    address user = getFreshUser();

    vm.startPrank(ADMIN);
    marketExtended.pauseMinting();

    changePrank(user);
    vm.expectRevert(IMarketCore.MintingPaused.selector);
    market.mintLong(0, 1e18);
    vm.expectRevert(IMarketCore.MintingPaused.selector);

    market.mintShort(0, 1e18);
    vm.stopPrank();
  }

  function testOtherFunctionsAreCallableWhenMintingIsPaused() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    uint112 amount = 10e18;

    dealPoolToken(marketIndex, user, IMarketCommon.PoolType.SHORT, 0, amount);
    dealPoolToken(marketIndex, user, IMarketCommon.PoolType.LONG, 0, amount);

    vm.startPrank(ADMIN);
    marketExtended.pauseMinting();

    changePrank(user);
    market.redeemShort(0, 1e18);
    market.redeemLong(0, 1e18);
    updateSystemStateSingleMarket(marketIndex);

    settleAllUserActions(market, user);
    vm.stopPrank();
  }

  function testNormalBehaviourAfterMintingIsUnpaused() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    uint112 amount = 10e18;

    vm.startPrank(ADMIN);
    marketExtended.pauseMinting();
    marketExtended.unpauseMinting();
    vm.stopPrank();

    dealPoolToken(marketIndex, user, IMarketCommon.PoolType.SHORT, 0, amount);
    dealPoolToken(marketIndex, user, IMarketCommon.PoolType.LONG, 0, amount);

    vm.startPrank(user);
    updateSystemStateSingleMarket(marketIndex);
    market.redeemShort(0, 1e18);
    market.redeemLong(0, 1e18);
    updateSystemStateSingleMarket(marketIndex);

    settleAllUserActions(market, user);
    vm.stopPrank();
  }

  function testNonAdminAccountCannotPauseMinting() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    vm.startPrank(user);
    bytes32 adminRole = market.ADMIN_ROLE();
    string memory message = string.concat(
      "AccessControl: account ",
      string.concat(Strings.toHexString(user), string.concat(" is missing role ", Strings.toHexString(uint256(adminRole))))
    );
    vm.expectRevert(bytes(message));
    marketExtended.pauseMinting();
    vm.stopPrank();
  }

  function testNonAdminAccountCannotUnpauseMinting() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    vm.startPrank(ADMIN);
    marketExtended.pauseMinting();

    changePrank(user);
    bytes32 adminRole = market.ADMIN_ROLE();
    string memory message = string.concat(
      "AccessControl: account ",
      string.concat(Strings.toHexString(user), string.concat(" is missing role ", Strings.toHexString(uint256(adminRole))))
    );
    vm.expectRevert(bytes(message));
    marketExtended.unpauseMinting();
    vm.stopPrank();
  }

  function broken_testAllFunctionsNotCallableAfterMarketIsDeprecated() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    vm.startPrank(ADMIN);
    market.deprecateMarket();

    changePrank(user);
    vm.expectRevert(IMarketCore.MintingPaused.selector);

    market.mintLong(0, 1e18);
    vm.expectRevert(IMarketCore.MintingPaused.selector);

    market.mintShort(0, 1e18);
    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    market.redeemShort(0, 1e18);
    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    market.redeemLong(0, 1e18);
    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    updateSystemStateSingleMarket(marketIndex);

    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    settleAllUserActions(market, user);
    vm.stopPrank();
  }

  function testExitFunctionsNotCallableBeforeMarketIsDeprecated() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    vm.startPrank(ADMIN);

    changePrank(user);
    vm.expectRevert("Market is not deprecated");
    market.exitDeprecatedMarket(user);
    vm.stopPrank();
  }

  function testExitFunctionsNotCallableForZeroAddress() public {
    vm.startPrank(ADMIN);
    market.deprecateMarket();
    vm.expectRevert("User can't be 0 or seeder");
    market.exitDeprecatedMarket(address(0));
    vm.stopPrank();
  }

  function testExitFunctionsNotCallableForSeederAddress() public {
    vm.startPrank(ADMIN);
    market.deprecateMarket();
    address seeder = marketExtended.getSeederAddress();
    vm.expectRevert("User can't be 0 or seeder");
    market.exitDeprecatedMarket(seeder);
    vm.stopPrank();
  }

  function testExitFunctionsIsCallableByUserAfterMarketIsDeprecated() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    vm.startPrank(ADMIN);
    market.deprecateMarket();

    changePrank(user);
    market.exitDeprecatedMarket(user);
    vm.stopPrank();
  }

  function testNonAdminAccountCannotDeprecateMarket() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    vm.startPrank(user);
    bytes32 adminRole = defaultMarket.ADMIN_ROLE();
    string memory message = string.concat(
      "AccessControl: account ",
      string.concat(Strings.toHexString(user), string.concat(" is missing role ", Strings.toHexString(uint256(adminRole))))
    );
    vm.expectRevert(bytes(message));
    market.deprecateMarket();
    vm.stopPrank();
  }

  function testExitFunctionAllowsUserToRemovePoolTokens(
    uint112 amount,
    uint32 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);
    amount = 1e18 + (amount % uint112(paymentToken.balanceOf(user) - 1e18));
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(market.numberOfPoolsOfType(poolType));

    dealPoolToken(marketIndex, user, poolType, poolIndex, amount);
    uint256 poolTokenBalance = poolTokenBalance(marketIndex, user, poolType, poolIndex);
    uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(user);

    warpToEndOfMewtInNextEpoch(marketIndex);

    uint256 expectedPayout = (getPoolTokenPrice(marketIndex, poolType, poolIndex) * poolTokenBalance) / 1e18;

    vm.startPrank(ADMIN);
    market.deprecateMarket();
    market.exitDeprecatedMarket(user);
    vm.stopPrank();

    uint256 actualPayout = paymentToken.balanceOf(user) - paymentTokenBalanceBefore;

    assertEq(actualPayout, expectedPayout, "Incorrect amount of payment tokens returned to user");
  }

  function testExitFunctionAllowsUserToRedeemPoolTokensOnlyOnce(
    uint112 amount,
    uint32 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);
    amount = 1e18 + (amount % uint112(paymentToken.balanceOf(user) - 1e18));
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(market.numberOfPoolsOfType(poolType));

    dealPoolToken(marketIndex, user, poolType, poolIndex, amount);

    warpToEndOfMewtInNextEpoch(marketIndex);

    vm.startPrank(ADMIN);
    market.deprecateMarket();

    market.exitDeprecatedMarket(user);
    uint256 balanceAfterFirstCall = paymentToken.balanceOf(user);

    market.exitDeprecatedMarket(user);
    uint256 balanceAfterSecondCall = paymentToken.balanceOf(user);

    vm.stopPrank();

    assertEq(balanceAfterFirstCall, balanceAfterSecondCall, "User was able to exit twice");
  }

  function testExitFunctionAllowsMultipleUsersToRemovePoolTokens(
    uint112 amount1,
    uint112 amount2,
    uint32 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user1 = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user1);
    amount1 = 1e18 + (amount1 % uint112(paymentToken.balanceOf(user1) - 1e18));

    address user2 = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user2);
    amount2 = 1e18 + (amount2 % uint112(paymentToken.balanceOf(user2) - 1e18));

    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(market.numberOfPoolsOfType(poolType));

    dealPoolToken(marketIndex, user1, poolType, poolIndex, amount1);
    dealPoolToken(marketIndex, user2, poolType, poolIndex, amount2);

    uint256 poolTokenBalance1 = poolTokenBalance(marketIndex, user1, poolType, poolIndex);
    uint256 poolTokenBalance2 = poolTokenBalance(marketIndex, user2, poolType, poolIndex);
    uint256 paymentTokenBalanceBefore1 = paymentToken.balanceOf(user1);
    uint256 paymentTokenBalanceBefore2 = paymentToken.balanceOf(user2);

    warpToEndOfMewtInNextEpoch(marketIndex);

    uint256 expectedPayout1 = (getPoolTokenPrice(marketIndex, poolType, poolIndex) * poolTokenBalance1) / 1e18;
    uint256 expectedPayout2 = (getPoolTokenPrice(marketIndex, poolType, poolIndex) * poolTokenBalance2) / 1e18;

    vm.startPrank(ADMIN);
    market.deprecateMarket();
    market.exitDeprecatedMarket(user1);
    market.exitDeprecatedMarket(user2);
    vm.stopPrank();

    uint256 actualPayout1 = paymentToken.balanceOf(user1) - paymentTokenBalanceBefore1;
    uint256 actualPayout2 = paymentToken.balanceOf(user2) - paymentTokenBalanceBefore2;

    // NOTE: in rare edge cases this is off by 2 due to rounding errors. These rounding errors will be absorbed by the market seed and have no effect on the pool.
    assertApproxEqAbs(actualPayout1, expectedPayout1, 2, "Incorrect amount of payment tokens returned to user1");
    assertApproxEqAbs(actualPayout2, expectedPayout2, 2, "Incorrect amount of payment tokens returned to user2");
  }

  function testExitFunctionAllowsUserToRemovePendingDeposits(
    uint112 amount,
    uint32 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);
    amount = 1e18 + (amount % uint112(paymentToken.balanceOf(user) - 1e18));
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(market.numberOfPoolsOfType(poolType));

    uint256 balanceBeforeMint = paymentToken.balanceOf(user);

    vm.startPrank(user);
    mint(marketIndex, poolType, poolIndex, amount);

    changePrank(ADMIN);
    market.deprecateMarket();
    market.exitDeprecatedMarket(user);
    vm.stopPrank();

    uint256 balanceAfterDeprecation = paymentToken.balanceOf(user);

    assertEq(balanceBeforeMint, balanceAfterDeprecation, "User did not get back the same amount of payment tokens as they gave");
  }

  function testExitFunctionAllowsUserToRemovePastUnclaimedDeposits(
    uint112 amount,
    uint32 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);
    amount = 1e18 + (amount % uint112(paymentToken.balanceOf(user) - 1e18));
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(market.numberOfPoolsOfType(poolType));

    uint256 balanceBeforeMint = paymentToken.balanceOf(user);

    vm.startPrank(user);
    warpOutsideOfMewt(marketIndex);
    mint(marketIndex, poolType, poolIndex, amount);
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength(marketIndex);
    updateSystemStateSingleMarket(marketIndex);

    changePrank(ADMIN);
    market.deprecateMarket();
    market.exitDeprecatedMarket(user);
    vm.stopPrank();

    uint256 balanceAfterDeprecation = paymentToken.balanceOf(user);

    assertEq(balanceBeforeMint, balanceAfterDeprecation, "User did not get back the same amount of payment tokens as they gave");
  }

  function testExitFunctionAllowsUserToRemovePendingRedeems(
    uint112 amount,
    uint32 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);
    amount = 1e18 + (amount % uint112(paymentToken.balanceOf(user) - 1e18));
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(market.numberOfPoolsOfType(poolType));

    dealPoolToken(marketIndex, user, poolType, poolIndex, amount);
    uint256 poolTokenBalance = poolTokenBalance(marketIndex, user, poolType, poolIndex);
    uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(user);

    vm.startPrank(user);
    warpOutsideOfMewt(marketIndex);
    redeem(marketIndex, poolType, poolIndex, uint112(poolTokenBalance));

    uint256 expectedPayout = (getPoolTokenPrice(marketIndex, poolType, poolIndex) * poolTokenBalance) / 1e18;

    changePrank(ADMIN);
    market.deprecateMarket();
    market.exitDeprecatedMarket(user);
    vm.stopPrank();

    uint256 actualPayout = paymentToken.balanceOf(user) - paymentTokenBalanceBefore;

    assertEq(actualPayout, expectedPayout, "Incorrect amount of payment tokens returned to user");
  }

  function testExitFunctionAllowsUserToRemovePastUnclaimedRedeems(
    uint112 amount,
    uint32 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);
    amount = 1e18 + (amount % uint112(paymentToken.balanceOf(user) - 1e18));
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(market.numberOfPoolsOfType(poolType));

    dealPoolToken(marketIndex, user, poolType, poolIndex, amount);
    uint256 poolTokenBalance = poolTokenBalance(marketIndex, user, poolType, poolIndex);
    uint256 paymentTokenBalanceBefore = paymentToken.balanceOf(user);

    vm.startPrank(user);
    warpOutsideOfMewt(marketIndex);
    redeem(marketIndex, poolType, poolIndex, uint112(poolTokenBalance));
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength(marketIndex);
    updateSystemStateSingleMarket(marketIndex);

    uint256 expectedPayout = (getPoolTokenPrice(marketIndex, poolType, poolIndex) * poolTokenBalance) / 1e18;

    changePrank(ADMIN);
    market.deprecateMarket();
    market.exitDeprecatedMarket(user);
    vm.stopPrank();

    uint256 actualPayout = paymentToken.balanceOf(user) - paymentTokenBalanceBefore;

    assertEq(actualPayout, expectedPayout, "Incorrect amount of payment tokens returned to user");
  }

  function broken_testNoOraclePriceAutoDeprecatesMarket() public {
    // no oracle price in the epoch
    warpOneEpochLength();
    warpOneEpochLength();

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    assertEq(marketExtended.get_marketDeprecated(), true, "Market should have auto-deprecated");
  }

  function broken_testNoOraclePriceMakesActionsFail() public {
    // no oracle price in the epoch
    warpOneEpochLength();
    warpOneEpochLength();

    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);

    vm.startPrank(user);
    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    market.mintLong(0, 1e18);
    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    market.mintShort(0, 1e18);
    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    market.redeemShort(0, 1e18);
    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    market.redeemLong(0, 1e18);
    vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    settleAllUserActions(market, user);
    vm.stopPrank();
  }

  function testUpdateAllowedAfterNoOraclePrice() public {
    // no oracle price in the epoch
    warpOneEpochLength();
    warpOneEpochLength();

    address user = getFreshUser();
    vm.startPrank(user);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();
  }

  function testMaualDeprecateAllowedAfterNoOraclePrice() public {
    // no oracle price in the epoch
    warpOneEpochLength();
    warpOneEpochLength();

    vm.startPrank(ADMIN);
    market.deprecateMarket();
    vm.stopPrank();
  }

  function broken_testExitAllowedAfterNoOraclePrice() public {
    address user = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, user);
    uint112 amount = 10e18;
    dealPoolToken(marketIndex, user, IMarketCommon.PoolType.SHORT, 0, amount);

    // no oracle price in the epoch
    warpOneEpochLength();
    warpOneEpochLength();

    vm.startPrank(user);
    market.exitDeprecatedMarket(user);
    vm.stopPrank();
  }

  function testLatestExecutedEpochIndexUpdatesCorrectlyAfterNoOraclePrice() public {
    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();
    assertEq(
      epochInfo.latestExecutedEpochIndex,
      marketFactory.oracleManager(marketIndex).getCurrentEpochIndex() - 1,
      "LatestExecutedEpochIndex before test is incorrect"
    );

    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    // no oracle price in the epoch
    warpOneEpochLength();
    warpOneEpochLength();

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    assertEq(
      market.get_epochInfo().latestExecutedEpochIndex,
      epochInfo.latestExecutedEpochIndex,
      "LatestExecutedEpochIndex after auto-deprecate is incorrect"
    );
  }

  function testLatestExecutedEpochIndexUpdatesCorrectlyForManyEpochsAfterNoOraclePrice() public {
    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();
    assertEq(
      epochInfo.latestExecutedEpochIndex,
      marketFactory.oracleManager(marketIndex).getCurrentEpochIndex() - 1,
      "LatestExecutedEpochIndex before test is incorrect"
    );

    // many epochs to execute
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    // no oracle price in the epoch
    warpOneEpochLength();
    warpOneEpochLength();

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    assertEq(
      market.get_epochInfo().latestExecutedEpochIndex,
      epochInfo.latestExecutedEpochIndex,
      "LatestExecutedEpochIndex after auto-deprecate is incorrect"
    );
  }

  function testLatestExecutedEpochIndexUpdatesCorrectlyAfterNoOraclePricesForManyEpochs() public {
    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();
    assertEq(
      epochInfo.latestExecutedEpochIndex,
      marketFactory.oracleManager(marketIndex).getCurrentEpochIndex() - 1,
      "LatestExecutedEpochIndex before test is incorrect"
    );

    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    // no oracle price in the epoch
    warpOneEpochLength();
    warpOneEpochLength();
    warpOneEpochLength();
    warpOneEpochLength();
    warpOneEpochLength();
    warpOneEpochLength();
    warpOneEpochLength();
    warpOneEpochLength();

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    assertEq(
      market.get_epochInfo().latestExecutedEpochIndex,
      epochInfo.latestExecutedEpochIndex,
      "LatestExecutedEpochIndex after auto-deprecate is incorrect"
    );
  }

  function broken_testLatestExecutedEpochIndexUpdatesCorrectlyAfterNoOraclePriceforEpochThenOraclePricesForFutureEpochs() public {
    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();
    assertEq(
      epochInfo.latestExecutedEpochIndex,
      marketFactory.oracleManager(marketIndex).getCurrentEpochIndex() - 1,
      "LatestExecutedEpochIndex before test is incorrect"
    );

    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    // no oracle price in the epoch
    warpOneEpochLength();

    // oracle price in next epoch
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    assertTrue(marketExtended.get_marketDeprecated(), "Market should have auto-deprecated");
    assertEq(
      market.get_epochInfo().latestExecutedEpochIndex,
      epochInfo.latestExecutedEpochIndex,
      "LatestExecutedEpochIndex after auto-deprecate is incorrect"
    );
  }

  function testLatestExecutedEpochIndexUpdatesCorrectlyAfterManualDeprecation() public {
    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    vm.startPrank(ADMIN);
    updateSystemStateSingleMarket(marketIndex);

    vm.stopPrank();

    IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();
    assertEq(
      epochInfo.latestExecutedEpochIndex,
      marketFactory.oracleManager(marketIndex).getCurrentEpochIndex() - 1,
      "LatestExecutedEpochIndex before test is incorrect"
    );

    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);

    vm.startPrank(ADMIN);
    market.deprecateMarket();
    vm.stopPrank();

    assertEq(
      market.get_epochInfo().latestExecutedEpochIndex,
      epochInfo.latestExecutedEpochIndex + 2,
      "LatestExecutedEpochIndex after deprecation is incorrect"
    );
  }
}
