// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console2.sol";
import "../../testing/FloatTest.t.sol";

contract MarketTieredLeverageSenarioOne is FloatTest {
  uint256 constant MEWT = 2;
  uint256 constant EPOCH_LENGTH = 10;
  uint80 constant ORACLE_FIRST_ROUND_ID = 2;
  address constant CHAINLINK_MOCK_ADDRESS = address(bytes20(keccak256("chainlinkMockAddress MarketTieredPool.leverageSenarioOne")));

  address user1;
  address user2;
  address user3;

  uint32 marketIndex;
  IMarket market;
  PaymentTokenTestnet paymentToken;
  MarketLiquidityManagerSimple liquidityManager;

  uint256 POOL_INDEX = 0;

  mapping(uint256 => int128) prices;
  mapping(uint256 => uint256) oracleTimes;
  mapping(uint256 => uint256) epochStartTime;

  uint256 checkPointA;
  uint256 checkPointB;
  uint256 checkPointC;
  uint256 checkPointD;
  uint256 checkPointE;
  uint256 checkPointF;
  uint256 checkPointG;
  uint256 checkPointH;

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
      assertEq(shortPoolLeverage, -1e18, "Checkpoint A shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint A shortPoolEvenBatchedDeposit should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint A shortPoolEvenBatchedRedeem should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint A shortPoolOddBatchedDeposit should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint A shortPoolOddBatchedRedeem should be 0");
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
      assertEq(longPoolLeverage, 1e18, "Checkpoint A longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint A longPoolEvenBatchedDeposit should be 0");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint A longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint A longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint A longPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointC(uint256 checkpointBMintAmount) public {
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
      assertEq((longPoolValue / 1e6), (101.5 ether / 1e6), "Checkpoint C long side does not contain the expected value");
      assertEq(longPoolLeverage, 1e18, "Checkpoint C longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, checkpointBMintAmount, "Checkpoint C longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint C longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint C longPoolOddBatchedDeposit should be 0");
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
      assertEq(shortPoolLeverage, -1e18, "Checkpoint D shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint D shortPoolEvenBatchedDeposit should be 0");
      assertEq((shortPoolValue / 1e6), (99.470443349753 ether / 1e6), "Checkpoint D short side does not contain the expected value");
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
      assertEq((longPoolValue / 1e6), (108.5 ether / 1e6), "Checkpoint D long side does not contain the expected value");
      assertTrue(longPoolValue > 0, "Checkpoint D long side was not seeded");
      assertEq(longPoolLeverage, 1e18, "Checkpoint D longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint D longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint D longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint D longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint D longPoolOddBatchedRedeem should be 0");
    }
    {
      // int96 floatPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      address floatPoolToken = market.get_pool_token(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolValue = market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      assertTrue(floatPoolToken != address(0), "Checkpoint D float token not initialized");
      assertEq((floatPoolValue / 1e6), (100.029556650246 ether / 1e6), "Checkpoint D float side does not contain the expected value");
      assertTrue(floatPoolValue > 0, "Checkpoint D float side was not seeded");
      // assertEq(floatPoolLeverage, 1e18, "Checkpoint D floatPoolLeverage should be 1x");
      assertEq(floatPoolEvenBatchedDeposit, 0, "Checkpoint D floatPoolEvenBatchedDeposit does not match mint amount");
      assertEq(floatPoolEvenBatchedRedeem, 0, "Checkpoint D floatPoolEvenBatchedRedeem should be 0");
      assertEq(floatPoolOddBatchedDeposit, 0, "Checkpoint D floatPoolOddBatchedDeposit should be 0");
      assertEq(floatPoolOddBatchedRedeem, 0, "Checkpoint D floatPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointE() public {
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
      assertEq(shortPoolLeverage, -1e18, "Checkpoint E shortPoolLeverage should be 1x");
      assertEq(shortPoolOddBatchedDeposit, 13e18, "Checkpoint E shortPoolOddBatchedDeposit should be 13");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint E shortPoolOddBatchedRedeem should be 0");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint E shortPool.Epoch_batchedAmountPaymentToken_deposit should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint E shortPoolEvenBatchedRedeem should be 0");
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
      assertTrue(longPoolValue > 0, "Checkpoint E long side was not seeded");
      assertEq(longPoolLeverage, 1e18, "Checkpoint E longPoolLeverage should be 1x");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint E longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolOddBatchedRedeem, 6e18, "Checkpoint E longPoolOddBatchedRedeem should be 6");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint E longPoolEvenBatchedDeposit should be 0");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint E longPool.evemEpoch_batchedAmountPoolToken_redeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointG() public {
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertTrue(shortPoolToken != address(0), "Checkpoint G short token not initialized");
      assertEq((shortPoolValue / 1e6), (113.460199004975 ether / 1e6), "Checkpoint G short side does not contain the expected value");
      assertEq(shortPoolLeverage, -1e18, "Checkpoint G shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint G shortPoolEvenBatchedDeposit should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint G shortPoolEvenBatchedRedeem should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint G shortPoolOddBatchedDeposit should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint G shortPoolOddBatchedRedeem should be 0");
    }
    {
      address longPoolToken = market.get_pool_token(IMarketCommon.PoolType.LONG, POOL_INDEX);
      int96 longPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);
      assertTrue(longPoolToken != address(0), "Checkpoint G long token not initialized");
      assertEq((longPoolValue / 1e6), (101.450398009950 ether / 1e6), "Checkpoint G long side does not contain the expected value");
      assertTrue(longPoolValue > 0, "Checkpoint G long side was not seeded");
      assertEq(longPoolLeverage, 1e18, "Checkpoint G longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint G longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint G longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint G longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint G longPoolOddBatchedRedeem should be 0");
    }
    {
      address floatPoolToken = market.get_pool_token(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolValue = market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      assertTrue(floatPoolToken != address(0), "Checkpoint G float token not initialized");
      assertEq((floatPoolValue / 1e6), (100.119402985074 ether / 1e6), "Checkpoint G float side does not contain the expected value");
      assertTrue(floatPoolValue > 0, "Checkpoint G float side was not seeded");
      assertEq(floatPoolEvenBatchedDeposit, 0, "Checkpoint G floatPoolEvenBatchedDeposit does not match mint amount");
      assertEq(floatPoolEvenBatchedRedeem, 0, "Checkpoint G floatPoolEvenBatchedRedeem should be 0");
      assertEq(floatPoolOddBatchedDeposit, 0, "Checkpoint G floatPoolOddBatchedDeposit should be 0");
      assertEq(floatPoolOddBatchedRedeem, 0, "Checkpoint G floatPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointH() public {
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertTrue(shortPoolToken != address(0), "Checkpoint H short token not initialized");
      assertEq((shortPoolValue / 1e6), (112.890047251181 ether / 1e6), "Checkpoint H short side does not contain the expected value");
      assertEq(shortPoolLeverage, -1e18, "Checkpoint H shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint H shortPoolEvenBatchedDeposit should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint H shortPoolEvenBatchedRedeem should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint H shortPoolOddBatchedDeposit should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint H shortPoolOddBatchedRedeem should be 0");
    }
    {
      address longPoolToken = market.get_pool_token(IMarketCommon.PoolType.LONG, POOL_INDEX);
      int96 longPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);
      assertTrue(longPoolToken != address(0), "Checkpoint H long token not initialized");
      assertEq((longPoolValue / 1e6), (101.960199004975 ether / 1e6), "Checkpoint H long side does not contain the expected value");
      assertTrue(longPoolValue > 0, "Checkpoint H long side was not seeded");
      assertEq(longPoolLeverage, 1e18, "Checkpoint H longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint H longPoolEvenBatchedDeposit does not match mint amount");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint H longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint H longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint H longPoolOddBatchedRedeem should be 0");
    }
    {
      address floatPoolToken = market.get_pool_token(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolValue = market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      assertTrue(floatPoolToken != address(0), "Checkpoint H float token not initialized");
      assertEq((floatPoolValue / 1e6), (100.179753743843 ether / 1e6), "Checkpoint H float side does not contain the expected value");
      assertTrue(floatPoolValue > 0, "Checkpoint H float side was not seeded");
      assertEq(floatPoolEvenBatchedDeposit, 0, "Checkpoint H floatPoolEvenBatchedDeposit does not match mint amount");
      assertEq(floatPoolEvenBatchedRedeem, 0, "Checkpoint H floatPoolEvenBatchedRedeem should be 0");
      assertEq(floatPoolOddBatchedDeposit, 0, "Checkpoint H floatPoolOddBatchedDeposit should be 0");
      assertEq(floatPoolOddBatchedRedeem, 0, "Checkpoint H floatPoolOddBatchedRedeem should be 0");
    }
  }

  function checkUserPaymentTokenDepositActionAtCheckpointC(uint256 checkpointBMintAmount) public {
    IMarketCommon.UserAction memory userDepositAction = market.get_userAction_depositPaymentToken(user1, IMarketCommon.PoolType.LONG, POOL_INDEX);

    assertEq(userDepositAction.correspondingEpoch, 2, "Checkpoint C user deposit action corresponding epoch set incorrectly");
    assertEq(userDepositAction.amount, checkpointBMintAmount, "Checkpoint C user deposit action amount does not match mint amounnt");
    assertEq(userDepositAction.nextEpochAmount, 0, "Checkpoint C user deposit action nextEpochAmount should be 0 since this occurs outside of MEWT");
  }

  function checkUserPaymentTokenDepositActionAtCheckpointD() public {
    IMarketCommon.UserAction memory userDepositAction = market.get_userAction_depositPaymentToken(user1, IMarketCommon.PoolType.LONG, POOL_INDEX);

    assertEq(userDepositAction.correspondingEpoch, 0, "Checkpoint D user deposit action corresponding epoch set incorrectly");
    assertEq(userDepositAction.amount, 0, "Checkpoint D user deposit action amount should be 0");
    assertEq(userDepositAction.nextEpochAmount, 0, "Checkpoint D user deposit action nextEpochAmount should be 0 since this occurs outside of MEWT");
  }

  function checkUser1PoolTokenRedeemActionAtCheckpointE() public {
    IMarketCommon.UserAction memory userRedeemAction = market.get_userAction_redeemPoolToken(user1, IMarketCommon.PoolType.LONG, POOL_INDEX);

    assertEq(userRedeemAction.correspondingEpoch, 3, "Checkpoint E user redeem action corresponding epoch set incorrectly");
    assertEq(userRedeemAction.amount, 6e18, "Checkpoint E user redeem action amount should be 6");
    assertEq(userRedeemAction.nextEpochAmount, 0, "Checkpoint E user redeem action nextEpochAmount should be 0 since this occurs outside of MEWT");
  }

  function checkUser2And3PaymentTokenDepositActionAtCheckpointE(address _user, uint112 _expectedMintAmount) public {
    IMarketCommon.UserAction memory userDepositAction = market.get_userAction_depositPaymentToken(_user, IMarketCommon.PoolType.SHORT, POOL_INDEX);

    assertEq(userDepositAction.correspondingEpoch, 3, "Checkpoint E user deposit action corresponding epoch set incorrectly");
    assertEq(userDepositAction.amount, _expectedMintAmount, "Checkpoint E user deposit action amount should be 0");
    assertEq(userDepositAction.nextEpochAmount, 0, "Checkpoint E user deposit action nextEpochAmount should be 0 since this occurs outside of MEWT");
  }

  function checkUserDepositAndRedeemActionsAtCheckpointG(address _user, IMarketCommon.PoolType poolType) public {
    IMarketCommon.UserAction memory userDepositAction = market.get_userAction_depositPaymentToken(_user, poolType, POOL_INDEX);
    IMarketCommon.UserAction memory userRedeemAction = market.get_userAction_redeemPoolToken(_user, poolType, POOL_INDEX);

    assertEq(userDepositAction.correspondingEpoch, 0, "Checkpoint G user deposit action corresponding epoch set incorrectly");
    assertEq(userDepositAction.amount, 0, "Checkpoint G user deposit action amount should be 0");
    assertEq(userDepositAction.nextEpochAmount, 0, "Checkpoint G user deposit action nextEpochAmount should be 0 since this occurs outside of MEWT");

    assertEq(userRedeemAction.correspondingEpoch, 0, "Checkpoint G user deposit action corresponding epoch set incorrectly");
    assertEq(userRedeemAction.amount, 0, "Checkpoint G user deposit action amount should be 0");
    assertEq(userRedeemAction.nextEpochAmount, 0, "Checkpoint G user deposit action nextEpochAmount should be 0 since this occurs outside of MEWT");
  }

  /// @dev this test follows this excalidraw image exactly: https://app.excalidraw.com/l/2big5WYTyfh/2HyRQh5Imw4
  function testMarketScenarioOne() public {
    user1 = getFreshUser();
    user2 = getFreshUser();
    user3 = getFreshUser();

    //prices
    prices[0] = 1e18;
    prices[1] = 1010e15;
    prices[2] = 1020e15;
    prices[3] = 1015e15;
    prices[4] = 1005e15;
    prices[5] = 995e15;
    prices[6] = 1000e15;

    //Events in timeline order
    oracleTimes[0] = 46;
    epochStartTime[0] = 50;
    oracleTimes[1] = 52;
    epochStartTime[1] = 60;
    oracleTimes[2] = 65;
    //Market deployed and initialized
    checkPointA = 69;
    epochStartTime[2] = 70;
    oracleTimes[3] = 75;
    //user1 mints 8 long
    checkPointB = 77;
    //checks value change and if mint amount is added to batch
    checkPointC = 78;
    epochStartTime[3] = 80;
    oracleTimes[4] = 83;
    //check value change and user1 mint exectuion
    //user1 redeems 6 pool tokens
    //user2 and 3 mint 4 and 9 short respectively
    checkPointD = 88;
    // check that multiple user actions are batched correctly for execution
    checkPointE = 89;
    epochStartTime[4] = 90;

    // check that system state update has not triggered - check pool values and batched actions
    checkPointF = 91;
    oracleTimes[5] = 92;

    // checks value change and user actions were executed
    checkPointG = 97;

    oracleTimes[6] = 103;
    // checks value change
    checkPointH = 105;

    /*╔══════════════════╗
      ║   CHECKPOINT A   ║
      ╚══════════════════╝*/
    vm.warp(checkPointA);

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

    assertEq(oracleManager.getCurrentEpochIndex(), 1, "Checkpoint A Not in 1st Epoch");

    // Check constructor addresses are initialized
    assertTrue(market.get_paymentToken() != address(0), "payment token not initialized");
    assertTrue(address(market.get_registry()) != address(0), "registry not initialized");
    assertTrue(market.get_gems() != address(0), "gems not initialized");

    // Check Epoch Info
    IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();

    // Should this equal 0 or 1?
    assertEq(epochInfo.latestExecutedEpochIndex, 0, "Checkpoint A latest Executed Epoch Index not correct");
    assertEq(epochInfo.latestExecutedOracleRoundId, 2, "Checkpoint A previous execution price oracle identifier incorrect");

    checkMarketPoolsAtCheckpointA();

    vm.warp(oracleTimes[3]);
    chainlinkOracleMock.pushPrice(prices[3]);
    assertEq(chainlinkOracleMock.currentRoundId(), 3, "Oracle round id should be 3");

    /*╔══════════════════╗
      ║   CHECKPOINT B   ║
      ╚══════════════════╝*/
    vm.warp(checkPointB);
    changePrank(user1);

    defaultPaymentToken.mint(10e18);
    defaultPaymentToken.approve(address(market), 10e18);

    uint112 CHECKPOINT_B_USER_1_PAYMENT_TOKEN_MINT_AMOUNT = 8e18;
    market.mintLong(0, CHECKPOINT_B_USER_1_PAYMENT_TOKEN_MINT_AMOUNT);

    /*╔══════════════════╗
      ║   CHECKPOINT C   ║
      ╚══════════════════╝*/
    changePrank(ADMIN);
    vm.warp(checkPointC);

    updateSystemStateSingleMarket(marketIndex);

    checkMarketPoolsAtCheckpointC(CHECKPOINT_B_USER_1_PAYMENT_TOKEN_MINT_AMOUNT);
    checkUserPaymentTokenDepositActionAtCheckpointC(CHECKPOINT_B_USER_1_PAYMENT_TOKEN_MINT_AMOUNT);

    vm.warp(oracleTimes[4]);
    chainlinkOracleMock.pushPrice(prices[4]);
    assertEq(chainlinkOracleMock.currentRoundId(), 4, "Oracle round id should be 4");

    /*╔══════════════════╗
      ║   CHECKPOINT D   ║
      ╚══════════════════╝*/

    vm.warp(checkPointD);

    updateSystemStateSingleMarket(marketIndex);

    settleAllUserActions(market, user1);

    checkMarketPoolsAtCheckpointD();
    checkUserPaymentTokenDepositActionAtCheckpointD();

    // User actions

    changePrank(user1);
    uint112 CHECKPOINT_D_USER_1_POOLTOKEN_TOKEN_REDEEM_AMOUNT = 6e18;
    market.redeemLong(POOL_INDEX, CHECKPOINT_D_USER_1_POOLTOKEN_TOKEN_REDEEM_AMOUNT);

    changePrank(user2);
    defaultPaymentToken.mint(10e18);
    defaultPaymentToken.approve(address(market), 10e18);
    uint112 CHECKPOINT_D_USER_2_PAYMENT_TOKEN_MINT_AMOUNT = 4e18;
    market.mintShort(POOL_INDEX, CHECKPOINT_D_USER_2_PAYMENT_TOKEN_MINT_AMOUNT);

    changePrank(user3);
    defaultPaymentToken.mint(10e18);
    defaultPaymentToken.approve(address(market), 10e18);
    uint112 CHECKPOINT_D_USER_3_PAYMENT_TOKEN_MINT_AMOUNT = 9e18;
    market.mintShort(POOL_INDEX, CHECKPOINT_D_USER_3_PAYMENT_TOKEN_MINT_AMOUNT);

    /*╔══════════════════╗
      ║   CHECKPOINT E   ║
      ╚══════════════════╝*/

    vm.warp(checkPointE);

    checkMarketPoolsAtCheckpointE();

    checkUser1PoolTokenRedeemActionAtCheckpointE();

    checkUser2And3PaymentTokenDepositActionAtCheckpointE(user2, CHECKPOINT_D_USER_2_PAYMENT_TOKEN_MINT_AMOUNT);
    checkUser2And3PaymentTokenDepositActionAtCheckpointE(user3, CHECKPOINT_D_USER_3_PAYMENT_TOKEN_MINT_AMOUNT);

    /*╔══════════════════╗
      ║   CHECKPOINT F   ║
      ╚══════════════════╝*/

    vm.warp(checkPointF);

    // Checkpoint E checks should not have changed, we are in the next epoch but
    // still in EWT and no exectutions or updateSystemState has occured.
    checkUser1PoolTokenRedeemActionAtCheckpointE();

    checkUser2And3PaymentTokenDepositActionAtCheckpointE(user2, CHECKPOINT_D_USER_2_PAYMENT_TOKEN_MINT_AMOUNT);
    checkUser2And3PaymentTokenDepositActionAtCheckpointE(user3, CHECKPOINT_D_USER_3_PAYMENT_TOKEN_MINT_AMOUNT);

    vm.warp(oracleTimes[5]);
    chainlinkOracleMock.pushPrice(prices[5]);
    assertEq(chainlinkOracleMock.currentRoundId(), 5, "Oracle round id should be 5");

    /*╔══════════════════╗
      ║   CHECKPOINT G   ║
      ╚══════════════════╝*/

    vm.warp(checkPointG);

    updateSystemStateSingleMarket(marketIndex);

    settleAllUserActions(market, user1);
    settleAllUserActions(market, user2);
    settleAllUserActions(market, user3);

    checkUserDepositAndRedeemActionsAtCheckpointG(user1, IMarketCommon.PoolType.LONG);
    checkUserDepositAndRedeemActionsAtCheckpointG(user1, IMarketCommon.PoolType.SHORT);
    checkUserDepositAndRedeemActionsAtCheckpointG(user2, IMarketCommon.PoolType.LONG);
    checkUserDepositAndRedeemActionsAtCheckpointG(user2, IMarketCommon.PoolType.SHORT);
    checkUserDepositAndRedeemActionsAtCheckpointG(user3, IMarketCommon.PoolType.LONG);
    checkUserDepositAndRedeemActionsAtCheckpointG(user3, IMarketCommon.PoolType.SHORT);

    checkMarketPoolsAtCheckpointG();

    vm.warp(oracleTimes[6]);
    chainlinkOracleMock.pushPrice(prices[6]);
    assertEq(chainlinkOracleMock.currentRoundId(), 6, "Oracle round id should be 5");

    /*╔══════════════════╗
      ║   CHECKPOINT H   ║
      ╚══════════════════╝*/

    vm.warp(checkPointH);

    updateSystemStateSingleMarket(marketIndex);

    checkMarketPoolsAtCheckpointH();
  }
}
