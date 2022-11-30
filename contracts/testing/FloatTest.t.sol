// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../testing/FloatContractsCoordinator.s.sol";
import "../interfaces/IMarket.sol";

contract FloatTest is FloatContractsCoordinator {
  uint32 immutable defaultMarketIndex;
  IMarket immutable defaultMarket;
  address immutable defaultMarketAddress;
  IOracleManager immutable defaultOracleManager;
  MarketLiquidityManagerSimple immutable defaultYieldManager;
  PaymentTokenTestnet immutable defaultPaymentToken;

  constructor() {
    setupContractCoordinator();

    vm.warp(DEFAULT_START_TIMESTAMP);
    vm.startPrank(ADMIN);

    gems = constructGems();
    registry = constructRegistry(address(gems), ADMIN);

    marketFactory = new MarketFactory(registry);

    vm.stopPrank();

    uint256 initialPoolLiquidity = 100e18;
    MarketFactory.PoolLeverage[] memory poolLeverages = new MarketFactory.PoolLeverage[](5);
    poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
    poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
    poolLeverages[2] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 1);
    poolLeverages[3] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
    poolLeverages[4] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 1);

    defaultPaymentToken = constructOrUpdatePaymentTokenTestnet("defaultTestPaymentToken", 0, ADMIN);
    deal(address(defaultPaymentToken), ADMIN, 1e22);
    deal(address(defaultPaymentToken), ALICE, 1e22);
    deal(address(defaultPaymentToken), BOB, 1e22);

    defaultMarketIndex = deployMarket(
      initialPoolLiquidity,
      poolLeverages,
      DEFAULT_FIXED_EPOCH_LENGTH,
      DEFAULT_MINIMUM_EXECUTION_WAITING_TIME,
      DEFAULT_ORACLE_FIRST_PRICE,
      DEFAULT_MARKET_TYPE
    );

    defaultMarket = marketFactory.market(defaultMarketIndex);
    defaultMarketAddress = marketFactory.marketAddress(defaultMarketIndex);
    defaultOracleManager = marketFactory.oracleManager(defaultMarketIndex);
    defaultYieldManager = marketFactory.liquidityManager(defaultMarketIndex);

    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);
  }

  function deployMarket(
    uint256 initialLiquidityToSeedEachPool,
    MarketFactory.PoolLeverage[] memory poolLeverages,
    uint256 fixedEpochLength,
    uint256 minimumExecutionWaitingTime,
    int256 oracleFirstPrice,
    MarketFactory.MarketContractType marketType
  ) public returns (uint32 marketIndex) {
    AggregatorV3Mock chainlinkOracleMock = new AggregatorV3Mock(oracleFirstPrice, DEFAULT_ORACLE_FIRST_ROUND_ID, DEFAULT_ORACLE_DECIMALS);
    marketIndex = marketFactory.deployMarketWithPrank(
      ADMIN,
      initialLiquidityToSeedEachPool,
      poolLeverages,
      fixedEpochLength,
      minimumExecutionWaitingTime,
      address(chainlinkOracleMock),
      IERC20(address(defaultPaymentToken)),
      marketType
    );
  }

  function dealPaymentTokenWithMarketApproval(address user) public {
    dealPaymentTokenWithMarketApproval(defaultMarketIndex, user);
  }

  function dealPaymentTokenWithMarketApproval(uint32 marketIndex, address user) public {
    PaymentTokenTestnet paymentToken = PaymentTokenTestnet(address(marketFactory.paymentToken(marketIndex)));
    vm.startPrank(user);
    paymentToken.mint(1e22);
    paymentToken.approve(marketFactory.marketAddress(marketIndex), ~uint256(0));
    vm.stopPrank();
  }

  function dealPaymentTokenWithMarketApproval(address user, uint256 amount) public {
    vm.startPrank(user);
    defaultPaymentToken.mint(amount);
    defaultPaymentToken.approve(address(defaultMarket), amount * 10);
    vm.stopPrank();
  }

  function dealPoolToken(
    address user,
    IMarketCommon.PoolType poolType,
    uint32 poolIndex,
    uint112 amountInPaymentToken
  ) public {
    dealPoolToken(defaultMarketIndex, user, poolType, poolIndex, amountInPaymentToken);
  }

  function dealPoolToken(
    uint32 marketIndex,
    address user,
    IMarketCommon.PoolType poolType,
    uint32 poolIndex,
    uint112 amountInPaymentToken
  ) public {
    IERC20 paymentToken = marketFactory.paymentToken(marketIndex);
    IMarket market = marketFactory.market(marketIndex);

    vm.assume(amountInPaymentToken > 0 && amountInPaymentToken <= paymentToken.balanceOf(user));

    vm.startPrank(user);
    warpOutsideOfMewt(marketIndex);
    mint(marketIndex, poolType, poolIndex, amountInPaymentToken);
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    warpOneEpochLength(marketIndex);
    mockChainlinkOraclePercentPriceMovement(marketIndex, ONE_PERCENT);
    updateSystemStateSingleMarket(marketIndex);
    settleAllUserActions(market, user);
    vm.stopPrank();
  }

  uint256 freshUserOffset;

  function getFreshUser() public returns (address freshUser) {
    freshUserOffset += 1;
    freshUser = address(bytes20(bytes32(uint256(keccak256(abi.encodePacked("freshUser", freshUserOffset))))));
    dealPaymentTokenWithMarketApproval(freshUser);
  }

  function mockChainlinkOracleNextPrice(int256 price) public {
    mockChainlinkOracleNextPrice(defaultMarketIndex, price);
  }

  function mockChainlinkOracleNextPrice(uint32 marketIndex, int256 price) public {
    mockChainlinkOracleNextPrice(marketFactory.chainlinkOracle(marketIndex), price);
  }

  function mockChainlinkOraclePercentPriceMovement(
    int256 percent // e.g. 1e18 is 100%
  ) public {
    mockChainlinkOraclePercentPriceMovement(defaultMarketIndex, percent);
  }

  function mockChainlinkOraclePercentPriceMovement(
    uint32 marketIndex,
    int256 percent // e.g. 1e18 is 100%
  ) public {
    mockChainlinkOraclePercentPriceMovement(marketFactory.chainlinkOracle(marketIndex), percent);
  }

  function getPoolLeverage(IMarketCommon.PoolType poolType, uint8 poolIndex) public view returns (int256) {
    return int256(defaultMarket.get_pool_leverage(poolType, poolIndex));
  }

  function addPoolToExistingMarket(
    IMarketExtended.SinglePoolInitInfo memory initPool,
    uint256 initialEffectiveLiquidityForNewPool,
    address seederAndAdmin,
    uint32 _marketIndex
  ) public {
    MarketExtended(address(defaultMarket)).addPoolToExistingMarket(initPool, initialEffectiveLiquidityForNewPool, seederAndAdmin, _marketIndex);
  }

  function getPreviousEpochEndTimestamp() public view returns (uint32) {
    IOracleManager oracleManager = IOracleManager(defaultMarket.get_oracleManager());
    IMarket.EpochInfo memory epochInfo = defaultMarket.get_epochInfo();

    uint32 previousEpochEndTimestamp = uint32(
      (uint256(epochInfo.latestExecutedEpochIndex + 1) * oracleManager.EPOCH_LENGTH()) + oracleManager.initialEpochStartTimestamp()
    );
    return previousEpochEndTimestamp;
  }

  function getPreviousExecutedEpochIndex() public view returns (uint32) {
    return defaultMarket.get_epochInfo().latestExecutedEpochIndex;
  }

  function getLastEpochPrice() public view returns (int256) {
    return int256(uint256(marketFactory.market(defaultMarketIndex).get_epochInfo().lastEpochPrice));
  }

  function timeLeftInEpoch() public view returns (uint256 _timeLeftInEpoch) {
    uint256 epochStartTimestamp = defaultOracleManager.getEpochStartTimestamp();
    _timeLeftInEpoch = epochStartTimestamp + defaultOracleManager.EPOCH_LENGTH() - block.timestamp;
  }

  function warpToJustBeforeEndOfMewtInNextEpoch() public {
    vm.warp(block.timestamp + timeLeftInEpoch() + defaultOracleManager.MINIMUM_EXECUTION_WAIT_THRESHOLD() - 1);
  }

  function warpToEndOfMewtInNextEpoch() public {
    warpToEndOfMewtInNextEpoch(defaultMarketIndex);
  }

  function warpToEndOfMewtInNextEpoch(uint32 marketIndex) public {
    vm.warp(block.timestamp + timeLeftInEpoch() + marketFactory.oracleManager(marketIndex).MINIMUM_EXECUTION_WAIT_THRESHOLD());
  }

  function warpOneEpochLength() public {
    warpOneEpochLength(defaultMarketIndex);
  }

  function warpOneEpochLength(uint32 marketIndex) public {
    vm.warp(block.timestamp + marketFactory.oracleManager(marketIndex).EPOCH_LENGTH());
  }

  function warpToJustBeforeNextEpoch() public {
    vm.warp(defaultOracleManager.getEpochStartTimestamp() + defaultOracleManager.EPOCH_LENGTH() - 1);
  }

  function warpOutsideOfMewt() public {
    warpOutsideOfMewt(defaultMarketIndex);
  }

  /// @dev Checks whether current timestamp is inside MEWT (excluding the boundary)
  /// @return inMewt boolean to indicate whether still in MEWT or not
  function inMewt(IOracleManager oracleManager) public view returns (bool) {
    return block.timestamp < oracleManager.getEpochStartTimestamp() + oracleManager.MINIMUM_EXECUTION_WAIT_THRESHOLD();
  }

  function warpOutsideOfMewt(uint32 marketIndex) public {
    IOracleManager oracleManager = marketFactory.oracleManager(marketIndex);
    if (inMewt(oracleManager)) {
      vm.warp(oracleManager.getEpochStartTimestamp() + oracleManager.MINIMUM_EXECUTION_WAIT_THRESHOLD() + 1);
    }
  }

  function warpForwardOneSecond() public {
    vm.warp(block.timestamp + 1);
  }

  function getPoolTokenPrice(IMarketCommon.PoolType poolType, uint256 poolIndex) public view returns (uint256) {
    return getPoolTokenPrice(defaultMarketIndex, poolType, poolIndex);
  }

  function getPoolTokenPrice(
    uint32 marketIndex,
    IMarketCommon.PoolType poolType,
    uint256 poolIndex
  ) public view returns (uint256) {
    IMarket market = marketFactory.market(marketIndex);
    uint32 currentExecutedEpoch = market.get_epochInfo().latestExecutedEpochIndex;

    require(currentExecutedEpoch > 0, "Market does not yet have a pool token price.");

    uint256 price = market.get_poolToken_priceSnapshot(currentExecutedEpoch, poolType, poolIndex);

    return price;
  }

  function getAmountInPaymentToken(
    IMarketCommon.PoolType poolType,
    uint256 poolIndex,
    uint112 amountPoolToken
  ) public view returns (uint112) {
    return getAmountInPaymentToken(defaultMarketIndex, poolType, poolIndex, amountPoolToken);
  }

  function getAmountInPaymentToken(
    uint32 marketIndex,
    IMarketCommon.PoolType poolType,
    uint256 poolIndex,
    uint112 amountPoolToken
  ) public view returns (uint112) {
    uint256 poolTokenPriceInPaymentTokens = getPoolTokenPrice(marketIndex, poolType, poolIndex);
    return uint112((uint256(amountPoolToken) * poolTokenPriceInPaymentTokens) / 1e18);
  }

  function getAmountInPoolToken(
    IMarketCommon.PoolType poolType,
    uint256 poolIndex,
    uint112 amountPaymentToken
  ) public view returns (uint112) {
    uint256 poolTokenPriceInPaymentTokens = getPoolTokenPrice(poolType, poolIndex);
    return uint112((uint256(amountPaymentToken) * 1e18) / poolTokenPriceInPaymentTokens);
  }

  function getPoolToken(IMarketCommon.PoolType poolType, uint256 poolIndex) public view returns (PoolToken) {
    return getPoolToken(defaultMarketIndex, poolType, poolIndex);
  }

  function getPoolToken(
    uint32 marketIndex,
    IMarketCommon.PoolType poolType,
    uint256 poolIndex
  ) public view returns (PoolToken) {
    return PoolToken(marketFactory.marketExtended(marketIndex).getPoolTokenAddress(poolType, poolIndex));
  }

  uint256 constant secondsInAYear = 365.25 days;
  int256 maxPercentChange;
  uint256 secondsInEpoch;
  uint256 fundingRateMultiplier;
  uint256 minFloatPoolFundingBoost;
  int256 priceMovement;
  int256 perfectFloatPoolLeverage;
  uint256 totalUserEffectiveValue;

  function calculateFundingAmount(
    uint8 overbalancedIndex,
    uint256 overbalancedValue,
    uint256 underbalancedValue,
    IMarket market,
    int256 floatLeverage
  ) public virtual returns (int256[2] memory fundingAmount) {
    totalUserEffectiveValue = overbalancedValue + underbalancedValue;
    secondsInEpoch = market.get_oracleManager().EPOCH_LENGTH();
    fundingRateMultiplier = market.get_fundingRateMultiplier();
    minFloatPoolFundingBoost = market.get_minFloatPoolFundingBoost();
    if (floatLeverage < 0) floatLeverage = -floatLeverage;

    uint256 totalFunding = (totalUserEffectiveValue *
      fundingRateMultiplier *
      Math.max(minFloatPoolFundingBoost, uint256(floatLeverage)) *
      secondsInEpoch) / (secondsInAYear * 1e22);

    uint256 overbalancedFunding = Math.min(totalFunding, (totalFunding * (2 * overbalancedValue - underbalancedValue)) / (totalUserEffectiveValue));
    uint256 underbalancedFunding = totalFunding - overbalancedFunding;

    if (overbalancedIndex == uint8(IMarketCommon.PoolType.SHORT)) fundingAmount = [-int256(overbalancedFunding), int256(underbalancedFunding)];
    else fundingAmount = [-int256(underbalancedFunding), int256(overbalancedFunding)];
  }

  function newCalculateFundingAmount(
    uint256 overbalancedIndex,
    uint256 overbalancedValue,
    uint256 underbalancedValue,
    IMarket market
  ) public view virtual returns (int256[2] memory fundingAmount) {
    // TODO: add reference implementation
    /*
    baseFunding exists based on the size of capital and happens regardless of balance.
    additionalFunding scales as the imbalance of liquidity does. 
    The split of the total funding is borne predominently by the overbalanced side. 
    */
    // secondsInEpoch = market.get_oracleManager().EPOCH_LENGTH();
    // fundingRateMultiplier = market.get_fundingRateMultiplier();
    // uint256 baseFunding = ((overbalancedValue + underbalancedValue) * fundingRateMultiplier * secondsInEpoch) / 365.25 days;
    // uint256 additionalFunding = ((overbalancedValue - underbalancedValue) * fundingRateMultiplier * secondsInEpoch) / 365.25 days;
    // uint256 totalFunding = (baseFunding + additionalFunding);
    // uint256 overbalancedFunding = (totalFunding * overbalancedValue) / (overbalancedValue + underbalancedValue);
    // uint256 underbalancedFunding = totalFunding - overbalancedFunding;
    // if (overbalancedIndex == SHORT_TYPE) fundingAmount = [-int256(overbalancedFunding), int256(underbalancedFunding)];
    // else fundingAmount = [-int256(underbalancedFunding), int256(overbalancedFunding)];
  }

  function getEffectiveValueChangeReferenceImplementation(
    uint256 effectiveValueLong,
    uint256 effectiveValueShort,
    uint256 floatPoolLiquidity,
    int256 previousPrice,
    int256 currentPrice,
    IMarket market
  )
    public
    virtual
    returns (
      int256 valueChange,
      int256 fundingAmount,
      int256 floatPoolLeverage,
      uint8 underBalancedPoolType
    )
  {
    maxPercentChange = market.get_maxPercentChange();
    secondsInEpoch = market.get_oracleManager().EPOCH_LENGTH();
    fundingRateMultiplier = market.get_fundingRateMultiplier();
    priceMovement = (1e18 * (currentPrice - previousPrice)) / previousPrice;

    int256 finalPercentageMovement;

    perfectFloatPoolLeverage = ((int256(effectiveValueShort) - int256(effectiveValueLong)) * 1e18) / int256(floatPoolLiquidity);

    if (perfectFloatPoolLeverage > 0) {
      floatPoolLeverage = int256(Math.min(uint256(perfectFloatPoolLeverage), 5e18));
    } else {
      floatPoolLeverage = -int256(Math.min(uint256(-perfectFloatPoolLeverage), 5e18));
    }

    if (priceMovement > 0) {
      finalPercentageMovement = int256(Math.min(uint256(priceMovement), uint256(maxPercentChange)));
    } else {
      finalPercentageMovement = -int256(Math.min(uint256(-priceMovement), uint256(maxPercentChange)));
    }

    // valueChange = (finalPercentageMovement * int256(Math.min(effectiveValueShort, effectiveValueLong))) / 1e18;

    //  slow drip interest funding payment here.
    uint256 totalEffectiveLiquidityOnUnderbalancedSide;

    if (effectiveValueLong < effectiveValueShort) {
      totalEffectiveLiquidityOnUnderbalancedSide = effectiveValueLong + ((uint256(floatPoolLeverage) * floatPoolLiquidity) / 1e18);
      // TODO: this funding rate calc is outdated
      fundingAmount = int256(((effectiveValueShort - effectiveValueLong) * fundingRateMultiplier * secondsInEpoch) / secondsInAYear);
      underBalancedPoolType = uint8(IMarketCommon.PoolType.LONG);
    } else {
      totalEffectiveLiquidityOnUnderbalancedSide = effectiveValueShort + ((uint256(-floatPoolLeverage) * floatPoolLiquidity) / 1e18);
      fundingAmount = int256(((effectiveValueLong - effectiveValueShort) * fundingRateMultiplier * secondsInEpoch) / secondsInAYear);
      underBalancedPoolType = uint8(IMarketCommon.PoolType.SHORT);
    }

    valueChange = (finalPercentageMovement * int256(totalEffectiveLiquidityOnUnderbalancedSide)) / 1e18;
  }

  // TODO: this function doesn't include the funding amount
  function valueChangeForPool(
    IMarketCommon.PoolType poolType,
    uint8 poolIndex,
    uint256[2] memory previousTotalEffectiveLiquidity,
    uint256 floatPoolLiquidity,
    int256 previousOraclePrice,
    uint256 previousPoolPaymentTokenBalance
  ) internal returns (int256 _valueChangeForPool) {
    // TODO: we need to use the `fundingAmount` variable in the tests.
    (
      int256 valueChange,
      int256 fundingAmount,
      int256 floatPoolLeverage,
      uint8 underBalancedPoolType
    ) = getEffectiveValueChangeReferenceImplementation(
        previousTotalEffectiveLiquidity[uint256(IMarketCommon.PoolType.LONG)],
        previousTotalEffectiveLiquidity[uint256(IMarketCommon.PoolType.SHORT)],
        floatPoolLiquidity,
        previousOraclePrice,
        getLastEpochPrice(),
        defaultMarket
      );
    uint256 effectiveLiquidityOnSide;
    if (poolType == IMarketCommon.PoolType.FLOAT || underBalancedPoolType == uint8(poolType)) {
      effectiveLiquidityOnSide =
        previousTotalEffectiveLiquidity[underBalancedPoolType] +
        ((SignedMath.abs(floatPoolLeverage) * uint256(floatPoolLiquidity)) / 1e18);
    } else {
      effectiveLiquidityOnSide = previousTotalEffectiveLiquidity[uint8(poolType)];
    }

    int256 poolLeverage = (poolType == IMarketCommon.PoolType.FLOAT ? floatPoolLeverage : getPoolLeverage(poolType, poolIndex));

    _valueChangeForPool = ((((int256(previousPoolPaymentTokenBalance) * poolLeverage) / 1e18) * valueChange) / int256(effectiveLiquidityOnSide));
  }

  function mint(
    IMarketCommon.PoolType poolType,
    uint256 poolIndex,
    uint112 amount
  ) internal {
    mint(defaultMarketIndex, poolType, poolIndex, amount);
  }

  function redeem(
    IMarketCommon.PoolType poolType,
    uint256 poolIndex,
    uint112 amount
  ) internal {
    redeem(defaultMarketIndex, poolType, poolIndex, amount);
  }

  function poolTokenBalance(
    address user,
    IMarketCommon.PoolType poolType,
    uint256 poolIndex
  ) public view returns (uint256) {
    return poolTokenBalance(defaultMarketIndex, user, poolType, poolIndex);
  }

  function poolTokenBalance(
    uint32 marketIndex,
    address user,
    IMarketCommon.PoolType poolType,
    uint256 poolIndex
  ) public view returns (uint256) {
    return getPoolToken(marketIndex, poolType, poolIndex).balanceOf(user);
  }
}
