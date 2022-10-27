// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/console2.sol";
import "../../testing/FloatTest.t.sol";

contract MarketFundingRateSenarioOne is FloatTest {
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
      assertEq(shortPoolValue, 50e18, "Checkpoint A short side was not seeded correctly");
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
      assertEq(longPoolValue, 50e18, "Checkpoint A long side was not seeded correctly");
      assertEq(longPoolLeverage, 1e18, "Checkpoint A longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint A longPoolEvenBatchedDeposit should be 0");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint A longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint A longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint A longPoolOddBatchedRedeem should be 0");
    }
    {
      address floatPoolToken = market.get_pool_token(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolValue = market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      assertTrue(floatPoolToken != address(0), "Checkpoint A float token not initialized");
      assertEq(floatPoolValue, 50e18, "Checkpoint A float side was not seeded correctly");
      assertEq(floatPoolEvenBatchedDeposit, 0, "Checkpoint A floatPoolEvenBatchedDeposit should be 0");
      assertEq(floatPoolEvenBatchedRedeem, 0, "Checkpoint A floatPoolEvenBatchedRedeem should be 0");
      assertEq(floatPoolOddBatchedDeposit, 0, "Checkpoint A floatPoolOddBatchedDeposit should be 0");
      assertEq(floatPoolOddBatchedRedeem, 0, "Checkpoint A floatPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointB() public {
    // check pools
    {
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertEq(shortPoolValue, 50e18, "Checkpoint B short side was not updated correctly");
      assertEq(shortPoolLeverage, -1e18, "Checkpoint B shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint B shortPoolEvenBatchedDeposit should be 0");
      assertEq(shortPoolEvenBatchedRedeem, 0, "Checkpoint B shortPoolEvenBatchedRedeem should be 0");
      assertEq(shortPoolOddBatchedDeposit, 0, "Checkpoint B shortPoolOddBatchedDeposit should be 0");
      assertEq(shortPoolOddBatchedRedeem, 0, "Checkpoint B shortPoolOddBatchedRedeem should be 0");
    }
    {
      int96 longPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.LONG, POOL_INDEX);
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);
      assertEq(longPoolValue, 50e18, "Checkpoint B long side was not updated correctly");
      assertEq(longPoolLeverage, 1e18, "Checkpoint B longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 8e18, "Checkpoint B longPoolEvenBatchedDeposit should be 8e18");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint B longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint B longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint B longPoolOddBatchedRedeem should be 0");
    }
    {
      uint256 floatPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolValue = market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      assertEq(floatPoolValue, 50e18, "Checkpoint B float side was not updated correctly");
      assertEq(floatPoolEvenBatchedDeposit, 0, "Checkpoint B floatPoolEvenBatchedDeposit should be 0");
      assertEq(floatPoolEvenBatchedRedeem, 0, "Checkpoint B floatPoolEvenBatchedRedeem should be 0");
      assertEq(floatPoolOddBatchedDeposit, 0, "Checkpoint B floatPoolOddBatchedDeposit should be 0");
      assertEq(floatPoolOddBatchedRedeem, 0, "Checkpoint B floatPoolOddBatchedRedeem should be 0");
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
      assertEq(shortPoolValue, 50e18, "Checkpoint C short side was not updated correctly");
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
      assertEq(longPoolValue, 58e18, "Checkpoint C long side was not updated correctly");
      assertEq(longPoolLeverage, 1e18, "Checkpoint C longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint C longPoolEvenBatchedDeposit should be 0");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint C longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint C longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint C longPoolOddBatchedRedeem should be 0");
    }
    {
      address floatPoolToken = market.get_pool_token(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolValue = market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      assertTrue(floatPoolToken != address(0), "Checkpoint C float token not initialized");
      assertEq(floatPoolValue, 50e18, "Checkpoint C float side was not updated correctly");
      assertEq(floatPoolEvenBatchedDeposit, 0, "Checkpoint C floatPoolEvenBatchedDeposit should be 0");
      assertEq(floatPoolEvenBatchedRedeem, 0, "Checkpoint C floatPoolEvenBatchedRedeem should be 0");
      assertEq(floatPoolOddBatchedDeposit, 0, "Checkpoint C floatPoolOddBatchedDeposit should be 0");
      assertEq(floatPoolOddBatchedRedeem, 0, "Checkpoint C floatPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointD() public {
    // check pools
    int256[2] memory fundingAmounts = calculateFundingAmount(uint8(IMarketCommon.PoolType.LONG), 58e18, 50e18, IMarket(address(market)));
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertTrue(shortPoolToken != address(0), "Checkpoint D short token not initialized");
      // TODO: investigate rounding issues here
      assertApproxEqAbs(
        shortPoolValue,
        50e18 - uint256(-fundingAmounts[uint8(IMarketCommon.PoolType.SHORT)]),
        9,
        "Checkpoint D short side was not updated correctly"
      );
      assertEq(shortPoolLeverage, -1e18, "Checkpoint D shortPoolLeverage should be 1x");
      assertEq(shortPoolEvenBatchedDeposit, 0, "Checkpoint D shortPoolEvenBatchedDeposit should be 0");
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
      assertTrue(longPoolToken != address(0), "Checkpoint D long token not initialized");
      uint256 longPoolValue = market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX);

      assertTrue(longPoolToken != address(0), "Checkpoint D long token not initialized");
      // TODO: investigate rounding issues here
      assertApproxEqAbs(
        longPoolValue,
        58e18 - uint256(fundingAmounts[uint8(IMarketCommon.PoolType.LONG)]),
        9,
        "Checkpoint D long side was not updated correctly"
      );
      assertEq(longPoolLeverage, 1e18, "Checkpoint D longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint D longPoolEvenBatchedDeposit should be 0");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint D longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint D longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint D longPoolOddBatchedRedeem should be 0");
    }
    {
      address floatPoolToken = market.get_pool_token(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolValue = market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      assertTrue(floatPoolToken != address(0), "Checkpoint D float token not initialized");
      assertEq(
        floatPoolValue,
        50e18 + uint256(fundingAmounts[uint8(IMarketCommon.PoolType.LONG)]) + uint256(-fundingAmounts[uint8(IMarketCommon.PoolType.SHORT)]),
        "Checkpoint D float side was not updated correctly"
      );
      assertEq(floatPoolEvenBatchedDeposit, 0, "Checkpoint D floatPoolEvenBatchedDeposit should be 0");
      assertEq(floatPoolEvenBatchedRedeem, 0, "Checkpoint D floatPoolEvenBatchedRedeem should be 0");
      assertEq(floatPoolOddBatchedDeposit, 0, "Checkpoint D floatPoolOddBatchedDeposit should be 0");
      assertEq(floatPoolOddBatchedRedeem, 0, "Checkpoint D floatPoolOddBatchedRedeem should be 0");
    }
  }

  function checkMarketPoolsAtCheckpointE() public {
    int256[2] memory previousFundingAmounts = calculateFundingAmount(uint8(IMarketCommon.PoolType.LONG), 58e18, 50e18, IMarket(address(market)));
    int256[2] memory fundingAmounts = calculateFundingAmount(
      uint8(IMarketCommon.PoolType.LONG),
      58e18 - uint256(previousFundingAmounts[uint8(IMarketCommon.PoolType.LONG)]),
      50e18 - uint256(-previousFundingAmounts[uint8(IMarketCommon.PoolType.SHORT)]),
      IMarket(address(market))
    );
    {
      address shortPoolToken = market.get_pool_token(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      int96 shortPoolLeverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      uint256 shortPoolValue = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX);
      assertTrue(shortPoolToken != address(0), "Checkpoint E short token not initialized");
      // TODO: investigate rounding issues here
      assertApproxEqAbs(
        shortPoolValue,
        50e18 - uint256(-previousFundingAmounts[uint8(IMarketCommon.PoolType.SHORT)]) - uint256(-fundingAmounts[uint8(IMarketCommon.PoolType.SHORT)]),
        15,
        "Checkpoint E short side was not updated correctly"
      );
      assertEq(shortPoolLeverage, -1e18, "Checkpoint E shortPoolLeverage should be 1x");
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
      // TODO: investigate rounding issues here
      assertApproxEqAbs(
        longPoolValue,
        58e18 - uint256(previousFundingAmounts[uint8(IMarketCommon.PoolType.LONG)]) - uint256(fundingAmounts[uint8(IMarketCommon.PoolType.LONG)]),
        9,
        "Checkpoint E long side was not updated correctly"
      );
      assertEq(longPoolLeverage, 1e18, "Checkpoint E longPoolLeverage should be 1x");
      assertEq(longPoolEvenBatchedDeposit, 0, "Checkpoint E longPoolEvenBatchedDeposit should be 0");
      assertEq(longPoolEvenBatchedRedeem, 0, "Checkpoint E longPoolEvenBatchedRedeem should be 0");
      assertEq(longPoolOddBatchedDeposit, 0, "Checkpoint E longPoolOddBatchedDeposit should be 0");
      assertEq(longPoolOddBatchedRedeem, 0, "Checkpoint E longPoolOddBatchedRedeem should be 0");
    }
    {
      address floatPoolToken = market.get_pool_token(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedDeposit = market.get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedDeposit = market.get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolEvenBatchedRedeem = market.get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolOddBatchedRedeem = market.get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      uint256 floatPoolValue = market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);
      assertTrue(floatPoolToken != address(0), "Checkpoint E float token not initialized");
      // TODO: investigate rounding issues here
      assertApproxEqAbs(
        floatPoolValue,
        50e18 +
          uint256(-previousFundingAmounts[uint8(IMarketCommon.PoolType.SHORT)]) +
          uint256(previousFundingAmounts[uint8(IMarketCommon.PoolType.LONG)]) +
          uint256(-fundingAmounts[uint8(IMarketCommon.PoolType.SHORT)]) +
          uint256(fundingAmounts[uint8(IMarketCommon.PoolType.LONG)]),
        7,
        "Checkpoint E float side was not updated correctly"
      );
      assertEq(floatPoolEvenBatchedDeposit, 0, "Checkpoint E floatPoolEvenBatchedDeposit should be 0");
      assertEq(floatPoolEvenBatchedRedeem, 0, "Checkpoint E floatPoolEvenBatchedRedeem should be 0");
      assertEq(floatPoolOddBatchedDeposit, 0, "Checkpoint E floatPoolOddBatchedDeposit should be 0");
      assertEq(floatPoolOddBatchedRedeem, 0, "Checkpoint D floatPoolOddBatchedRedeem should be 0");
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

  function testMarketSimpleTranchScenarioOne() public {
    user1 = getFreshUser();
    user2 = getFreshUser();
    user3 = getFreshUser();

    //prices
    prices[0] = 100e18;
    prices[1] = 100e18;
    prices[2] = 100e18;
    prices[3] = 100e18;
    prices[4] = 100e18;

    //Events in timeline order
    epochStartTime[0] = 50;
    epochStartTime[1] = 60;
    oracleTimes[0] = 65;
    checkPointA = 69;
    epochStartTime[2] = 70;
    oracleTimes[1] = 75;
    checkPointB = 77;
    epochStartTime[3] = 80;
    oracleTimes[2] = 83;
    checkPointC = 85;
    epochStartTime[4] = 90;
    oracleTimes[3] = 92;
    checkPointD = 98;
    // check that multiple user actions are batched correctly for execution
    oracleTimes[4] = 105;
    checkPointE = 109;

    vm.warp(oracleTimes[0]);
    AggregatorV3Mock chainlinkOracleMock = new AggregatorV3Mock(prices[0], ORACLE_FIRST_ROUND_ID, DEFAULT_ORACLE_DECIMALS);
    chainlinkOracleMock.pushPrice(prices[0]);
    assertEq(chainlinkOracleMock.currentRoundId(), 3, "Oracle round id should be 3");

    /*╔══════════════════╗
      ║   CHECKPOINT A   ║
      ╚══════════════════╝*/
    vm.warp(checkPointA);

    uint256 initialPoolLiquidity = 50e18;
    MarketFactory.PoolLeverage[] memory poolLeverages = new MarketFactory.PoolLeverage[](3);
    poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
    poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
    poolLeverages[2] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);

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

    vm.stopPrank();
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

    // keeping track of total system liquidity
    uint256 totalSystemLiquidity = market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX) +
      market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX) +
      market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX);

    // Should this equal 0 or 1?
    assertEq(epochInfo.latestExecutedEpochIndex, 0, "Checkpoint A latest Executed Epoch Index not correct");
    assertEq(
      epochInfo.latestExecutedOracleRoundId,
      chainlinkOracleMock.currentRoundId(),
      "Checkpoint A previous execution price oracle identifier incorrect"
    );

    checkMarketPoolsAtCheckpointA();

    vm.warp(oracleTimes[1]);
    chainlinkOracleMock.pushPrice(prices[1]);
    assertEq(chainlinkOracleMock.currentRoundId(), 4, "Oracle round id should be 4");

    /*╔══════════════════╗
      ║   CHECKPOINT B   ║
      ╚══════════════════╝*/
    vm.warp(checkPointB);

    defaultPaymentToken.mint(10e18);
    defaultPaymentToken.approve(address(market), 10e18);

    uint112 CHECKPOINT_B_USER_1_PAYMENT_TOKEN_MINT_AMOUNT = 8e18;
    market.mintLong(0, CHECKPOINT_B_USER_1_PAYMENT_TOKEN_MINT_AMOUNT);

    updateSystemStateSingleMarket(marketIndex);

    settleAllUserActions(market, user1);

    epochInfo = market.get_epochInfo();
    assertEq(epochInfo.latestExecutedEpochIndex, 1, "Checkpoint B latest Executed Epoch Index not correct");
    assertApproxEqAbs(
      market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX) +
        market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX) +
        market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX),
      totalSystemLiquidity,
      1,
      "Checkpoint B Total System Liquidity should remain the same"
    );

    checkMarketPoolsAtCheckpointB();

    vm.warp(oracleTimes[2]);
    chainlinkOracleMock.pushPrice(prices[2]);

    /*╔══════════════════╗
      ║   CHECKPOINT C   ║
      ╚══════════════════╝*/
    vm.warp(checkPointC);

    updateSystemStateSingleMarket(marketIndex);
    // only increasing total liquidity here because actions at checkpoint B are only executed at checkpoint C
    totalSystemLiquidity += CHECKPOINT_B_USER_1_PAYMENT_TOKEN_MINT_AMOUNT;
    epochInfo = market.get_epochInfo();
    assertEq(epochInfo.latestExecutedEpochIndex, 2, "Checkpoint C latest Executed Epoch Index not correct");
    assertApproxEqAbs(
      market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX) +
        market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX) +
        market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX),
      totalSystemLiquidity,
      1,
      "Checkpoint C Total System Liquidity should remain the same"
    );

    checkMarketPoolsAtCheckpointC();

    vm.warp(oracleTimes[3]);
    chainlinkOracleMock.pushPrice(prices[3]);

    vm.startPrank(ADMIN);
    market.changeMarketFundingRateMultiplier(
      IMarketExtendedCore.FundingRateUpdate({prevMultiplier: market.get_fundingRateMultiplier(), newMultiplier: 10000})
    );

    vm.stopPrank();

    /*╔══════════════════╗
      ║   CHECKPOINT D   ║
      ╚══════════════════╝*/

    vm.warp(checkPointD);

    updateSystemStateSingleMarket(marketIndex);
    epochInfo = market.get_epochInfo();
    assertEq(epochInfo.latestExecutedEpochIndex, 3, "Checkpoint D latest Executed Epoch Index not correct");
    assertApproxEqAbs(
      market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX) +
        market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX) +
        market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX),
      totalSystemLiquidity,
      1,
      "Checkpoint D Total System Liquidity should remain the same"
    );

    checkMarketPoolsAtCheckpointD();

    vm.warp(oracleTimes[4]);
    chainlinkOracleMock.pushPrice(prices[4]);

    /*╔══════════════════╗
      ║   CHECKPOINT E   ║
      ╚══════════════════╝*/

    vm.warp(checkPointE);

    updateSystemStateSingleMarket(marketIndex);
    epochInfo = market.get_epochInfo();
    assertEq(epochInfo.latestExecutedEpochIndex, 4, "Checkpoint E latest Executed Epoch Index not correct");
    assertApproxEqAbs(
      market.get_pool_value(IMarketCommon.PoolType.SHORT, POOL_INDEX) +
        market.get_pool_value(IMarketCommon.PoolType.LONG, POOL_INDEX) +
        market.get_pool_value(IMarketCommon.PoolType.FLOAT, POOL_INDEX),
      totalSystemLiquidity,
      1,
      "Checkpoint E Total System Liquidity should remain the same"
    );

    checkMarketPoolsAtCheckpointE();
  }
}
