// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../MarketCore.sol";
import "../MarketExtended.sol";

/// @title Non-core market contract
/// @notice Functions in this contract are either view functions or admin-callable functions
contract MarketExtended is MarketExtendedCore, IMarketExtended {
  constructor(address _paymentToken, IRegistry _registry) MarketExtendedCore(_paymentToken, _registry, 1e18) {}

  /// @notice Purely a convenience function to get the seeder address. Used in testing.
  function getSeederAddress() external pure returns (address) {
    return MARKET_SEEDER_DEAD_ADDRESS;
  }

  /// @notice Purely a convenience function to get the pool token address. Used in testing.
  function getPoolTokenAddress(IMarketCommon.PoolType poolType, uint256 index) external view returns (address) {
    return pools[poolType][index].fixedConfig.token;
  }

  /// @notice Returns the number of pools of poolType i.e. Long or Short
  /// @param isLong true for long, false for short
  function getNumberOfPools(bool isLong) external view returns (uint256) {
    if (isLong) {
      return _numberOfPoolsOfType[uint8(IMarketCommon.PoolType.LONG)];
    } else {
      return _numberOfPoolsOfType[uint8(IMarketCommon.PoolType.SHORT)];
    }
  }

  /// @notice Returns batched deposit amount in payment token for even numbered epochs.
  /// @param poolType indicates either Long or Short pool type
  /// @param pool index of the pool on the market side
  function get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256) {
    return uint256(pools[poolType][pool].batchedAmount[0].paymentToken_deposit);
  }

  /// @notice Returns batched deposit amount in payment token for odd numbered epochs.
  /// @param poolType indicates either Long or Short pool type
  /// @param pool index of the pool on the market side
  function get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256) {
    return uint256(pools[poolType][pool].batchedAmount[1].paymentToken_deposit);
  }

  /// @notice Returns batched redeem amount in pool token for even numbered epochs.
  /// @param poolType indicates either Long or Short pool type
  /// @param pool index of the pool on the market side
  function get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256) {
    return uint256(pools[poolType][pool].batchedAmount[0].poolToken_redeem);
  }

  /// @notice Returns batched redeem amount in pool token for odd numbered epochs.
  /// @param poolType indicates either Long or Short pool type
  /// @param pool index of the pool on the market side
  function get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256) {
    return uint256(pools[poolType][pool].batchedAmount[1].poolToken_redeem);
  }

  /// @notice Total number of pending mints for this epoch
  function get_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256) {
    return uint256(pools[poolType][pool].batchedAmount[oracleManager.getCurrentEpochIndex() & 1].paymentToken_deposit);
  }

  /// @notice Total number of pending redeems for this epoch
  function get_batchedAmountPoolToken_redeem(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256) {
    return uint256(pools[poolType][pool].batchedAmount[oracleManager.getCurrentEpochIndex() & 1].poolToken_redeem);
  }

  /// @notice Whether the minting action is paused or not
  function get_mintingPaused() external view returns (bool) {
    return mintingPaused;
  }

  /// @notice Whether the market is deprecated or not
  function get_marketDeprecated() external view returns (bool) {
    return marketDeprecated;
  }

  /// @notice The largest acceptable percentage that the underlying asset can move in 1 epoch
  function get_maxPercentChange() external view returns (int256) {
    return maxPercentChange;
  }

  /// @notice Admin-adjustable value that determines the magnitude of funding amount each epoch
  function get_fundingRateMultiplier() external view returns (uint128) {
    return fundingVariables.fundingRateMultiplier;
  }

  /// @notice Admin-adjustable value that determines the minimum magnitude of funding amount each epoch
  function get_minFloatPoolFundingBoost() external view returns (uint128) {
    return fundingVariables.minFloatPoolFundingBoost;
  }

  /// @notice Admin-adjustable value that determines the mint fee
  function get_stabilityFee_basisPoints() external view returns (uint256) {
    return stabilityFee_basisPoints;
  }

  /// @notice The effective liquidity (actual liquidity * leverage) for all the pools of a specific type
  function get_effectiveLiquidityForPoolType() external view returns (uint256[2] memory) {
    return effectiveLiquidityForPoolType;
  }

  /// @notice View function for the gems state variable
  /// @return address of the gems contract
  function get_gems() external view returns (address) {
    return gems;
  }

  /// @notice View function for the registry state variable
  /// @return address of the registry contract
  function get_registry() external view returns (IRegistry) {
    return registry;
  }
}

