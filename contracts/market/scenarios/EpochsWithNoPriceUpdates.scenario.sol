// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../testing/FloatTest.t.sol";

contract MarketTieredLeverageSenarioOne is FloatTest {
  uint256 constant MEWT = 2;
  uint256 constant EPOCH_LENGTH = 10;
  uint80 constant ORACLE_FIRST_ROUND_ID = 2;
  address constant CHAINLINK_MOCK_ADDRESS = address(bytes20(keccak256("chainlinkMockAddress MarketTieredPool.leverageSenarioOne")));
  uint112 constant USER_MINT_AMOUNT = 1e18;

  address user1;

  uint32 marketIndex;
  IMarket market;
  PaymentTokenTestnet paymentToken;

  uint256 POOL_INDEX = 0;

  mapping(uint256 => int128) prices;
  mapping(uint256 => uint256) oracleTimes;
  mapping(uint256 => uint256) epochStartTime;

  uint256 userActionPointA;
  uint256 userActionPointB;
  uint256 userActionPointC;
  uint256 userActionPointD;
  uint256 userActionPointE;
  uint256 userActionPointF;
  uint256 userActionPointG;
  uint256 userActionPointH;
  uint256 userActionPointI;
  uint256 userActionPointJ;

  function checkMarketPoolsAtCheckpointA() public {
    // check pools
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertTrue(shortPoolToken != address(0), "Checkpoint A short token not initialized");
      assertTrue(shortPoolValue > 0, "Checkpoint A short side was not seeded");
      assertEq((shortPoolValue / 1e6), (98.5 ether / 1e6), "Checkpoint A short side does not contain the expected value");
      assertEq(shortPoolLeverage, -1e18, "Checkpoint A shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint A shortPool.batchedAmountPaymentToken_deposit[even] should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint A shortPool.batchedAmountPoolToken_redeem[even] should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint A shortPool.batchedAmountPaymentToken_deposit[odd] should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint A shortPool.batchedAmountPoolToken_redeem[odd] should be 0");
    }
    {
      address longPoolToken = market.get_pool_token(IMarketCommon.PoolType.LONG, POOL_INDEX);
      int96 longPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);
      assertTrue(longPoolToken != address(0), "Checkpoint A long token not initialized");
      assertTrue(longPoolValue > 0, "Checkpoint A long side was not seeded");
      assertEq((longPoolValue / 1e6), (101.5 ether / 1e6), "Checkpoint A long side does not contain the expected value");
      assertEq(longPoolLeverage, 1e18, "Checkpoint A longPoolLeverage should be 1x");
      assertEq(
        longPoolEvenBatchedDeposit,
        3 * USER_MINT_AMOUNT,
        "Checkpoint A longPool.batchedAmountPaymentToken_deposit[even] does not match mint amount"
      );
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint A longPool.batchedAmountPoolToken_redeem[even] should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint A longPool.batchedAmountPaymentToken_deposit[odd] should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint A longPool.batchedAmountPoolToken_redeem[odd] should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointB() public {
    // check pools
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertTrue(shortPoolToken != address(0), "Checkpoint B short token not initialized");
      assertTrue(shortPoolValue > 0, "Checkpoint B short side was not seeded");
      assertEq((shortPoolValue / 1e6), (98.5 ether / 1e6), "Checkpoint B short side does not contain the expected value");
      assertEq(shortPoolLeverage, -1e18, "Checkpoint B shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint B shortPoolEvenBatchedDeposit should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint B shortPoolEvenBatchedRedeem should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint B shortPoolOddBatchedDeposit should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint B shortPoolOddBatchedRedeem should be 0");
    }
    {
      address longPoolToken = market.get_pool_token(IMarketCommon.PoolType.LONG, POOL_INDEX);
      int96 longPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);
      assertTrue(longPoolToken != address(0), "Checkpoint B long token not initialized");
      assertTrue(longPoolValue > 0, "Checkpoint B long side was not seeded");
      assertEq((longPoolValue / 1e6), ((101.5 ether + (4 * USER_MINT_AMOUNT)) / 1e6), "Checkpoint B long side does not contain the expected value");
      assertEq(longPoolLeverage, 1e18, "Checkpoint B longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint B longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint B longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, USER_MINT_AMOUNT, "Checkpoint B longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint B longPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointC() public {
    // check pools
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertTrue(shortPoolToken != address(0), "Checkpoint C short token not initialized");
      assertTrue(shortPoolValue > 0, "Checkpoint C short side was not seeded");
      assertEq((shortPoolValue / 1e6), (98.5 ether / 1e6), "Checkpoint C short side does not contain the expected value");
      assertEq(shortPoolLeverage, -1e18, "Checkpoint C shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint C shortPoolEvenBatchedDeposit should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint C shortPoolEvenBatchedRedeem should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint C shortPoolOddBatchedDeposit should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint C shortPoolOddBatchedRedeem should be 0");
    }
    {
      address longPoolToken = market.get_pool_token(IMarketCommon.PoolType.LONG, POOL_INDEX);
      int96 longPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);
      assertTrue(longPoolToken != address(0), "Checkpoint C long token not initialized");
      assertTrue(longPoolValue > 0, "Checkpoint C long side was not seeded");
      assertEq((longPoolValue / 1e6), (105.5 ether / 1e6), "Checkpoint C long side does not contain the expected value");
      assertEq(longPoolLeverage, 1e18, "Checkpoint C longPoolLeverage should be 1x");
      // need to fix the bug in the code for this assertion to pass
      assertEq(longPoolEvenBatchedDeposit, 2 * USER_MINT_AMOUNT, "Checkpoint C longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint C longPoolEvenBatchedRedeem should be 0");
      // need to fix the bug in the code for this assertion to pass
      assertEq(longPoolOddBatchedDeposit, 2 * USER_MINT_AMOUNT, "Checkpoint C longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint C longPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointD() public {
    // check pools
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertTrue(shortPoolToken != address(0), "Checkpoint D short token not initialized");
      assertTrue(shortPoolValue > 0, "Checkpoint D short side was not seeded");
      assertEq(shortPoolLeverage, 1e18, "Checkpoint D shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint D shortPoolEvenBatchedDeposit should be 0");
      assertEq((shortPoolValue / 1e6), (98.5 ether / 1e6), "Checkpoint D short side does not contain the expected value");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint D shortPoolEvenBatchedRedeem should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint D shortPoolOddBatchedDeposit should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint D shortPoolOddBatchedRedeem should be 0");
    }
    {
      address longPoolToken = market.get_pool_token(IMarketCommon.PoolType.LONG, POOL_INDEX);
      int96 longPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);
      assertTrue(longPoolToken != address(0), "Checkpoint D long token not initialized");
      assertEq((longPoolValue / 1e6), (105.5 ether / 1e6), "Checkpoint D long side does not contain the expected value");
      assertTrue(longPoolValue > 0, "Checkpoint D long side was not seeded");
      assertEq(longPoolLeverage, 1e18, "Checkpoint D longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 2 * USER_MINT_AMOUNT, "Checkpoint D longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint D longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 2 * USER_MINT_AMOUNT, "Checkpoint D longPoolOddBatchedDeposit did not match mint amount");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint D longPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointE() public {
    {
      IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();

      assertEq(epochInfo.latestExecutedEpochIndex, 2, "Checkpoint E No epochs after epoch 2 should have been executed");
      assertEq(epochInfo.latestExecutedOracleRoundId, 5, "Checkpoint E No Oracle price updates after P5 should have been used for epoch execution");
    }
    // check pools
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);

      assertTrue(shortPoolToken != address(0), "Checkpoint E short token not initialized");
      assertTrue(shortPoolValue > 0, "Checkpoint E short side was not seeded");
      assertEq(shortPoolLeverage, 1e18, "Checkpoint E shortPoolLeverage should be 1x");
      assertEq((shortPoolValue / 1e6), (98.5 ether / 1e6), "Checkpoint E short side does not contain the expected value");

      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint E shortPoolEvenBatchedDeposit should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint E shortPoolEvenBatchedRedeem should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint E shortPoolOddBatchedDeposit should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint E shortPoolOddBatchedRedeem should be 0");
    }
    {
      address longPoolToken = market.get_pool_token(IMarketCommon.PoolType.LONG, POOL_INDEX);
      int96 longPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);

      assertTrue(longPoolToken != address(0), "Checkpoint E long token not initialized");
      assertEq((longPoolValue / 1e6), (105.5 ether / 1e6), "Checkpoint E long side does not contain the expected value");
      assertTrue(longPoolValue > 0, "Checkpoint E long side was not seeded");
      assertEq(longPoolLeverage, 1e18, "Checkpoint E longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 2 * USER_MINT_AMOUNT, "Checkpoint E longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint E longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 2 * USER_MINT_AMOUNT, "Checkpoint E longPoolOddBatchedDeposit did not match mint amount");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint E longPoolOddBatchedRedeem should be 0");
    }
  }

  /// @dev this test follows this excalidraw image exactly: https://app.excalidraw.com/l/2big5WYTyfh/47gJBUvvH8Y
  function testMarketPauseDueToEpochWithNoPriceUpdate() public {
    user1 = getFreshUser();

    //prices
    prices[0] = 1e18;
    prices[1] = 1010e15;
    prices[2] = 1000e15;
    prices[3] = 1015e15;
    prices[4] = 1915e15;
    prices[5] = 1015e15;
    prices[6] = 1015e15;
    prices[7] = 1015e15;

    //Events in timeline order
    oracleTimes[0] = 46;
    epochStartTime[0] = 50;
    oracleTimes[1] = 52;
    epochStartTime[1] = 60;
    oracleTimes[2] = 65;
    epochStartTime[2] = 70;
    userActionPointA = 71;
    userActionPointB = 73;
    oracleTimes[3] = 75;
    userActionPointC = 77;
    userActionPointD = 78;
    epochStartTime[3] = 80;
    oracleTimes[4] = 81;
    oracleTimes[5] = 83;
    userActionPointE = 88;
    userActionPointF = 89;
    epochStartTime[4] = 90;
    userActionPointG = 91;
    userActionPointH = 97;
    epochStartTime[5] = 100;
    oracleTimes[6] = 101;
    userActionPointI = 103;
    oracleTimes[7] = 105;
    userActionPointJ = 107;

    /*╔══════════════════╗
      ║  DEPLOY MARKET   ║
      ╚══════════════════╝*/
    vm.warp(69);

    uint256 initialPoolLiquidity = 100e18;
    MarketFactory.PoolLeverage[] memory poolLeverages = new MarketFactory.PoolLeverage[](3);
    poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
    poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
    poolLeverages[2] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);

    AggregatorV3Mock chainlinkOracleMock = new AggregatorV3Mock(prices[0], ORACLE_FIRST_ROUND_ID, DEFAULT_ORACLE_DECIMALS);
    marketIndex = marketFactory.deployMarketWithPrank(
      ADMIN,
      initialPoolLiquidity,
      poolLeverages,
      EPOCH_LENGTH,
      MEWT,
      address(chainlinkOracleMock),
      IERC20(address(defaultPaymentToken)),
      MarketFactory.MarketContractType.MarketTieredLeverage
    );

    market = marketFactory.market(marketIndex);
    paymentToken = PaymentTokenTestnet(IMarketTieredLeverage(address(market)).get_paymentToken());
    IOracleManager oracleManager = market.get_oracleManager();

    assertEq(oracleManager.initialEpochStartTimestamp(), 50, "Oracle Manager initialEpochStartTimestamp incorrect");

    assertEq(oracleManager.getCurrentEpochIndex(), 1, "Deployment should be in epoch 1");

    // Check constructor addresses are initialized
    assertTrue(market.get_paymentToken() != address(0), "payment token not initialized");
    assertTrue(address(IMarketExtended(address(market)).get_registry()) != address(0), "registry not initialized");
    assertTrue(IMarketExtended(address(market)).get_gems() != address(0), "gems not initialized");

    // Check Epoch Info
    IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();

    // Should this equal 0 or 1?
    assertEq(epochInfo.latestExecutedEpochIndex, 0, "Deployment latest Executed Epoch Index not correct");
    assertEq(epochInfo.latestExecutedOracleRoundId, 2, "Deployment previous execution price oracle identifier incorrect");

    vm.warp(oracleTimes[3]);
    chainlinkOracleMock.pushPrice(prices[3]);
    assertEq(chainlinkOracleMock.currentRoundId(), 3, "Oracle round id should be 3");

    vm.warp(userActionPointA);
    vm.startPrank(ALICE);

    defaultPaymentToken.mint(USER_MINT_AMOUNT);
    defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    market.mintLong(0, USER_MINT_AMOUNT);

    vm.warp(userActionPointB);

    defaultPaymentToken.mint(USER_MINT_AMOUNT);
    defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    market.mintLong(0, USER_MINT_AMOUNT);

    /*╔══════════════════╗
      ║   CHECKPOINT A   ║
      ╚══════════════════╝*/

    vm.warp(userActionPointC);

    defaultPaymentToken.mint(USER_MINT_AMOUNT);
    defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    market.mintLong(0, USER_MINT_AMOUNT);

    updateSystemStateSingleMarket(marketIndex);

    settleAllUserActions(market, ALICE);

    //assertions
    checkMarketPoolsAtCheckpointA();

    vm.warp(userActionPointD);

    defaultPaymentToken.mint(USER_MINT_AMOUNT);
    defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    market.mintLong(0, USER_MINT_AMOUNT);

    vm.warp(oracleTimes[4]);
    chainlinkOracleMock.pushPrice(prices[4]);
    assertEq(chainlinkOracleMock.currentRoundId(), 4, "Oracle round id should be 4");

    vm.warp(oracleTimes[5]);
    chainlinkOracleMock.pushPrice(prices[5]);
    assertEq(chainlinkOracleMock.currentRoundId(), 5, "Oracle round id should be 5");

    /*╔══════════════════╗
      ║   CHECKPOINT B   ║
      ╚══════════════════╝*/

    vm.warp(userActionPointE);

    defaultPaymentToken.mint(USER_MINT_AMOUNT);
    defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    market.mintLong(0, USER_MINT_AMOUNT);

    updateSystemStateSingleMarket(marketIndex);

    settleAllUserActions(market, ALICE);

    checkMarketPoolsAtCheckpointB();

    vm.warp(userActionPointF);

    defaultPaymentToken.mint(USER_MINT_AMOUNT);
    defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    market.mintLong(0, USER_MINT_AMOUNT);

    vm.warp(userActionPointG);
    defaultPaymentToken.mint(USER_MINT_AMOUNT);
    defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    market.mintLong(0, USER_MINT_AMOUNT);

    /*╔══════════════════╗
      ║   CHECKPOINT C   ║
      ╚══════════════════╝*/

    vm.warp(userActionPointH);
    defaultPaymentToken.mint(USER_MINT_AMOUNT);
    defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    market.mintLong(0, USER_MINT_AMOUNT);

    settleAllUserActions(market, ALICE);

    checkMarketPoolsAtCheckpointC();

    vm.warp(oracleTimes[6]);
    chainlinkOracleMock.pushPrice(prices[6]);
    assertEq(chainlinkOracleMock.currentRoundId(), 6, "Oracle round id should be 6");

    //// TODO: the following 'deprecation' tests don't work the same anymore - need to re-write!
    // /*╔══════════════════╗
    //   ║   CHECKPOINT D   ║
    //   ╚══════════════════╝*/

    // vm.warp(userActionPointI);
    // defaultPaymentToken.mint(USER_MINT_AMOUNT);
    // defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    // vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    // market.mintLong(0, USER_MINT_AMOUNT);

    // vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    // settleAllUserActions(market, ALICE);

    // checkMarketPoolsAtCheckpointD();

    // vm.warp(oracleTimes[7]);
    // chainlinkOracleMock.pushPrice(prices[7]);
    // assertEq(chainlinkOracleMock.currentRoundId(), 7, "Oracle round id should be 7");

    // /*╔══════════════════╗
    //   ║   CHECKPOINT E   ║
    //   ╚══════════════════╝*/

    // vm.warp(userActionPointJ);
    // defaultPaymentToken.mint(USER_MINT_AMOUNT);
    // defaultPaymentToken.approve(address(market), USER_MINT_AMOUNT);
    // vm.expectRevert(IMarketCore.MarketDeprecated.selector);
    // market.mintLong(0, USER_MINT_AMOUNT);

    // checkMarketPoolsAtCheckpointE();
  }
}
