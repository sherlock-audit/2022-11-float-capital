// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "./IMarketCommon.sol";
import "./IOracleManager.sol";
import "./IRegistry.sol";

/// @title Interface for the mutating admin functions of the market
/// @author float
/// @notice Events & functions that are to be callable only by the admin account.
interface IMarketExtendedCore is IMarketCommon {
  /// @notice Parameters of a new pool
  struct SinglePoolInitInfo {
    string name;
    string symbol;
    PoolType poolType;
    uint8 poolTier;
    address token;
    uint96 leverage;
  }

  /// @notice Params for initializing the contract
  /// @dev Without this struct we get stack to deep errors. Grouping the data helps!
  struct InitializePoolsParams {
    SinglePoolInitInfo[] initPools;
    uint256 initialLiquidityToSeedEachPool;
    address seederAndAdmin;
    uint32 _marketIndex;
    address oracleManager;
    address liquidityManager;
  }

  /// @notice Parameters when oracle manager address is updated
  /// @dev Can only be called by the current admin.
  struct OracleUpdate {
    IOracleManager prevOracle;
    IOracleManager newOracle;
  }

  /// @notice Parameters when funding rate is updated
  /// @dev Can only be called by the current admin.
  struct FundingRateUpdate {
    uint256 prevMultiplier;
    uint256 newMultiplier;
  }

  /// @notice Parameters when funding rate is updated
  /// @dev Can only be called by the current admin.
  struct StabilityFeeUpdate {
    uint256 prevStabilityFee;
    uint256 newStabilityFee;
  }

  /// @notice Used in event
  enum ConfigType {
    marketOracleUpdate,
    fundingRateMultiplier,
    stabilityFee
  }

  /// @notice Emitted when core system parameters are changed by admin
  event ConfigChange(ConfigType indexed configChangeType, bytes data);

  /// @notice Emitted when minting is paused/unpaused by admin
  event MintingPauseChange(bool isPaused);

  /// @notice Emitted when market contract is initialized
  event SeparateMarketLaunchedAndSeeded(
    uint32 marketIndex,
    address admin,
    address oracleManager,
    address liquidityManager,
    address paymentToken,
    int256 initialAssetPrice
  );

  /// @notice Emitted when a new pool has been added to an existing market
  event TierAdded(SinglePoolInitInfo newTier, uint256 initialSeed);

  /// @notice Initialize pools in the market
  /// @dev Can only be called by registry contract
  /// @param params struct containing addresses of dependency contracts and other market initialization parameters
  /// @return initializationSuccess bool value indicating whether initialization was successful.
  function initializePools(InitializePoolsParams memory params) external returns (bool);

  /// @notice Update oracle for a market
  /// @dev Can only be called by the current admin.
  /// @param oracleConfig Address of the replacement oracle manager.
  function updateMarketOracle(OracleUpdate memory oracleConfig) external;

  /// @notice Stop allowing mints on the market
  /// @dev Can only be called by the current admin.
  function pauseMinting() external;

  /// @notice Resume allowing mints on the market
  /// @dev Can only be called by the current admin.
  function unpauseMinting() external;

  /// @notice Update the yearly funding rate multiplier for the market
  /// @dev Can only be called by the current admin.
  /// @param fundingRateConfig New funding rate multiplier
  function changeMarketFundingRateMultiplier(FundingRateUpdate memory fundingRateConfig) external;

  /// @notice Update the yearly funding rate multiplier for the market
  /// @dev Can only be called by the current admin.
  /// @param stabilityFeeConfig New funding rate multiplier
  function changeStabilityFeeBasisPoints(StabilityFeeUpdate memory stabilityFeeConfig) external;
}

/// @title Interface of read only functions for a market
/// @author float
interface IMarketExtendedView is IMarketCommon {
  /// @notice Whether the minting action is paused or not
  function get_mintingPaused() external view returns (bool);

  /// @notice Whether the market is deprecated or not
  function get_marketDeprecated() external view returns (bool);

  /// @notice Purely a convenience function to get the seeder address. Used in testing.
  function getSeederAddress() external view returns (address);

  /// @notice Purely a convenience function to get the pool token address. Used in testing.
  function getPoolTokenAddress(IMarketCommon.PoolType poolType, uint256 index) external view returns (address);

  /// @notice The largest acceptable percentage that the underlying asset can move in 1 epoch
  function get_maxPercentChange() external view returns (int256);

  /// @notice Admin-adjustable value that determines the magnitude of funding amount each epoch
  function get_fundingRateMultiplier() external view returns (uint256);

  /// @notice Admin-adjustable value that determines the mint fee
  function get_stabilityFee_basisPoints() external view returns (uint256);

  /// @notice Returns batched deposit amount in payment token for even numbered epochs.
  /// @param poolType indicates either Long or Short pool type
  /// @param pool index of the pool on the market side
  function get_even_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256);

  /// @notice Returns batched deposit amount in payment token for odd numbered epochs.
  /// @param poolType indicates either Long or Short pool type
  /// @param pool index of the pool on the market side
  function get_odd_batchedAmountPaymentToken_deposit(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256);

  /// @notice Returns batched redeem amount in pool token for even numbered epochs.
  /// @param poolType indicates either Long or Short pool type
  /// @param pool index of the pool on the market side
  function get_even_batchedAmountPoolToken_redeem(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256);

  /// @notice Returns batched redeem amount in pool token for odd numbered epochs.
  /// @param poolType indicates either Long or Short pool type
  /// @param pool index of the pool on the market side
  function get_odd_batchedAmountPoolToken_redeem(IMarketCommon.PoolType poolType, uint256 pool) external view returns (uint256);

  /// @notice The effective liquidity (actual liquidity * leverage) for all the pools of a specific type
  /// @return The contract stored value for effective liquidity
  function get_effectiveLiquidityForPoolType() external view returns (uint128[2] memory);

  /// @notice View function for the gems state variable
  /// @return address of the gems contract
  function get_gems() external view returns (address);

  /// @notice View function for the registry state variable
  /// @return address of the registry contract
  function get_registry() external view returns (IRegistry);
}

/// @title Combined interface for the admin functions and view functions
/// @author float
interface IMarketExtended is IMarketExtendedCore, IMarketExtendedView {

}
