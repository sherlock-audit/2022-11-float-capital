// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import "../testing/MarketFactory.t.sol";
import "../testing/FloatTest.t.sol";
import "./UserActionsManyEpochs.t.sol";

contract UserActionsSingleEpochTest is UserActionsManyEpochsTestBase {
  uint8 numEpochs = 1;

  function testUserMintingAtTwoPointsInEpoch(
    uint32 options, // determines which path the test takes
    uint8 poolTypeInt,
    uint8 poolIndex,
    uint112 amount
  ) public {
    _testManyUserMintingAtTwoPointsInEpoch(options, numEpochs, poolTypeInt, poolIndex, amount);
  }

  function testUserRedeemingAtTwoPointsInEpoch(
    uint32 options, // determines which path the test takes
    uint8 poolTypeInt,
    uint8 poolIndex,
    uint112 amount
  ) public {
    _testManyUserRedeemingAtTwoPointsInEpoch(options, numEpochs, poolTypeInt, poolIndex, amount);
  }

  function testIntermediateValuesWhenMinting(
    uint112 amount,
    uint256 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user = getFreshUser();
    amount = 1e18 + (amount % uint112(defaultPaymentToken.balanceOf(user) - 1e18));
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(defaultMarket.numberOfPoolsOfType(poolType));

    vm.startPrank(user);

    uint32 currentEpochIndex = uint32(defaultMarket.get_oracleManager().getCurrentEpochIndex());

    mint(poolType, poolIndex, amount);

    IMarketCommon.UserAction memory depositAction = defaultMarket.get_userAction_depositPaymentToken(user, poolType, poolIndex);

    assertEq(depositAction.amount, amount, "deposit action amount seen in market contract not equal to intended amount");
    assertEq(depositAction.correspondingEpoch, currentEpochIndex, "next update index seen in market contract not equal to current epoch index");

    uint256 batchAmount;
    if (currentEpochIndex % 2 == 0) {
      batchAmount = MarketExtended(address(defaultMarket)).get_even_batchedAmountPaymentToken_deposit(poolType, poolIndex);
    } else {
      batchAmount = MarketExtended(address(defaultMarket)).get_odd_batchedAmountPaymentToken_deposit(poolType, poolIndex);
    }
    assertEq(uint256(amount), batchAmount, "Pool batch amount not equal to mint amount");

    vm.stopPrank();
  }

  function testIntermediateValuesWhenRedeeming(
    uint112 amount,
    uint32 poolIndex,
    uint8 poolTypeInt
  ) public {
    address user = getFreshUser();
    amount = 1e18 + (amount % uint112(defaultPaymentToken.balanceOf(user) - 1e18));
    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(defaultMarket.numberOfPoolsOfType(poolType));

    dealPoolToken(user, poolType, poolIndex, uint112(defaultPaymentToken.balanceOf(user)));

    vm.startPrank(user);

    uint112 amountPoolToken = uint112(getPoolToken(poolType, poolIndex).balanceOf(address(user)));
    uint32 currentEpochIndex = uint32(defaultMarket.get_oracleManager().getCurrentEpochIndex());

    if (poolType == IMarketCommon.PoolType.LONG) {
      MarketTieredLeverageInternalStateSetters(address(defaultMarket)).redeemLong(poolIndex, amountPoolToken);
    } else {
      MarketTieredLeverageInternalStateSetters(address(defaultMarket)).redeemShort(poolIndex, amountPoolToken);
    }

    uint256 userBalanceAfter = getPoolToken(poolType, poolIndex).balanceOf(address(user));
    uint256 marketBalanceAfter = getPoolToken(poolType, poolIndex).balanceOf(address(defaultMarket));

    IMarketCommon.UserAction memory redeemAction = defaultMarket.get_userAction_redeemPoolToken(user, poolType, poolIndex);

    assertEq(redeemAction.amount, amountPoolToken, "redeem action amount seen in market contract not equal to intended amount");
    assertEq(redeemAction.correspondingEpoch, currentEpochIndex, "next update index seen in market contract not equal to current epoch index");

    assertEq(userBalanceAfter, 0, "User should have 0 tokens after redeem");

    uint256 amountPoolTokenToRedeem;

    if (currentEpochIndex % 2 == 0) {
      amountPoolTokenToRedeem = MarketExtended(address(defaultMarket)).get_even_batchedAmountPoolToken_redeem(poolType, poolIndex);
    } else {
      amountPoolTokenToRedeem = MarketExtended(address(defaultMarket)).get_odd_batchedAmountPoolToken_redeem(poolType, poolIndex);
    }

    assertEq(uint256(amountPoolToken), amountPoolTokenToRedeem, "long batch not equal");
    assertEq(marketBalanceAfter, amountPoolToken, "Market has users tokens before system update");
    vm.stopPrank();
  }

  function testMintInLongAndShortPoolsInSameEpoch(uint112 amount, uint256 poolIndex) public {
    address user = getFreshUser();
    // The amount must be greater than 2, but less than half of their balance
    // TODO: clean this up, this is very hard to understand, we should clarify this more.
    amount = uint112(2e18 + (amount % (defaultPaymentToken.balanceOf(user) / 2 - 2e18)));

    poolIndex = poolIndex % uint8(defaultMarket.numberOfPoolsOfType(IMarketCommon.PoolType.LONG));

    vm.startPrank(user);

    uint32 currentEpochIndex = uint32(defaultMarket.get_oracleManager().getCurrentEpochIndex());

    mint(IMarketCommon.PoolType.LONG, poolIndex, amount);
    mint(IMarketCommon.PoolType.SHORT, poolIndex, amount);

    IMarketCommon.UserAction memory depositLongAction = defaultMarket.get_userAction_depositPaymentToken(
      user,
      IMarketCommon.PoolType.LONG,
      poolIndex
    );

    assertEq(depositLongAction.amount, amount, "long user deposit amount incorrect");
    assertEq(depositLongAction.correspondingEpoch, currentEpochIndex, "corresponding epoch for long action incorrect");
    {
      uint256 batchAmountLong;
      uint256 batchAmountShort;

      if (currentEpochIndex % 2 == 0) {
        batchAmountLong = MarketExtended(address(defaultMarket)).get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, poolIndex);
        batchAmountShort = MarketExtended(address(defaultMarket)).get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, poolIndex);
      } else {
        batchAmountLong = MarketExtended(address(defaultMarket)).get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, poolIndex);
        batchAmountShort = MarketExtended(address(defaultMarket)).get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, poolIndex);
      }

      assertEq(uint256(amount), batchAmountLong, "long batch deposit amount incorrect");
      assertEq(uint256(amount), batchAmountShort, "short batch deposit amount incorrect");
    }

    IMarketCommon.UserAction memory depositActionShort = defaultMarket.get_userAction_depositPaymentToken(
      user,
      IMarketCommon.PoolType.SHORT,
      poolIndex
    );

    assertEq(depositActionShort.amount, amount, "short user deposit amount incorrect");
    assertEq(depositActionShort.correspondingEpoch, currentEpochIndex, "corresponding epoch for short action incorrect");

    vm.stopPrank();

    // now check the correct tokens are received!

    int256 percent = 1e16;
    warpToEndOfMewtInNextEpoch();
    mockChainlinkOraclePercentPriceMovement(percent);
    updateSystemStateSingleMarket(defaultMarketIndex);

    // tokens should now be issued

    vm.startPrank(user);

    uint256 longPoolMarketPoolTokenBalanceBeforeClaim = getPoolToken(IMarketCommon.PoolType.LONG, poolIndex).balanceOf(address(defaultMarket));
    uint256 shortPoolMarketPoolTokenBalanceBeforeClaim = getPoolToken(IMarketCommon.PoolType.SHORT, poolIndex).balanceOf(address(defaultMarket));

    settleAllUserActions(defaultMarket, user);

    uint256 numTokensLONG = (uint256(amount) * 1e18) / getPoolTokenPrice(IMarketCommon.PoolType.LONG, poolIndex);
    uint256 numTokensSHORT = (uint256(amount) * 1e18) / getPoolTokenPrice(IMarketCommon.PoolType.SHORT, poolIndex);

    // long asserts
    assertEq(getPoolToken(IMarketCommon.PoolType.LONG, poolIndex).balanceOf(address(user)), numTokensLONG, "User should own tokens after update");
    assertEq(longPoolMarketPoolTokenBalanceBeforeClaim, numTokensLONG, "Market contract should own tokens before user claims");
    assertEq(
      getPoolToken(IMarketCommon.PoolType.LONG, poolIndex).balanceOf(address(defaultMarket)),
      0,
      "Market contract should not own tokens after user claims"
    );

    //short asserts
    assertEq(getPoolToken(IMarketCommon.PoolType.SHORT, poolIndex).balanceOf(address(user)), numTokensSHORT, "User should own tokens after update");
    assertEq(shortPoolMarketPoolTokenBalanceBeforeClaim, numTokensSHORT, "Market contract should own tokens before user claims");
    assertEq(
      getPoolToken(IMarketCommon.PoolType.SHORT, poolIndex).balanceOf(address(defaultMarket)),
      0,
      "Market contract should not own tokens after user claims"
    );

    vm.stopPrank();
  }
}
