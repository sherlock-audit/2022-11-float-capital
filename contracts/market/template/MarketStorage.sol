// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import "../../abstract/AccessControlledAndUpgradeable.sol";
import "../../abstract/ProxyNonPayable.sol";

import "../../interfaces/IMarket.sol";
import "../../interfaces/IOracleManager.sol";
import "../../interfaces/IPoolToken.sol";
import "../../interfaces/ILiquidityManager.sol";
import "../../interfaces/IGEMS.sol";

import "../../util/Math.sol";

import "forge-std/console2.sol";

/// @title State variables for the market
/// @author float
contract MarketStorage is IMarketCommon {
  /* ══════ Fixed-precision constants ══════ */
  address constant MARKET_SEEDER_DEAD_ADDRESS = address(420);

  bytes32 internal constant FLOAT_POOL_ROLE = keccak256("FLOAT_POOL_ROLE");

  uint256 constant LONG_TYPE = uint256(PoolType.LONG);
  uint256 constant SHORT_TYPE = uint256(PoolType.SHORT);
  uint256 constant FLOAT_TYPE = uint256(PoolType.FLOAT);
  uint256 constant POOL_TYPE_UPPER_BOUND = uint256(PoolType.LAST);

  /// @dev an empty allocation of storage for use in future upgrades - inspiration from OZ:
  ///      https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/10f0f1a95b1b0fd5520351886bae7a03490f1056/contracts/token/ERC20/ERC20Upgradeable.sol#L361
  uint256[45] private __openingstorageGap;

  /* ══════ Global state ══════ */

  /// @notice Address of the liquidity manager contract
  address internal liquidityManager = address(0);

  /// @notice Oracle manager contract
  IOracleManager internal oracleManager = IOracleManager(address(0));

  /// @notice All info related to the current epoch
  EpochInfo internal epochInfo;

  uint256[45] private __marketStateGap;

  /// @notice Adjustable variable that determines the rate at which traders pay fees to the market makers
  uint256 internal fundingRateMultiplier = 0;

  /// @notice Adjustable value that determines the mint fee
  uint256 internal stabilityFee_basisPoints = 0;

  /// @notice Max percent change in price per epoch where 1e18 is 100% price movement.
  int256 internal maxPercentChange = 0;

  /// @notice True when minting is not allowed in the market
  bool internal mintingPaused = false;

  /// @notice True when the market is deprecated
  bool internal marketDeprecated = false;

  /// @notice first element is for even epochs and second element for odd epochs
  uint256[2] public feesToDistribute;

  /// @notice Effective liquidity for short (0) and long (1) pool types
  uint128[2] effectiveLiquidityForPoolType;

  uint256[45] private __globalStorageGap;

  /* ══════ Pool state ══════ */

  /// @notice Mapping from epoch number -> pooltype -> array of price snapshot
  mapping(uint256 => mapping(IMarketCommon.PoolType => uint256[8])) internal poolToken_priceSnapshot;

  /// @notice Mapping from the type of pool to an array containing the number of pools of that type
  mapping(IMarketCommon.PoolType => IMarketCommon.Pool[8]) internal pools;

  /// @notice Array storing the total number of pools of each type
  uint256[16] internal _numberOfPoolsOfType = [0];

  /// @notice Sum of elements of _numberOfPoolsOfType
  uint256 internal _totalNumberOfPoolTiers = 0;

  uint256[45] private __poolStorageGap;

  /* ══════ User specific ══════ */

  /// @notice User Address => IMarketCommon.PoolType => UserAction Array
  mapping(address => mapping(IMarketCommon.PoolType => IMarketCommon.UserAction[8])) internal userAction_depositPaymentToken;

  /// @notice User Address => IMarketCommon.PoolType => UserAction Array
  mapping(address => mapping(IMarketCommon.PoolType => IMarketCommon.UserAction[8])) internal userAction_redeemPoolToken;

  uint256[45] private __userStorageGap;

  /// @notice Original main contract
  IRegistry internal immutable registry;
  address internal immutable gems;
  address internal immutable paymentToken;

  constructor(address _paymentToken, IRegistry _registry) {
    if (_paymentToken == address(0)) revert InvalidAddress({invalidAddress: _paymentToken});
    if (address(_registry) == address(0)) revert InvalidAddress({invalidAddress: address(_registry)});

    paymentToken = _paymentToken;

    registry = _registry; // original core contract

    gems = _registry.gems();
  }
}

library MarketHelpers {
  /// @notice - this assumes that we will never have more than 16 tier types, and 16 tiers of a given tier type.
  function packPoolId(IMarketCommon.PoolType poolType, uint8 poolTier) internal pure returns (uint8) {
    return (uint8(poolType) << 4) | poolTier;
  }
}
