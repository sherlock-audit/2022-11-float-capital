// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "./MarketStorage.sol";

/// @title Extended (not often used) functions for market
/// @author float
/// @dev This contract is contains a set of non-core functions for the MarketCore contract that are not important enough to be included in the core contract.
contract MarketExtendedCore is AccessControlledAndUpgradeableModifiers, MarketStorage, IMarketExtendedCore {
  using SafeERC20 for IERC20;

  uint256 public immutable initialPoolTokenPrice;

  constructor(
    address _paymentToken,
    IRegistry _registry,
    uint256 _initialPoolTokenPrice
  ) initializer MarketStorage(_paymentToken, _registry) {
    require(_initialPoolTokenPrice >= 1e18 && _initialPoolTokenPrice < 1e22, "bad initial price");
    initialPoolTokenPrice = _initialPoolTokenPrice;
  }

  /*╔═══════════════════════╗
    ║       INITIALIZE      ║
    ╚═══════════════════════╝*/

  /// @notice Initialize pools in the market
  /// @dev Can only be called by registry contract
  /// @param params struct containing addresses of dependency contracts and other market initialization parameters
  /// @return initializationSuccess bool value indicating whether initialization was successful.
  function initializePools(InitializePoolsParams memory params) external override initializer returns (bool initializationSuccess) {
    require(msg.sender == address(registry), "Not registry");
    require(params.seederAndAdmin != address(0) && params.oracleManager != address(0) && params.liquidityManager != address(0));
    // The below function ensures that this contract can't be re-initialized!
    _AccessControlledAndUpgradeable_init(params.seederAndAdmin);

    _setupRole(FLOAT_POOL_ROLE, params.seederAndAdmin);
    _setRoleAdmin(FLOAT_POOL_ROLE, ADMIN_ROLE);

    oracleManager = IOracleManager(params.oracleManager);
    liquidityManager = params.liquidityManager;

    epochInfo.latestExecutedEpochIndex = uint32(oracleManager.getCurrentEpochIndex() - 1);

    (uint80 latestRoundId, int256 initialAssetPrice, , , ) = oracleManager.chainlinkOracle().latestRoundData();
    epochInfo.latestExecutedOracleRoundId = latestRoundId;
    require(uint256(initialAssetPrice) < type(uint128).max); // Be double sure the chainlink price isn't broken
    epochInfo.lastEpochPrice = uint128(uint256(initialAssetPrice));

    // Ie default max percentage change is 19.99% (for the 5x FLOAT tier)
    // given general deviation threshold of 0.5% for most oracle price feeds
    // price movements greater than 20% are extremely unlikely and so maintaining a hard cap of 19.99% on price changes is reasonable.
    // We start this value at 99% as the max change, but it gets reduced when pools with higher leverage are added.
    maxPercentChange = 0.99e18;

    emit SeparateMarketLaunchedAndSeeded(
      params._marketIndex,
      params.seederAndAdmin,
      address(oracleManager),
      liquidityManager,
      paymentToken,
      initialAssetPrice
    );

    // NOTE: The first pool HAS to be the 1 and only FLOAT pool - otherwise initializer will fail!
    for (uint256 i = 0; i < params.initPools.length; i++) {
      _addPoolToExistingMarket(params.initPools[i], params.initialLiquidityToSeedEachPool, params.seederAndAdmin, params._marketIndex);
    }

    // Return true to drastically reduce chance of making mistakes with this.
    initializationSuccess = true;
  }

  /*╔═══════════════════╗
    ║       ADMIN       ║
    ╚═══════════════════╝*/

  /// @notice Update oracle for a market
  /// @dev Can only be called by the current admin (not MINOR_ADMIN_ROLE - more strict since more sensitive).
  /// @param oracleConfig Address of the replacement oracle manager.
  function updateMarketOracle(OracleUpdate memory oracleConfig) external adminOnly {
    // NOTE: we could also upgrade this contract to reference the new oracle potentially and have it as immutable
    // If not a oracle contract this would break things.. Test's arn't validating this
    // Ie require isOracle interface - ERC165

    // This check helps make sure that config changes are deliberate.
    require(oracleConfig.prevOracle == oracleManager, "Incorrect prev oracle");

    oracleManager = oracleConfig.newOracle;
    emit ConfigChange(ConfigType.marketOracleUpdate, abi.encode(oracleConfig));
  }

  /// @notice Update the yearly funding rate multiplier for the market
  /// @dev Can only be called by the current MINOR_ADMIN_ROLE.
  /// @param fundingRateConfig New funding rate multiplier
  function changeMarketFundingRateMultiplier(FundingRateUpdate memory fundingRateConfig) external minorAdminOnly {
    // Funding multiplier quoted in basis points
    require(fundingRateConfig.newMultiplier <= 10000, "funding rate must be <= 100%");
    require(
      5e17 <= fundingRateConfig.newMinFloatPoolFundingBoost && fundingRateConfig.newMinFloatPoolFundingBoost <= 2e18,
      "Min boost out of bounds"
    );

    // This check helps make sure that config changes are deliberate.
    require(fundingRateConfig.prevMultiplier == fundingVariables.fundingRateMultiplier, "Incorrect prev mult value");
    require(fundingRateConfig.prevMinFloatPoolFundingBoost == fundingVariables.minFloatPoolFundingBoost, "Incorrect prev min value");

    fundingVariables.fundingRateMultiplier = fundingRateConfig.newMultiplier;
    fundingVariables.minFloatPoolFundingBoost = fundingRateConfig.newMinFloatPoolFundingBoost;
    emit ConfigChange(ConfigType.fundingVariables, abi.encode(fundingRateConfig));
  }

  /// @notice Update the yearly stability fee for the market
  /// @dev Can only be called by the current MINOR_ADMIN_ROLE.
  /// @param stabilityFeeConfig New stability fee multiplier
  function changeStabilityFeeBasisPoints(StabilityFeeUpdate memory stabilityFeeConfig) external minorAdminOnly {
    require(stabilityFeeConfig.newStabilityFee <= 500, "stability fee must be <= 5%");

    // This check helps make sure that config changes are deliberate.
    require(stabilityFeeConfig.prevStabilityFee == stabilityFee_basisPoints, "Incorrect prev value");

    stabilityFee_basisPoints = stabilityFeeConfig.newStabilityFee;
    emit ConfigChange(ConfigType.stabilityFee, abi.encode(stabilityFeeConfig));
  }

  /// @notice Add a pool to an existing market.
  /// @dev Can only be called by the current admin.
  /// @param initPool initialization info for the new pool
  /// @param initialActualLiquidityForNewPool initial effective liquidity to be added to new pool at initialization
  /// @param seederAndAdmin address of pool seeder and admin
  /// @param _marketIndex index of the market
  //slither-disable-next-line costly-operations-inside-a-loop
  function _addPoolToExistingMarket(
    SinglePoolInitInfo memory initPool,
    uint256 initialActualLiquidityForNewPool,
    address seederAndAdmin,
    uint32 _marketIndex
  ) internal {
    require(seederAndAdmin != address(0), "Invalid seederAndAdmin can't be zero");
    // You require at least 1e12 (1 payment token with 12 decimal places) of the underlying payment token to seed the market.
    require(initialActualLiquidityForNewPool >= 1e12, "Insufficient market seed");
    require(
      _numberOfPoolsOfType[uint256(initPool.poolType)] < 8 &&
        initPool.token != address(0) &&
        initPool.poolType < PoolType.LAST &&
        (initPool.leverage >= 1e18 && initPool.leverage <= 10e18),
      "Invalid pool params"
    );

    SinglePoolInitInfo memory poolInfo = initPool;
    uint256 tierPriceMovementThresholdAbsolute = PoolType.FLOAT == initPool.poolType ? 0.19e18 : (1e36 / poolInfo.leverage) - 1e16;

    maxPercentChange = int256(Math.min(uint256(maxPercentChange), tierPriceMovementThresholdAbsolute));

    IPoolToken(initPool.token).initialize(initPool, seederAndAdmin, _marketIndex, uint8(_numberOfPoolsOfType[uint256(initPool.poolType)]));

    IPoolToken(initPool.token).mint(MARKET_SEEDER_DEAD_ADDRESS, MathUintFloat.div(initialActualLiquidityForNewPool, initialPoolTokenPrice));

    Pool storage pool = pools[initPool.poolType][_numberOfPoolsOfType[uint256(initPool.poolType)]];

    pool.fixedConfig = PoolFixedConfig(initPool.token, (initPool.poolType == PoolType.SHORT ? -int96(initPool.leverage) : int96(initPool.leverage)));
    pool.value = initialActualLiquidityForNewPool;

    require(_numberOfPoolsOfType[uint256(initPool.poolType)]++ == poolInfo.poolTier, "incorrect pool tier");
    ++_totalNumberOfPoolTiers;

    emit TierAdded(poolInfo, initialActualLiquidityForNewPool);

    IERC20(paymentToken).safeTransferFrom(seederAndAdmin, liquidityManager, initialActualLiquidityForNewPool);

    if (initPool.poolType != PoolType.FLOAT)
      effectiveLiquidityForPoolType[uint256(initPool.poolType)] += uint128(MathUintFloat.mul(initialActualLiquidityForNewPool, initPool.leverage));

    require(_numberOfPoolsOfType[FLOAT_TYPE] == 1, "Must be exactly 1 float pool");
  }

  /// @notice Add a pool to an existing market.
  /// @dev Can only be called by the current admin.
  /// @param initPool initialization info for the new pool
  /// @param initialActualLiquidityForNewPool initial effective liquidity to be added to new pool at initialization
  /// @param seederAndAdmin address of pool seeder and admin
  /// @param _marketIndex index of the market
  function addPoolToExistingMarket(
    SinglePoolInitInfo memory initPool,
    uint256 initialActualLiquidityForNewPool,
    address seederAndAdmin,
    uint32 _marketIndex
  ) external adminOnly {
    require(!marketDeprecated && !mintingPaused, "can't add pool to when paused/deprecated");
    _addPoolToExistingMarket(initPool, initialActualLiquidityForNewPool, seederAndAdmin, _marketIndex);
  }

  /// @notice Stop allowing mints on the market
  /// @dev Can only be called by the current admin.
  function pauseMinting() external emergencyMitigationOnly {
    mintingPaused = true;
    emit MintingPauseChange(mintingPaused);
  }

  /// @notice Resume allowing mints on the market
  /// @dev Can only be called by the current admin.
  function unpauseMinting() external emergencyMitigationOnly {
    // It is important you cannot unpause a deprecated market because that will create inconsistent state (ie a half deprecated market where minting is possible)
    require(!marketDeprecated, "can't unpause deprecated market");
    mintingPaused = false;
    emit MintingPauseChange(mintingPaused);
  }
}
