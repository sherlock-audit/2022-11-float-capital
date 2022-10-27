// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "./CoinGeckoPricesEth.sol";
import "../../../testing/FloatTest.t.sol";

contract MarketTieredLeverageRealPricesTest is FloatTest {
  CoinGeckoPricesEth prices;

  uint32 constant MAX_USERS = 20;
  address[MAX_USERS] users;
  uint32 numUsers;

  uint256 constant FIXED_EPOCH_LENGTH = 3600; // must be 1 hour to match prices

  // NOTE if more than 400 then fails with EvmError: OutOfGas
  uint32 constant MAX_EPOCH_INDEX = 400; // 2610; // 3 months of 1 hour epochs

  uint32 currentEpochIndex;

  uint32 marketIndex;
  IMarket market;
  IMarketExtended marketExtended;
  address marketAddress;
  IERC20 paymentToken;
  uint32[3] numPools;
  uint32 numPoolsTotal;

  constructor() {
    prices = new CoinGeckoPricesEth();
    prices.setPrices();

    AggregatorV3Interface chainlinkOracleMock = AggregatorV3Interface(
      address(new AggregatorV3Mock(int256(prices.getPrice(currentEpochIndex)), 1, DEFAULT_ORACLE_DECIMALS))
    );

    uint256 initialPoolLiquidity = 100e18;
    MarketFactory.PoolLeverage[] memory poolLeverages = new MarketFactory.PoolLeverage[](5);
    poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
    poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
    poolLeverages[2] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.LONG, 1);
    poolLeverages[3] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
    poolLeverages[4] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 1);
    numPools[0] = 2; // short
    numPools[1] = 2; // long
    numPools[2] = 1; // float
    numPoolsTotal = numPools[1] + numPools[0] + numPools[2];

    marketIndex = marketFactory.deployMarketWithPrank(
      ADMIN,
      initialPoolLiquidity,
      poolLeverages,
      FIXED_EPOCH_LENGTH,
      DEFAULT_MINIMUM_EXECUTION_WAITING_TIME,
      address(chainlinkOracleMock),
      IERC20(address(defaultPaymentToken)),
      DEFAULT_MARKET_TYPE
    );

    market = marketFactory.market(marketIndex);
    marketExtended = marketFactory.marketExtended(marketIndex);
    marketAddress = marketFactory.marketAddress(marketIndex);
    paymentToken = IERC20(address(defaultPaymentToken));
    deal(address(paymentToken), ADMIN, 1e22);

    warpOneEpochLength();
    currentEpochIndex++;
    mockChainlinkOracleNextPrice(marketIndex, int256(prices.getPrice(currentEpochIndex)));
    updateSystemStateSingleMarket(marketIndex);

    marketFactory.setFundingRate(ADMIN, marketIndex, 10000);

    createNewUser();
    createNewUser();
    createNewUser();
    createNewUser();
  }

  // percent
  uint32 constant NEW_ACTOR_CHANCE = 10;

  function shouldCreateNewUser() internal returns (bool) {
    if (numUsers > MAX_USERS - 1) {
      return false;
    }
    return randomNumber(100) < NEW_ACTOR_CHANCE;
  }

  function createNewUser() internal {
    users[numUsers] = getFreshUser();
    dealPaymentTokenWithMarketApproval(marketIndex, users[numUsers]);
    numUsers++;
  }

  // percent
  uint32 constant MINT_CHANCE = 10;

  function shouldMint() internal returns (bool) {
    return randomNumber(100) < MINT_CHANCE;
  }

  function shouldRedeem(
    address user,
    IMarketCommon.PoolType poolType,
    uint256 poolIndex
  ) internal returns (bool) {
    if (poolTokenBalance(marketIndex, user, poolType, poolIndex) == 0) {
      return false;
    }
    return randomNumber(100) < MINT_CHANCE * numPoolsTotal;
  }

  function redeemActions(address user, IMarketCommon.PoolType poolType) internal returns (uint256 totalRedeem) {
    uint32 numPools = numPools[uint8(poolType)];

    for (uint8 poolTier = 0; poolTier < numPools; poolTier++) {
      if (shouldRedeem(user, poolType, poolTier)) {
        uint256 balance = poolTokenBalance(marketIndex, user, poolType, poolTier);
        if (poolType == IMarketCommon.PoolType.FLOAT) {
          console2.log("redeeming FLOAT balance: ", balance);
        }
        vm.startPrank(user);
        redeem(marketIndex, poolType, poolTier, uint112(balance));
        vm.stopPrank();
      }
    }
  }

  function randomUserActivity() internal returns (uint256 totalMint, uint256 totalRedeem) {
    if (shouldCreateNewUser()) {
      createNewUser();
    }

    for (uint256 userIndex = 0; userIndex < numUsers; userIndex++) {
      address user = users[userIndex];
      settleAllUserActions(market, user);

      if (shouldMint()) {
        uint256 poolType = randomNumber(2);
        uint32 numPools = numPools[poolType];
        uint256 poolTier = randomNumber(numPools);
        uint256 balance = paymentToken.balanceOf(user);
        uint112 amount = randomInRange112(1e18, uint112(Math.max(1e18 + 1, balance / 10)));
        vm.startPrank(user);
        mint(marketIndex, IMarketCommon.PoolType(uint8(poolType)), poolTier, amount);
        vm.stopPrank();
        totalMint += amount;
      }
      //totalRedeem += redeemActions(user, IMarketCommon.PoolType.LONG);
      //totalRedeem += redeemActions(user, IMarketCommon.PoolType.SHORT);
      //totalRedeem += redeemActions(user, IMarketCommon.PoolType.FLOAT);
    }
  }

  // NOTE turning this into a script yields the error:
  function testExecuteAllEpochs() public {
    uint256 totalInOut;

    for (uint8 poolType = uint8(IMarketCommon.PoolType.SHORT); poolType <= uint8(IMarketCommon.PoolType.FLOAT); poolType++) {
      uint32 numPools = numPools[poolType];
      IMarketCommon.PoolType poolTypeX = IMarketCommon.PoolType(poolType);
      for (uint256 poolTier = 0; poolTier < numPools; poolTier++) {
        totalInOut += market.get_pool_value(poolTypeX, poolTier);
      }
    }

    console2.log("Initial total value:", totalInOut);

    uint256 total;
    uint256 totalMint;
    uint256 totalRedeem;

    while (currentEpochIndex < MAX_EPOCH_INDEX - 1) {
      console2.log("currentEpochIndex", currentEpochIndex);

      total = 0;
      totalMint = 0;
      totalRedeem = 0;

      for (uint8 poolType = uint8(IMarketCommon.PoolType.SHORT); poolType <= uint8(IMarketCommon.PoolType.FLOAT); poolType++) {
        uint32 numPools = numPools[poolType];
        IMarketCommon.PoolType poolTypeX = IMarketCommon.PoolType(poolType);

        for (uint256 poolTier = 0; poolTier < numPools; poolTier++) {
          uint256 price = getPoolTokenPrice(marketIndex, poolTypeX, poolTier);
          uint256 value = market.get_pool_value(poolTypeX, poolTier);
          total += value;
          console2.log("  PoolToken: poolType poolTier price:", uint256(poolType), uint256(poolTier), price);
          console2.log("  PoolToken: poolType poolTier value:", uint256(poolType), uint256(poolTier), value);
        }
      }
      console2.log("  Total just calculated:", total);
      console2.log("  Total from adding mints and subtracting redeems:", totalInOut);

      if (totalInOut > total) {
          console2.log("  Diff (totalInOut > total):", totalInOut - total);
      } else {
          console2.log("  Diff (totalInOut < total):", total - totalInOut);
      }

      if (currentEpochIndex < MAX_EPOCH_INDEX - 10) {
        (totalMint, totalRedeem) = randomUserActivity();
      }

      totalInOut += totalMint - totalRedeem;
      warpOneEpochLength(marketIndex);
      currentEpochIndex++;
      mockChainlinkOracleNextPrice(marketIndex, int256(prices.getPrice(currentEpochIndex)));
      updateSystemStateSingleMarket(marketIndex);
    }

    console2.log("  Total just calculated:", total);
    console2.log("  Total from adding mints and subtracting redeems:", totalInOut);
  }

  function testCoinGeckoPrices() public {
    assertEq(prices.getPrice(0), 1067203435568735322112);
  }
}
