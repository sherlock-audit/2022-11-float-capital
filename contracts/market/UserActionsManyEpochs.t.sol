// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import "../testing/MarketFactory.t.sol";
import "../testing/FloatTest.t.sol";

contract UserActionsManyEpochsTestBase is FloatTest {
  uint32 optionalActionsPerEpoch;
  uint32 maxActions;

  struct Balances {
    uint256 poolToken;
    uint256 paymentToken;
  }

  Balances poolPrevBalances;
  Balances userPrevBalances;

  uint256 workingVariable_prevEpoch;
  uint256 workingVariable_currEpoch;

  struct State {
    uint128[2] totalEffectiveLiquidity;
    uint256 floatPoolLiquidity;
    int256 oraclePrice;
  }

  State prevState;

  function updateBalances(
    address user,
    IMarketCommon.PoolType poolType,
    uint8 poolIndex
  ) internal {
    userPrevBalances.paymentToken = defaultPaymentToken.balanceOf(user);
    userPrevBalances.poolToken = getPoolToken(poolType, poolIndex).balanceOf(address(user));
    poolPrevBalances.paymentToken = defaultMarket.get_pool_value(poolType, poolIndex);
    poolPrevBalances.poolToken = getPoolToken(poolType, poolIndex).balanceOf(address(defaultMarket));
  }

  function setUp() public {
    userPrevBalances.paymentToken = 0;
    userPrevBalances.poolToken = 0;
    poolPrevBalances.paymentToken = 0;
    poolPrevBalances.poolToken = 0;
  }

  /*
   * epoch starts
   * inside MEWT
   * [option] user action
   * MEWT ends
   * [option] user action
   * epoch ends
   * [repeat twice]
   */
  function _testManyUserMintingAtTwoPointsInEpoch(
    uint32 options, // determines which path the test takes
    uint8 numEpochs,
    uint8 poolTypeInt,
    uint8 poolIndex,
    uint112 amount
  ) internal {
    // we must have numEpochs <= 16 since we need 2^(2*numEpochs) <= type(uint32).max for the options modulo
    numEpochs = 1 + (numEpochs % 14);

    optionalActionsPerEpoch = 2;
    maxActions = optionalActionsPerEpoch * numEpochs;

    address user = getFreshUser();

    vm.startPrank(ADMIN);
    AccessControlledAndUpgradeable marketAccessCortrol = AccessControlledAndUpgradeable(address(defaultMarket));
    marketAccessCortrol.grantRole(defaultMarket.get_FLOAT_POOL_ROLE(), user);
    vm.stopPrank();

    // need amount > 1e18 because of mint requirement inside Market contract
    amount = 2e18 + (amount % uint112(defaultPaymentToken.balanceOf(user) / maxActions - 2e18));

    // the number of unique options available is 2^(number of actions) since each optional action is binary
    options = options % uint32(2**maxActions);

    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 3);
    poolIndex = poolIndex % uint8(defaultMarket.numberOfPoolsOfType(poolType));

    updateBalances(user, poolType, poolIndex);
    prevState.totalEffectiveLiquidity = defaultMarket.get_effectiveLiquidityForPoolType();
    prevState.floatPoolLiquidity = defaultMarket.get_pool_value(IMarketCommon.PoolType.FLOAT, 0);
    prevState.oraclePrice = AggregatorV3InterfaceS(address(defaultOracleManager.chainlinkOracle()))
      .getRoundData((getPreviousOraclePriceIdentifier()))
      .answer;
    workingVariable_prevEpoch = 0;
    workingVariable_currEpoch = 0;
    uint112 randAmount;

    vm.startPrank(user);

    for (uint8 i = 0; i < maxActions; i += 2) {
      mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
      warpToJustBeforeEndOfMewtInNextEpoch();
      mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

      console2.log("\nepochIndex", defaultOracleManager.getCurrentEpochIndex());
      console2.log("\ntimestamp", block.timestamp);
      console2.log("in MEWT? True\n");

      // this is the second possible action in the epoch for the user
      if (options % (2**(i + 1)) >= 2**i) {
        randAmount = rand.randomInRange112(1e18, amount);
        mint(poolType, poolIndex, randAmount);
        workingVariable_currEpoch += randAmount;
      }

      mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
      warpToJustBeforeNextEpoch();
      mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

      console2.log("\nepochIndex", defaultOracleManager.getCurrentEpochIndex());
      console2.log("\ntimestamp", block.timestamp);
      console2.log("in MEWT? False");

      assertEq(
        getPoolToken(poolType, poolIndex).balanceOf(address(defaultMarket)),
        poolPrevBalances.poolToken,
        "Pool token balance should not have changed since previous epoch because the system has not updated"
      );

      assertEq(
        defaultPaymentToken.balanceOf(user),
        userPrevBalances.paymentToken - workingVariable_currEpoch,
        "User payment token value should have decreased by the amount minted in first action"
      );

      assertEq(
        getPoolToken(poolType, poolIndex).balanceOf(address(user)),
        userPrevBalances.poolToken,
        "User Pool token balance should not have changed before epoch is executed"
      );

      updateSystemStateSingleMarket(defaultMarketIndex);
      console2.log("updateSystemStateSingleMarket");

      // the pool token price is 0 when the previous executed epoch is 0
      //   so this assertion results in division by 0
      if (getPreviousExecutedEpochIndex() > 0) {
        assertEq(
          getPoolToken(poolType, poolIndex).balanceOf(address(defaultMarket)),
          poolPrevBalances.poolToken + uint256(getAmountInPoolToken(poolType, poolIndex, uint112(workingVariable_prevEpoch))),
          "Pool token balance should have changed after system state update"
        );
      }
      uint256 usersPoolTokenBalanceBeforeUserSettlement = getPoolToken(poolType, poolIndex).balanceOf(address(user));

      // this is the second possible action in the epoch for the user
      if (options % (2**(i + 2)) >= 2**(i + 1)) {
        randAmount = rand.randomInRange112(1e18, amount);
        mint(poolType, poolIndex, randAmount);
        workingVariable_currEpoch += randAmount;
      } else {
        // no need to run this in the neighboring branch because
        //   it should have been called as part of the mint action

        settleAllUserActions(defaultMarket, user);
      }

      assertEq(
        getPoolToken(poolType, poolIndex).balanceOf(address(user)),
        usersPoolTokenBalanceBeforeUserSettlement,
        "User pool token balance should remain the same before and after the User Settlements"
      );

      assertEq(
        defaultPaymentToken.balanceOf(user),
        userPrevBalances.paymentToken - workingVariable_currEpoch,
        "User payment token value should have decreased by the amount minted in both actions"
      );

      assertEq(
        getPoolToken(poolType, poolIndex).balanceOf(address(user)),
        userPrevBalances.poolToken + uint256(getAmountInPoolToken(poolType, poolIndex, uint112(workingVariable_prevEpoch))),
        "User Pool token balance should have increased after settleAllUserActions"
      );
      int256 valueChangeForPool = valueChangeForPool(
        poolType,
        poolIndex,
        prevState.totalEffectiveLiquidity,
        prevState.floatPoolLiquidity,
        prevState.oraclePrice,
        uint256(poolPrevBalances.paymentToken)
      );

      // TODO: These values should be exactly equal, work out why there is an off-by-one!
      assertApproxEqAbs(
        defaultMarket.get_pool_value(poolType, poolIndex),
        uint256(int256(poolPrevBalances.paymentToken) + int256(workingVariable_prevEpoch) + valueChangeForPool),
        2,
        "Pool payment token value should have changed after system state update by an amount related to transfer function and previous epoch mint amount"
      );

      // TODO: These values should be exactly equal, work out why there is an off-by-one!
      assertApproxEqAbs(
        getPoolToken(poolType, poolIndex).balanceOf(address(defaultMarket)),
        poolPrevBalances.poolToken,
        1,
        "Pool token balance should not have changed since previous epoch because the user has claimed their tokens"
      );

      // update the loop variables:

      workingVariable_prevEpoch = workingVariable_currEpoch;
      workingVariable_currEpoch = 0;

      updateBalances(user, poolType, poolIndex);

      prevState.oraclePrice = AggregatorV3InterfaceS(address(defaultOracleManager.chainlinkOracle()))
        .getRoundData((getPreviousOraclePriceIdentifier()))
        .answer;
      prevState.totalEffectiveLiquidity = defaultMarket.get_effectiveLiquidityForPoolType();
      prevState.floatPoolLiquidity = defaultMarket.get_pool_value(IMarketCommon.PoolType.FLOAT, 0);
    }

    vm.stopPrank();
  }

  /*
   * epoch starts
   * inside MEWT
   * [option] user action
   * MEWT ends
   * [option] user action
   * epoch ends
   * [repeat twice]
   */
  function _testManyUserRedeemingAtTwoPointsInEpoch(
    uint32 options, // determines which path the test takes
    uint8 numEpochs,
    uint8 poolTypeInt,
    uint8 poolIndex,
    uint112 amount
  ) public {
    // we must have numEpochs <= 16 since we need 2^(2*numEpochs) <= type(uint32).max for the options modulo
    numEpochs = 1 + (numEpochs % 14);

    optionalActionsPerEpoch = 2;
    maxActions = optionalActionsPerEpoch * numEpochs;

    address user = getFreshUser();

    // the number of unique options available is 2^(number of actions) since each optional action is binary
    options = options % uint32(2**maxActions);

    IMarketCommon.PoolType poolType = IMarketCommon.PoolType(poolTypeInt % 2);
    poolIndex = poolIndex % uint8(defaultMarket.numberOfPoolsOfType(poolType));

    dealPoolToken(user, poolType, poolIndex, uint112(defaultPaymentToken.balanceOf(user)));

    // need amount > 1e18 because of mint requirement inside Market contract
    amount =
      1e18 +
      (amount %
        uint112(PoolToken(MarketExtended(address(defaultMarket)).getPoolTokenAddress(poolType, poolIndex)).balanceOf(user) / maxActions - 1e18));

    updateBalances(user, poolType, poolIndex);
    prevState.oraclePrice = AggregatorV3InterfaceS(address(defaultOracleManager.chainlinkOracle()))
      .getRoundData((getPreviousOraclePriceIdentifier()))
      .answer;
    prevState.totalEffectiveLiquidity = defaultMarket.get_effectiveLiquidityForPoolType();
    prevState.floatPoolLiquidity = defaultMarket.get_pool_value(IMarketCommon.PoolType.FLOAT, 0);
    workingVariable_prevEpoch = 0;
    workingVariable_currEpoch = 0;
    uint112 randAmount;

    vm.startPrank(user);

    for (uint8 i = 0; i < maxActions; i += 2) {
      mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
      warpToJustBeforeEndOfMewtInNextEpoch();
      mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

      console2.log("mmmmmmmmmw");
      console2.log("epochIndex", defaultOracleManager.getCurrentEpochIndex());
      console2.log("mmmmmmmmm");
      console2.log("timestamp", block.timestamp);
      console2.log("in MEWT? True");
      console2.log("mmmmmmmmm");

      // this is the first possible redeem in the epoch for the user
      if (options % (2**(i + 1)) >= 2**i) {
        randAmount = rand.randomInRange112(0, amount);
        redeem(poolType, poolIndex, randAmount);
        workingVariable_currEpoch += randAmount;
      }

      mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
      warpToJustBeforeNextEpoch();
      mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

      console2.log("mmmmmmmmmw");
      console2.log("epochIndex", defaultOracleManager.getCurrentEpochIndex());
      console2.log("mmmmmmmmm");
      console2.log("timestamp", block.timestamp);
      console2.log("in MEWT? False");
      console2.log("mmmmmmmmm");

      assertEq(
        getPoolToken(poolType, poolIndex).balanceOf(address(defaultMarket)),
        poolPrevBalances.poolToken + workingVariable_currEpoch,
        "Pool token balance should have increased since previous epoch by current epoch redeem amount because system state update has not been called yet, so prev epoch redeemed tokens have not been burned yet"
      );

      updateSystemStateSingleMarket(defaultMarketIndex);

      assertEq(
        defaultPaymentToken.balanceOf(user),
        userPrevBalances.paymentToken,
        "User payment token value should not have changed since previous epoch after a system update"
      );

      // this is the second possible redeem in the epoch for the user
      if (options % (2**(i + 2)) >= 2**(i + 1)) {
        randAmount = rand.randomInRange112(0, amount);
        redeem(poolType, poolIndex, randAmount);
        workingVariable_currEpoch += randAmount;
      } else {
        // no need to run this in the neighboring branch because
        //   it should have been called as part of the redeem action
        settleAllUserActions(defaultMarket, user);
      }

      assertEq(
        defaultPaymentToken.balanceOf(user),
        uint256(getAmountInPaymentToken(poolType, poolIndex, uint112(workingVariable_prevEpoch))) + userPrevBalances.paymentToken,
        "User payment token balance should have increased by amount related to previous epoch redeems"
      );

      assertEq(
        getPoolToken(poolType, poolIndex).balanceOf(address(user)),
        userPrevBalances.poolToken - workingVariable_currEpoch,
        "User Pool token balance should have decreased by amount redeemed in current epoch"
      );

      assertEq(
        defaultMarket.get_pool_value(poolType, poolIndex),
        uint256(
          int256(poolPrevBalances.paymentToken) -
            int256(uint256(getAmountInPaymentToken(poolType, poolIndex, uint112(workingVariable_prevEpoch)))) +
            valueChangeForPool(
              poolType,
              poolIndex,
              prevState.totalEffectiveLiquidity,
              prevState.floatPoolLiquidity,
              prevState.oraclePrice,
              poolPrevBalances.paymentToken
            )
        ),
        "Pool payment token balance should have changed after system state update by an amount related to transfer function and previous epoch redeem amount"
      );

      assertEq(
        getPoolToken(poolType, poolIndex).balanceOf(address(defaultMarket)),
        poolPrevBalances.poolToken - workingVariable_prevEpoch + workingVariable_currEpoch,
        "Pool token balance should have decreased since previous epoch by the previous epoch redeem amount because system state update has been called so tokens should have been burned"
      );

      // update the loop variables:

      workingVariable_prevEpoch = workingVariable_currEpoch;
      workingVariable_currEpoch = 0;

      updateBalances(user, poolType, poolIndex);

      prevState.oraclePrice = AggregatorV3InterfaceS(address(defaultOracleManager.chainlinkOracle()))
        .getRoundData((getPreviousOraclePriceIdentifier()))
        .answer;
      prevState.totalEffectiveLiquidity = defaultMarket.get_effectiveLiquidityForPoolType();
      prevState.floatPoolLiquidity = defaultMarket.get_pool_value(IMarketCommon.PoolType.FLOAT, 0);
    }

    vm.stopPrank();
  }
}