contract Market is MarketCore, IMarketTieredLeverage {
  using MathUintFloat for uint256;

  constructor(
    IMarketExtended _nonCoreFunctionsDelegatee,
    address _paymentToken,
    IRegistry registry
  ) MarketCore(_nonCoreFunctionsDelegatee, _paymentToken, registry) {}

  function get_FLOAT_POOL_ROLE() external pure override returns (bytes32) {
    return FLOAT_POOL_ROLE;
  }

  /// @notice Returns the balance of user actions in epochs which have been executed but not yet distributed to users.
  /// @dev Prices have a fixed 18 decimals.
  /// @param user Address of user.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier The index of the pool in the side.
  /// @return confirmedButNotSettledBalance Returns balance of user actions in epochs which have been executed but not yet distributed to users.
  function getUsersConfirmedButNotSettledPoolTokenBalance(
    address user,
    IMarketCommon.PoolType poolType,
    uint8 poolTier
  ) external view returns (uint256 confirmedButNotSettledBalance) {
    /* NOTE:
      This function is the exact same logic/structure as settlePoolUserMints with lines of code commented out for setting state variables.
      We have left those commented out lines of code in the function so that this is easy to see. In particular this is why the team has decided to keep this function "OUT OF SCOPE" for the audit.
      Every comment labled with unused_from_settlePoolUserMints is code that came from the other version of this function.
    */
    IMarketCommon.UserAction memory userAction = userAction_depositPaymentToken[user][poolType][poolTier];

    // Case if the primary order can be executed.
    if (userAction.correspondingEpoch != 0 && userAction.correspondingEpoch <= epochInfo.latestExecutedEpochIndex) {
      uint256 poolToken_price = poolToken_priceSnapshot[userAction.correspondingEpoch][poolType][poolTier];

      /* unused_from_settlePoolUserMints
      address poolToken = pools[poolType][poolTier].token;
      */

      confirmedButNotSettledBalance = uint256(userAction.amount).div(poolToken_price);

      // If user has a mint in MEWT simply bump it one slot.
      if (userAction.nextEpochAmount > 0) {
        uint32 secondaryOrderEpoch = userAction.correspondingEpoch + 1;

        // need to check if we can also execute this
        if (secondaryOrderEpoch <= epochInfo.latestExecutedEpochIndex) {
          // then also execute
          poolToken_price = poolToken_priceSnapshot[secondaryOrderEpoch][poolType][poolTier];
          confirmedButNotSettledBalance += uint256(userAction.nextEpochAmount).div(poolToken_price);

          /* unused_from_settlePoolUserMints
          userAction.amount = 0;
          userAction.correspondingEpoch = 0;
        } else {
          userAction.amount = userAction.nextEpochAmount;
          userAction.correspondingEpoch = secondaryOrderEpoch;
          */
        }
        /* unused_from_settlePoolUserMints
        // has to zero as either executed or bumped to primary slot
        userAction.nextEpochAmount = 0;
      } else {
        // If user has no pending mints then simply wipe
        userAction.amount = 0;
        userAction.correspondingEpoch = 0;
        */
      }

      /* unused_from_settlePoolUserMints
      //slither-disable-next-line unchecked-transfer
      IPoolToken(poolToken).transfer(user, amountPoolTokenToMint);

      userAction_depositPaymentToken[user][poolType][poolTier] = userAction;

      emit ExecuteEpochSettlementMintUser(packPoolId(poolType, uint8(poolTier)), user, epochInfo.latestExecutedEpochIndex);
      */
    }
  }

  /// @notice Returns the number of pools of poolType i.e. Long or Short
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @return numberOfPoolsOfType Number of pools of poolType
  function numberOfPoolsOfType(IMarketCommon.PoolType poolType) external view returns (uint256) {
    return _numberOfPoolsOfType[uint8(poolType)];
  }

  /// @notice Returns the interface of OracleManager for the market
  /// @return oracleManager OracleManager interface
  function get_oracleManager() external view returns (IOracleManager) {
    return oracleManager;
  }

  /// @notice Returns the address of the YieldManager for the market
  /// @return liquidityManager address of the YieldManager
  function get_liquidityManager() external view returns (address) {
    return liquidityManager;
  }

  /// @notice Returns the deposit action in payment tokens of provided user for the given poolType and poolTier.
  /// @dev Action amounts have a fixed 18 decimals.
  /// @param user Address of the user.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier The index of the pool in the side.
  /// @return userAction_depositPaymentToken Outstanding deposit action by user for the given poolType and poolTier.
  function get_userAction_depositPaymentToken(
    address user,
    IMarketCommon.PoolType poolType,
    uint256 poolTier
  ) external view returns (IMarketCommon.UserAction memory) {
    return userAction_depositPaymentToken[user][poolType][poolTier];
  }

  /// @notice Returns the redeem action in pool tokens of provided user for the given poolType and poolTier.
  /// @dev Action amounts have a fixed 18 decimals.
  /// @param user Address of the user.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier The index of the pool in the side.
  /// @return userAction_redeemPoolToken Outstanding redeem action by user for the given poolType and poolTier.
  function get_userAction_redeemPoolToken(
    address user,
    IMarketCommon.PoolType poolType,
    uint256 poolTier
  ) external view returns (IMarketCommon.UserAction memory) {
    return userAction_redeemPoolToken[user][poolType][poolTier];
  }

  /// @notice Returns the pool liquidity given poolType and poolTier.
  /// @param poolType An enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier The index of the pool in the side.
  /// @return Liquidity of the pool
  function get_pool_value(IMarketCommon.PoolType poolType, uint256 poolTier) external view returns (uint256) {
    return pools[poolType][poolTier].value;
  }

  /// @notice Returns all information about a particular pool
  /// @param poolType An enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier The index of the pool in the side.
  /// @return Struct containing information about the pool i.e. value, leverage etc.
  function get_pool(IMarketCommon.PoolType poolType, uint256 poolTier) external view returns (IMarketCommon.Pool memory) {
    return pools[poolType][poolTier];
  }

  /// @notice Returns the pool token address given poolType and poolTier.
  /// @param poolType An enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier The index of the pool in the side.
  /// @return Address of the pool token
  function get_pool_token(IMarketCommon.PoolType poolType, uint256 poolTier) external view returns (address) {
    return pools[poolType][poolTier].fixedConfig.token;
  }

  /// @notice Returns the pool leverage given poolType and poolTier.
  /// @param poolType An enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier The index of the pool in the side.
  /// @return Leverage of the pool
  function get_pool_leverage(IMarketCommon.PoolType poolType, uint256 poolTier) external view returns (int96) {
    return pools[poolType][poolTier].fixedConfig.leverage;
  }

  /// @notice Returns the price of the pool token given poolType and poolTier.
  /// @dev Prices have a fixed 18 decimals.
  /// @param epoch Number of epoch that has been executed.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier The index of the pool in the side.
  /// @return poolToken_priceSnapshot Price of the pool tokens in the pool.
  function get_poolToken_priceSnapshot(
    uint32 epoch,
    IMarketCommon.PoolType poolType,
    uint256 poolTier
  ) external view returns (uint256) {
    return poolToken_priceSnapshot[epoch][poolType][poolTier];
  }

  /// @notice Returns the epochInfo struct.
  /// @return epochInfo Struct containing info about the latest executed epoch and previous epoch.
  function get_epochInfo() external view returns (IMarketCommon.EpochInfo memory) {
    return epochInfo;
  }

  /// @notice Getter function for the state variable paymentToken
  /// @return The address of the paymentToken for this market
  function get_paymentToken() external view returns (address) {
    return paymentToken;
  }
}
