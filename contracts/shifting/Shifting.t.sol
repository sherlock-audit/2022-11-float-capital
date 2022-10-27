pragma solidity 0.8.17;
import "../testing/FloatTest.t.sol";
import "./Shifting.sol";

// Things to test:
// The batch shifiting default size. Spam lots of orders.
// Should fail trying to add an invalid market.
// Should expect revert if a bad order is put in.
// Decode the resolver data and ensure the right orders are being executed.
// The contract has zero payment token balance after performing all shifts.
// Test shifting across different markets.
// Check its not dangerous for others to execute upkeep

/** @title Shifting testing contract */
contract ShiftingTest is FloatTest {
  Shifting shifter;

  uint32 immutable secondaryMarketIndex;
  MarketTieredLeverageInternalStateSetters immutable secondaryMarket;

  AggregatorV3Interface immutable primaryOracleMock;
  AggregatorV3Interface immutable secondaryOracleMock;

  constructor() {
    primaryOracleMock = marketFactory.chainlinkOracle(defaultMarketIndex);
    vm.startPrank(ADMIN);

    shifter = new Shifting();
    shifter.initialize(ADMIN, address(defaultPaymentToken));

    // Only 1 default market so far.
    shifter.addValidMarket(address(defaultMarket));

    vm.stopPrank();

    // Deploy a second market for cross shifiting.
    uint256 initialLiquidityToSeedEachPool = 100e18;
    MarketFactory.PoolLeverage[] memory poolLeverages = new MarketFactory.PoolLeverage[](5);
    poolLeverages[0] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.FLOAT, 0);
    poolLeverages[1] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.LONG, 0);
    poolLeverages[2] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 1);
    poolLeverages[3] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.SHORT, 0);
    poolLeverages[4] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 1);

    secondaryMarketIndex = deployMarket(
      initialLiquidityToSeedEachPool,
      poolLeverages,
      DEFAULT_FIXED_EPOCH_LENGTH,
      DEFAULT_MINIMUM_EXECUTION_WAITING_TIME,
      DEFAULT_ORACLE_FIRST_PRICE,
      DEFAULT_MARKET_TYPE
    );
    secondaryMarket = marketFactory.marketInternalStateSetters(secondaryMarketIndex);
    secondaryOracleMock = marketFactory.chainlinkOracle(secondaryMarketIndex);

    vm.startPrank(ADMIN);
    shifter.addValidMarket(address(secondaryMarket));
    vm.stopPrank();
  }

  function testHardcodedCanShiftToDifferentPoolInSameMarket() public {
    uint112 amountToMint = 100e18;
    uint8 poolTierFrom = 0;
    uint8 poolTierTo = 1;
    IMarketCommon.PoolType poolTypeFrom = IMarketCommon.PoolType.LONG;
    IMarketCommon.PoolType poolTypeTo = IMarketCommon.PoolType.SHORT;

    dealPaymentTokenWithMarketApproval(ALICE);
    dealPoolToken(defaultMarketIndex, ALICE, poolTypeFrom, poolTierFrom, amountToMint);

    PoolToken tokenFrom = getPoolToken(defaultMarketIndex, poolTypeFrom, poolTierFrom);

    PoolToken tokenTo = getPoolToken(defaultMarketIndex, poolTypeTo, poolTierTo);

    vm.startPrank(ALICE);
    tokenFrom.approve(address(shifter), type(uint256).max);
    updateSystemStateSingleMarket(defaultMarketIndex);

    shifter.shiftOrder(
      uint112(tokenFrom.balanceOf(ALICE)),
      defaultMarketAddress,
      poolTypeFrom,
      poolTierFrom,
      defaultMarketAddress,
      poolTypeTo,
      poolTierTo
    );
    vm.stopPrank();

    // Should check ALICE has no more tokenFrom Pool tokens and shifter doesn't either.
    assertEq(tokenFrom.balanceOf(ALICE), 0, "Tokens weren't taken");
    assertEq(tokenFrom.balanceOf(address(shifter)), 0, "Tokens weren't redeemed");

    // Will fail cause of assertion error :)
    // shifter.executeShiftOrder(address(defaultMarket), 1);

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    // Note that if upkeep is available and not executed, it won't shift
    (bool shouldExecuteBefore, ) = shifter.shouldExecuteShiftOrder();
    assertFalse(shouldExecuteBefore, "Upkeep shouldn't return true");

    updateSystemStateSingleMarket(defaultMarketIndex);

    (bool shouldExecuteAfter, ) = shifter.shouldExecuteShiftOrder();
    assertTrue(shouldExecuteAfter, " upkeep should be ready");

    // execute upkeep
    shifter.executeShiftOrder(defaultMarketAddress, 1);

    bool tokenBalancePositiveBefore = tokenTo.balanceOf(ALICE) > 0;
    assertFalse(tokenBalancePositiveBefore, "Already had tokens");

    shifter.shouldExecuteShiftOrder();

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);

    settleAllUserActions(defaultMarket, ALICE);

    assertTrue(tokenTo.balanceOf(ALICE) > 0, "Tokens weren't shifted");
  }

  function testCanShiftToDifferentPoolInSameMarket(
    uint112 amountToMint,
    uint256 poolTypeFromInt,
    uint8 poolTierFrom,
    uint256 poolTypeToInt,
    uint8 poolTierTo
  ) public {
    console2.log("Testing can shift from one pool to next");
    // Keep fuzz inputs within bounds.
    IMarketCommon.PoolType poolTypeFrom = IMarketCommon.PoolType(poolTypeFromInt % 2);
    IMarketCommon.PoolType _poolTypeTo = IMarketCommon.PoolType(poolTypeToInt % 2);
    poolTierFrom = (poolTierFrom % 2);
    poolTierTo = (poolTierTo % 2);
    amountToMint = (amountToMint % 1e20) + 1e20;

    // console2.log(_pool);
    dealPaymentTokenWithMarketApproval(ALICE);
    dealPoolToken(ALICE, poolTypeFrom, poolTierFrom, amountToMint);

    // uint256 initialPaymentTokenBalance =
    PoolToken tokenFrom = getPoolToken(poolTypeFrom, poolTierFrom);
    PoolToken tokenTo = getPoolToken(_poolTypeTo, poolTierTo);

    updateSystemStateSingleMarket(defaultMarketIndex);

    uint256 positionBalanceBefore = getAmountInPaymentToken(poolTypeFrom, poolTierFrom, uint112(tokenFrom.balanceOf(ALICE)));

    // uint256 AliceBalanceBefore

    vm.startPrank(ALICE);
    tokenFrom.approve(address(shifter), type(uint256).max);
    shifter.shiftOrder(
      uint112(tokenFrom.balanceOf(ALICE)),
      address(defaultMarket),
      poolTypeFrom,
      poolTierFrom,
      address(defaultMarket),
      _poolTypeTo,
      poolTierTo
    );
    vm.stopPrank();

    // Should check ALICE has no more tokenFrom Pool tokens and shifter doesn't exither.
    assertEq(tokenFrom.balanceOf(ALICE), 0, "Tokens weren't taken");
    assertEq(tokenFrom.balanceOf(address(shifter)), 0, "Tokens weren't redeemed");

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

    // check the payment token balance is zero here of the shifter.
    assertEq(defaultPaymentToken.balanceOf(address(this)), 0, "Should have shifter all of collateral recieved");
    updateSystemStateSingleMarket(defaultMarketIndex);

    // execute upkeep manually
    shifter.executeShiftOrder(address(defaultMarket), 1);

    assertFalse(tokenTo.balanceOf(ALICE) > 0, "Already had tokens");

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);
    settleAllUserActions(defaultMarket, ALICE);

    bool tokenBalancePositiveAfter = tokenTo.balanceOf(ALICE) > 0;
    assertTrue(tokenBalancePositiveAfter, "Tokens weren't shifted");
    uint256 positionBalanceAfter = getAmountInPaymentToken(_poolTypeTo, poolTierTo, uint112(tokenTo.balanceOf(ALICE)));

    // The value of position balance before and after should not be more that roughly 1.5% different accounting for
    // The fluctuations in the one epoch in which it was subjected to price movements before taken out for an epoch and shifted
    // This is very much dependant on the leverage in the market you are shifting from and the price percent movement given to the oracle
    assertApproxEqRel(positionBalanceAfter, positionBalanceBefore, 0.07e18, "Bad shift amount");

    // check the payment token balance is zero here of the shifter.
    assertEq(defaultPaymentToken.balanceOf(address(this)), 0, "Should have shifter all of collateral recieved");
  }

  address[] public users;

  function testLotsOfShiftsSameEpoch(
    uint112 amountToMint,
    uint256 poolTypeFromInt,
    uint8 poolTierFrom,
    uint256 poolTypeToInt,
    uint8 poolTierTo,
    uint32 amountOfUsers
  ) public {
    // Keep fuzz inputs within bounds.
    IMarketCommon.PoolType poolTypeFrom = IMarketCommon.PoolType(poolTypeFromInt % 2);
    IMarketCommon.PoolType _poolTypeTo = IMarketCommon.PoolType(poolTypeToInt % 2);
    poolTierFrom = (poolTierFrom % 2);
    poolTierTo = (poolTierTo % 2);
    amountToMint = (amountToMint % 1000e18) + 50e18;
    amountOfUsers = (amountOfUsers % 50) + 1;

    PoolToken tokenFrom = getPoolToken(poolTypeFrom, poolTierFrom);
    PoolToken tokenTo = getPoolToken(_poolTypeTo, poolTierTo);

    warpOutsideOfMewt();

    for (uint256 index = 0; index < amountOfUsers; index++) {
      address user = getFreshUser();
      vm.startPrank(user);
      mint(poolTypeFrom, poolTierFrom, amountToMint);
      users.push(user);
      vm.stopPrank();
    }

    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

    updateSystemStateSingleMarket(defaultMarketIndex);
    for (uint256 index = 0; index < amountOfUsers; index++) {
      address user = users[index];
      vm.startPrank(user);
      tokenFrom.approve(address(shifter), type(uint256).max);
      settleAllUserActions(defaultMarket, user);
      shifter.shiftOrder(
        uint112(tokenFrom.balanceOf(user)),
        address(defaultMarket),
        poolTypeFrom,
        poolTierFrom,
        address(defaultMarket),
        _poolTypeTo,
        poolTierTo
      );
      vm.stopPrank();
    }

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

    // execute upkeep manually
    updateSystemStateSingleMarket(defaultMarketIndex);
    shifter.executeShiftOrder(address(defaultMarket), amountOfUsers);

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

    updateSystemStateSingleMarket(defaultMarketIndex);
    for (uint256 index = 0; index < amountOfUsers; index++) {
      address user = users[index];
      settleAllUserActions(defaultMarket, user);
      uint256 positionBalanceAfter = getAmountInPaymentToken(_poolTypeTo, poolTierTo, uint112(tokenTo.balanceOf(user)));
      assertApproxEqRel(positionBalanceAfter, amountToMint, 0.07e18, "Bad shift amount");
    }

    // check the payment token balance is zero here of the shifter.
    assertEq(defaultPaymentToken.balanceOf(address(this)), 0, "Should have shifter all of collateral recieved");
  }

  function testCannotExecuteShiftOrdersThatDoNotExist(
    uint112 amountToMint,
    uint256 poolTypeFromInt,
    uint8 poolTierFrom,
    uint256 poolTypeToInt,
    uint8 poolTierTo
  ) public {
    // Keep fuzz inputs within bounds.
    IMarketCommon.PoolType poolTypeFrom = IMarketCommon.PoolType(poolTypeFromInt % 2);
    IMarketCommon.PoolType _poolTypeTo = IMarketCommon.PoolType(poolTypeToInt % 2);
    poolTierFrom = (poolTierFrom % 2);
    poolTierTo = (poolTierTo % 2);
    amountToMint = (amountToMint % 1e20) + 1e20;

    dealPaymentTokenWithMarketApproval(ALICE);
    dealPoolToken(ALICE, poolTypeFrom, poolTierFrom, amountToMint);

    // uint256 initialPaymentTokenBalance =
    PoolToken tokenFrom = getPoolToken(poolTypeFrom, poolTierFrom);

    vm.startPrank(ALICE);
    tokenFrom.approve(address(shifter), type(uint256).max);
    updateSystemStateSingleMarket(defaultMarketIndex);

    shifter.shiftOrder(
      uint112(tokenFrom.balanceOf(ALICE)),
      address(defaultMarket),
      poolTypeFrom,
      poolTierFrom,
      address(defaultMarket),
      _poolTypeTo,
      poolTierTo
    );
    vm.stopPrank();

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(ONE_PERCENT);

    updateSystemStateSingleMarket(defaultMarketIndex);

    vm.expectRevert();
    shifter.executeShiftOrder(address(defaultMarket), 20);

    // execute upkeep manually
    shifter.executeShiftOrder(address(defaultMarket), 1);

    vm.expectRevert("Cannot execute past");
    shifter.executeShiftOrder(address(defaultMarket), 0);

    vm.expectRevert();
    shifter.executeShiftOrder(address(defaultMarket), 2);
  }

  function testCannotShiftInvalidOrders(
    uint112 amountToMint,
    uint256 poolTypeFromInt,
    uint8 poolTierFrom,
    uint256 poolTypeToInt,
    uint8 poolTierTo
  ) public {
    IMarketCommon.PoolType poolTypeFrom = IMarketCommon.PoolType(poolTypeFromInt % 2);
    IMarketCommon.PoolType _poolTypeTo = IMarketCommon.PoolType(poolTypeToInt % 2);
    poolTierFrom = (poolTierFrom % 2);
    poolTierTo = (poolTierTo % 2);
    amountToMint = (amountToMint % 1e20) + 1e20;

    // uint256 initialPaymentTokenBalance =
    // PoolToken tokenFrom = getPoolToken(poolTypeFrom, poolTierFrom);
    // PoolToken tokenTo = getPoolToken(_poolTypeTo, poolTierTo);

    vm.startPrank(ALICE);

    vm.expectRevert("invalid from market");
    shifter.shiftOrder(
      uint112(amountToMint),
      address(defaultPaymentToken),
      poolTypeFrom,
      poolTierFrom,
      address(defaultMarket),
      _poolTypeTo,
      poolTierTo
    );

    vm.expectRevert("invalid to market");
    shifter.shiftOrder(
      uint112(amountToMint),
      address(defaultMarket),
      poolTypeFrom,
      poolTierFrom,
      address(defaultPaymentToken),
      _poolTypeTo,
      poolTierTo
    );

    vm.expectRevert("Bad pool type from");
    shifter.shiftOrder(
      uint112(amountToMint),
      address(defaultMarket),
      IMarketCommon.PoolType.LAST,
      poolTierFrom,
      address(defaultMarket),
      _poolTypeTo,
      poolTierTo
    );

    vm.expectRevert("Bad pool type to");
    shifter.shiftOrder(
      uint112(amountToMint),
      address(defaultMarket),
      poolTypeFrom,
      poolTierFrom,
      address(defaultMarket),
      IMarketCommon.PoolType.LAST,
      poolTierTo
    );

    vm.expectRevert("to pool does not exist");
    shifter.shiftOrder(
      uint112(amountToMint),
      address(defaultMarket),
      poolTypeFrom,
      poolTierFrom,
      address(defaultMarket),
      _poolTypeTo,
      poolTierTo + 5
    );
    // Note if the pool type put in is above 8 we get a different error where it can't access the array.

    vm.stopPrank();

    // dealPaymentTokenWithMarketApproval(ALICE);
    // dealPoolToken(ALICE, poolTypeFrom, poolTierFrom, amountToMint);

    // vm.expectRevert();
    // shifter.executeShiftOrder(address(defaultMarket), 20);

    // // execute upkeep manually
    // shifter.executeShiftOrder(address(defaultMarket), 1);

    // vm.expectRevert("Cannot execute past");
    // shifter.executeShiftOrder(address(defaultMarket), 0);

    // vm.expectRevert();
    // shifter.executeShiftOrder(address(defaultMarket), 2);
  }

  function testShiftDifferentMarket(
    uint112 amountToMint,
    uint256 poolTypeFromInt,
    uint8 poolTierFrom,
    uint256 poolTypeToInt,
    uint8 poolTierTo
  ) public {
    console2.log("Testing can shift from one pool to next not hard coded");

    // Keep fuzz inputs within bounds.
    IMarketCommon.PoolType poolTypeFrom = IMarketCommon.PoolType(poolTypeFromInt % 2);
    IMarketCommon.PoolType _poolTypeTo = IMarketCommon.PoolType(poolTypeToInt % 2);
    poolTierFrom = (poolTierFrom % 2);
    poolTierTo = (poolTierTo % 2);
    amountToMint = (amountToMint % 1e20) + 1e20;

    dealPaymentTokenWithMarketApproval(ALICE);
    // dealPoolToken(ALICE, poolTypeFrom, poolTierFrom, amountToMint);
    // This is ugly but can't deal paymentToken,
    // since we need to push prices to the seconday oracle market for the second
    // market so it doesn't brick because it has no price updates
    vm.startPrank(ALICE);
    warpOutsideOfMewt();
    mint(poolTypeFrom, poolTierFrom, amountToMint);
    mockChainlinkOraclePercentPriceMovement(primaryOracleMock, ONE_PERCENT);
    mockChainlinkOraclePercentPriceMovement(secondaryOracleMock, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(primaryOracleMock, ONE_PERCENT);
    mockChainlinkOraclePercentPriceMovement(secondaryOracleMock, ONE_PERCENT);
    updateSystemStateSingleMarket(defaultMarketIndex);
    settleAllUserActions(defaultMarket, ALICE);
    vm.stopPrank();

    PoolToken tokenFrom = getPoolToken(poolTypeFrom, poolTierFrom);
    PoolToken tokenTo = PoolToken(MarketExtended(address(secondaryMarket)).getPoolTokenAddress(_poolTypeTo, poolTierTo));

    uint256 positionBalanceBefore = getAmountInPaymentToken(poolTypeFrom, poolTierFrom, uint112(tokenFrom.balanceOf(ALICE)));

    // uint256 AliceBalanceBefore

    vm.startPrank(ALICE);
    tokenFrom.approve(address(shifter), type(uint256).max);
    shifter.shiftOrder(
      uint112(tokenFrom.balanceOf(ALICE)),
      address(defaultMarket),
      poolTypeFrom,
      poolTierFrom,
      address(secondaryMarket), // shift to other market.
      _poolTypeTo,
      poolTierTo
    );
    vm.stopPrank();

    // Should check ALICE has no more tokenFrom Pool tokens and shifter doesn't exither.
    assertEq(tokenFrom.balanceOf(ALICE), 0, "Tokens weren't taken");
    assertEq(tokenFrom.balanceOf(address(shifter)), 0, "Tokens weren't redeemed");

    warpOutsideOfMewt();
    mockChainlinkOraclePercentPriceMovement(primaryOracleMock, ONE_PERCENT);
    mockChainlinkOraclePercentPriceMovement(secondaryOracleMock, ONE_PERCENT);
    warpOneEpochLength();
    mockChainlinkOraclePercentPriceMovement(primaryOracleMock, ONE_PERCENT);
    mockChainlinkOraclePercentPriceMovement(secondaryOracleMock, ONE_PERCENT);

    // check the payment token balance is zero here of the shifter.
    assertEq(defaultPaymentToken.balanceOf(address(this)), 0, "Should have shifter all of collateral recieved");

    updateSystemStateSingleMarket(defaultMarketIndex);
    updateSystemStateSingleMarket(secondaryMarketIndex);

    // execute upkeep manually
    shifter.executeShiftOrder(address(defaultMarket), 1);

    assertFalse(tokenTo.balanceOf(ALICE) > 0, "Already had tokens");

    // simualting movements in secondary market.
    warpOutsideOfMewt(secondaryMarketIndex);
    mockChainlinkOraclePercentPriceMovement(secondaryOracleMock, ONE_PERCENT);
    warpOneEpochLength(secondaryMarketIndex);
    mockChainlinkOraclePercentPriceMovement(secondaryOracleMock, ONE_PERCENT);

    updateSystemStateSingleMarket(secondaryMarketIndex);

    settleAllUserActions(IMarket(address(secondaryMarket)), ALICE);

    bool tokenBalancePositiveAfter = tokenTo.balanceOf(ALICE) > 0;
    assertTrue(tokenBalancePositiveAfter, "Tokens weren't shifted");
    uint256 positionBalanceAfter = getAmountInPaymentToken(secondaryMarketIndex, _poolTypeTo, poolTierTo, uint112(tokenTo.balanceOf(ALICE)));

    // The value of position balance before and after should not be more than roughly 1.5% different accounting for
    // The fluctuations in the one epoch in which it was subjected to price movements before taken out for an epoch and shifted
    // This is very much dependant on the leverage in the market you are shifting from and the price percent movement given to the oracle
    assertApproxEqRel(positionBalanceAfter, positionBalanceBefore, 0.07e18, "Bad shift amount");

    // check the payment token balance is zero here of the shifter.
    assertEq(defaultPaymentToken.balanceOf(address(this)), 0, "Should have shifter all of collateral recieved");
  }
}