contract UserActionsManyEpochsTest is UserActionsManyEpochsTestBase {
  function testManyUserMintingAtTwoPointsInEpoch(
    uint32 options, // determines which path the test takes
    uint8 numEpochs,
    uint8 poolTypeInt,
    uint8 poolIndex,
    uint112 amount
  ) public {
    _testManyUserMintingAtTwoPointsInEpoch(
      options, // determines which path the test takes
      numEpochs,
      poolTypeInt,
      poolIndex,
      amount
    );
  }

  function testManyUserRedeemingAtTwoPointsInEpoch(
    uint32 options, // determines which path the test takes
    uint8 numEpochs,
    uint8 poolTypeInt,
    uint8 poolIndex,
    uint112 amount
  ) public {
    _testManyUserRedeemingAtTwoPointsInEpoch(
      options, // determines which path the test takes
      numEpochs,
      poolTypeInt,
      poolIndex,
      amount
    );
  }

  function testManyUserRedeemingAtTwoPointsInEpochRoundingIssue() public {
    _testManyUserRedeemingAtTwoPointsInEpoch(0, 6, 0, 0, 0);
  }

  function testManyUserRedeemingAtTwoPointsInEpochRoundingIssue2() public {
    _testManyUserRedeemingAtTwoPointsInEpoch(1378, 109, 182, 197, 13175);
  }
}
