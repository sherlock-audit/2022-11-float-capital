// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "./MarketStorage.sol";

/// @title Main market contract with all the main functionality
contract MarketCore is AccessControlledAndUpgradeableModifiers, IMarketCommon, IMarketCore, MarketStorage, ProxyNonPayable {
  using SafeERC20 for IERC20;
  using MathUintFloat for uint256;
  using MathIntFloat for int256;

  /*╔═════════════════════════════╗
    ║          MODIFIERS          ║
    ╚═════════════════════════════╝*/

  function gemCollectingModifierLogic(address user) internal {
    IGEMS(gems).gm(user);
  }

  modifier gemCollecting(address user) {
    gemCollectingModifierLogic(user);
    _;
  }

  modifier checkMarketNotDeprecated() {
    if (marketDeprecated) revert MarketDeprecated();
    _;
  }

  /*╔═══════════════════════════════╗
    ║     UPDATING SYSTEM STATE     ║
    ╚═══════════════════════════════╝*/

  /// @notice This calculates the value transfer from the overbalanced to underbalanced side (i.e. the funding rate)
  /// This is a further incentive measure to balanced markets. This may be present on some and not other pool token markets.
  /// @param overbalancedIndex poolType with more liquidity.
  /// @param overbalancedEffectiveValue Side with more liquidity.
  /// @param underbalancedEffectiveValue Side with less liquidity.
  /// @return fundingAmount The amount the overbalanced side needs to pay the underbalanced.
  function _calculateFundingAmount(
    uint256 overbalancedIndex,
    uint256 overbalancedEffectiveValue,
    int256 floatLeverage,
    uint256 underbalancedEffectiveValue
  ) internal view returns (int256[2] memory fundingAmount) {
    uint256 totalUserEffectiveValue = overbalancedEffectiveValue + underbalancedEffectiveValue;

    FundingVariables memory fundingVariablesMem = fundingVariables;
    // NOTE: fundingRateMultiplier is in basis points so need to divide by 10,000, and floatLeverage is in base 1e18 so overall we divide by 1e22.
    uint256 totalFunding = (totalUserEffectiveValue *
      fundingVariablesMem.fundingRateMultiplier *
      Math.max(fundingVariablesMem.minFloatPoolFundingBoost, floatLeverage.abs()) *
      oracleManager.EPOCH_LENGTH()) / (365.25 days * 1e22);

    uint256 overbalancedFunding = Math.min(
      totalFunding,
      (totalFunding * ((2 * overbalancedEffectiveValue) - underbalancedEffectiveValue)) / (totalUserEffectiveValue)
    );
    uint256 underbalancedFunding = totalFunding - overbalancedFunding;

    if (overbalancedIndex == SHORT_TYPE) fundingAmount = [-int256(overbalancedFunding), int256(underbalancedFunding)];
    else fundingAmount = [-int256(underbalancedFunding), int256(overbalancedFunding)];
  }

  function _getValueChangeAndFunding(
    uint256 effectiveValueLong,
    uint256 effectiveValueShort,
    int256 previousPrice,
    int256 currentPrice
  ) internal view returns (int256 floatPoolLeverage, ValueChangeAndFunding memory params) {
    uint256 floatPoolLiquidity = pools[PoolType.FLOAT][0].value;
    // We set the floating tranche leverage to the exact leverage that ensure effectiveValueLong = effectiveValueShort when taking
    //     into the floating liquidity added the underbalanced side.
    floatPoolLeverage = (int256(effectiveValueShort) - int256(effectiveValueLong)).div(int256(floatPoolLiquidity));

    // If there is a large diff between long and short liquidity or little floatPoolLiquidity, then the float pool leverage
    // may be set to a very high amount. Here we cap it such that floatPoolLeverage is between -5x and 5x.
    // This give Market Makers who deposit in the floatPool certain garuntees on the maximum delta they will be exposed to.
    if (floatPoolLeverage > 5e18) floatPoolLeverage = 5e18;
    else if (floatPoolLeverage < -5e18) floatPoolLeverage = -5e18;

    // NOTE - we are dividing by previous price before multiplying this value again in _rebalancePoolsAndExecuteBatchedActions - this means some accuracy is lost - however we deem this insignificant.
    int256 priceMovement_e18 = (currentPrice - previousPrice).div(previousPrice);

    // A really large price movement could bankrupt a 5x leveraged pool. We contrain the price movement to a max percentage
    // that ensure no pool will be underwater. This limimts the gain/loss on any single price movement. In practice
    // maxPercentChange is about 20% for a 5x pool, and we don't expect to see 20% price changes in one epoch, but if we do,
    // The system is able to tolerate it.
    if (priceMovement_e18 > maxPercentChange) priceMovement_e18 = maxPercentChange;
    else if (priceMovement_e18 < -maxPercentChange) priceMovement_e18 = -maxPercentChange;

    // Value change (amount to transfer between Short and Long pools) is based on the price movement multiplied by the
    // Notional value of the smaller side (long or short). Given the float pool should in most cases make the liquidity of long and short
    // exactly equal, the only case where long and short liquidity is different is when the float pool leverage is constrained to its 5x or -5x cap.
    // If this is the case, the side with greater liquidity will have a reduced exposure or delta of their position. I.e. If $1m long and $500k short,
    // Longs will only get 50% ($500k) long exposure.
    if (effectiveValueShort > effectiveValueLong) {
      params.fundingAmount = _calculateFundingAmount(SHORT_TYPE, effectiveValueShort, floatPoolLeverage, effectiveValueLong);
      params.valueChange = priceMovement_e18.mul(int256(effectiveValueLong + uint256(floatPoolLeverage).mul(floatPoolLiquidity)));
      params.underBalancedSide = LONG_TYPE;
    } else {
      params.fundingAmount = _calculateFundingAmount(LONG_TYPE, effectiveValueLong, floatPoolLeverage, effectiveValueShort);
      params.valueChange = priceMovement_e18.mul(int256(effectiveValueShort + uint256(-floatPoolLeverage).mul(floatPoolLiquidity)));
      params.underBalancedSide = SHORT_TYPE;
    }
  }

  /// @notice Reblances the pool given the epoch execution information and can also perform batched actions from the epoch.
  /// @param epochIndex The index of the epoch to execute
  /// @param totalEffectiveLiquidityPoolType Effective liquidity of short (0) and long (1) pools
  /// @param params Compact struct with all parameters needed for rebalance
  /// @return nextTotalEffectiveLiquidityPoolType Updated short and long liquidities
  /// @return poolStates Compact struct of pool states after rebalance
  function _rebalancePoolsAndExecuteBatchedActions(
    uint32 epochIndex,
    uint256[2] memory totalEffectiveLiquidityPoolType,
    int256 floatPoolLeverage,
    ValueChangeAndFunding memory params
  ) internal returns (uint256[2] memory nextTotalEffectiveLiquidityPoolType, PoolState[] memory poolStates) {
    poolStates = new PoolState[](_totalNumberOfPoolTiers);
    uint8 currentPoolStateIndex;

    // Correctly account for liquidity in long and short by adding the float liquidity to the underbalanced side.
    totalEffectiveLiquidityPoolType[params.underBalancedSide] += pools[PoolType.FLOAT][0].value.mul(floatPoolLeverage.abs());

    // For every pool (long pools, short pools and float pool)
    // 1) Adjust poolValue based on price movements and funding (and fees for float pool)
    // 2) Batch process all new entries and exits in pool
    for (uint256 poolType = SHORT_TYPE; poolType < POOL_TYPE_UPPER_BOUND; ++poolType) {
      for (uint256 poolTier = 0; poolTier < _numberOfPoolsOfType[poolType]; ++poolTier) {
        int256 poolValue = int256(pools[PoolType(poolType)][poolTier].value);
        PoolFixedConfig memory poolFixedConfig = pools[PoolType(poolType)][poolTier].fixedConfig;

        if (poolType != FLOAT_TYPE) {
          // To correctly apportion funding owed for the underblananced tiers, we need to remove the float liquidity contribution
          int256 actualTotalEffectiveLiquidityForPoolType = int256(
            (totalEffectiveLiquidityPoolType[poolType] -
              (poolType == params.underBalancedSide ? pools[PoolType.FLOAT][0].value.mul(floatPoolLeverage.abs()) : 0))
          );

          // Long and short pools both pay funding
          poolValue +=
            (((poolValue * poolFixedConfig.leverage * params.valueChange) / int256(totalEffectiveLiquidityPoolType[poolType])) -
              ((poolValue * poolFixedConfig.leverage * params.fundingAmount[poolType]) / (actualTotalEffectiveLiquidityForPoolType))) /
            1e18;
        } else {
          // Float pool recieves all funding and fees.
          poolValue +=
            ((poolValue * floatPoolLeverage * params.valueChange) / (int256(totalEffectiveLiquidityPoolType[params.underBalancedSide]) * 1e18)) +
            -params.fundingAmount[SHORT_TYPE] + // funding value is negative for short side (double negative to add it)
            params.fundingAmount[LONG_TYPE] +
            int256(feesToDistribute[epochIndex & 1]);

          feesToDistribute[epochIndex & 1] = 0;
        }

        uint256 tokenSupply = IPoolToken(poolFixedConfig.token).totalSupply();
        uint256 price = uint256(poolValue).div(tokenSupply);

        // as a precautionary measure - we pause minting immediately in this case.
        if (price < 1e9) mintingPaused = true;

        // All entries and exits to the pool are processed at latest price based on newly calculated poolValue
        poolValue += _processAllBatchedEpochActions(epochIndex, PoolType(poolType), poolTier, price, poolFixedConfig.token);

        // We calculate the new total liquidity always excluding the floating tranche.
        if (poolType != FLOAT_TYPE) nextTotalEffectiveLiquidityPoolType[poolType] += uint256(poolValue).mul(int256(poolFixedConfig.leverage).abs());

        pools[PoolType(poolType)][poolTier].value = uint256(poolValue);

        // Token price snapshot for this epoch is used to calculate amount individual token allocation retrospectively for entrants/exits
        poolToken_priceSnapshot[epochIndex][PoolType(poolType)][poolTier] = price;

        // This structure is purely to emit event info as easily as possible for the indexer.
        poolStates[currentPoolStateIndex++] = PoolState({
          poolId: MarketHelpers.packPoolId(PoolType(poolType), uint8(poolTier)),
          tokenPrice: price,
          value: poolValue
        });
      }
    }
  }

  /// @notice System state update function that verifies (instead of trying to find) oracle prices
  /// @param oracleRoundIdsToExecute The oracle prices that will be the prices for each epoch
  function updateSystemStateUsingValidatedOracleRoundIds(uint80[] memory oracleRoundIdsToExecute) external checkMarketNotDeprecated {
    uint32 latestExecutedEpochIndex = epochInfo.latestExecutedEpochIndex;
    int256[] memory epochPrices = oracleManager.validateAndReturnMissedEpochInformation(latestExecutedEpochIndex, oracleRoundIdsToExecute);

    int256 previousPrice = int256(uint256(epochInfo.lastEpochPrice));

    uint256 numberOfEpochsToExecute = epochPrices.length;

    uint256[2] memory totalEffectiveLiquidityPoolType = effectiveLiquidityForPoolType;

    for (uint256 i = 0; i < numberOfEpochsToExecute; ) {
      /* i is incremented later in scope*/
      (int256 floatPoolLeverage, ValueChangeAndFunding memory rebalanceParams) = _getValueChangeAndFunding(
        totalEffectiveLiquidityPoolType[LONG_TYPE],
        totalEffectiveLiquidityPoolType[SHORT_TYPE],
        // this is the previous execution price, not the previous oracle update price
        previousPrice,
        epochPrices[i]
      );

      previousPrice = epochPrices[i];
      require(previousPrice < type(int128).max, "invalid epoch price");

      PoolState[] memory poolStates;
      (totalEffectiveLiquidityPoolType, poolStates) = _rebalancePoolsAndExecuteBatchedActions(
        latestExecutedEpochIndex + uint32(++i),
        totalEffectiveLiquidityPoolType,
        floatPoolLeverage,
        rebalanceParams
      );

      emit EpochUpdated(latestExecutedEpochIndex + uint32(i), previousPrice, rebalanceParams.valueChange, rebalanceParams.fundingAmount, poolStates);
    }

    // Saving the final state of liquidity and info once all epochs have been executed.
    // In practive, keepers should ensure that the above loop length is only ever 1,
    // and we are never catching up multiple epochs. This arcitecture is built such that the
    // the system can gracefully handle missed upkeep fairly.
    effectiveLiquidityForPoolType = totalEffectiveLiquidityPoolType;
    epochInfo = EpochInfo({
      latestExecutedEpochIndex: latestExecutedEpochIndex + uint32(numberOfEpochsToExecute),
      lastEpochPrice: uint128(int128(previousPrice)),
      latestExecutedOracleRoundId: oracleRoundIdsToExecute[oracleRoundIdsToExecute.length - 1]
    });
  }

  /*╔═══════════════════════════╗
    ║       MINT POSITION       ║
    ╚═══════════════════════════╝*/

  /// @notice Calculates the fees for the mint amount depending on the market
  /// @param amount Amount of payment tokens in that token's lowest denomination for which to mint pool token assets at next price.
  function _calculateStabilityFees(uint256 amount) internal view returns (uint256 amountFees) {
    // stability fee is based on effectiveLiquidity added (takes into account leverage)
    amountFees = (amount * stabilityFee_basisPoints) / (10000);
  }

  /// @notice Allows users to mint pool token assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @dev Called by external functions to mint either long or short. If a user mints multiple times before a price update, these are treated as a single mint.
  /// @dev We have to check minting is not paused.
  /// @param amount Amount of payment tokens in that token's lowest denominationfor which to mint pool token assets at next price.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier leveraged poolTier index
  function _mint(
    uint112 amount,
    address user,
    PoolType poolType,
    uint256 poolTier
  ) internal {
    // ASIDE: This check also checks that the poolType is valid - since if it is invalid it will be zero - and no uint can be less than zero
    if (uint256(poolTier) >= _numberOfPoolsOfType[uint256(poolType)]) revert InvalidPool();

    if (mintingPaused) revert MintingPaused();

    // Due to get amount of payment token calculation we must have amount * 1e18 > poolTokenPriceInPaymentTokens otherwise we get 0
    // In fact, all the decimals of amount * 1e18 that are less than poolTokenPriceInPaymentTokens get cut off
    if (amount < 1e18) revert InvalidActionAmount(amount);

    IERC20(paymentToken).safeTransferFrom(msg.sender, liquidityManager, amount);

    uint256 fees = _calculateStabilityFees(uint256(amount).mul(int256(pools[poolType][poolTier].fixedConfig.leverage).abs()));
    amount -= uint112(fees);

    uint32 currentEpoch = uint32(oracleManager.getCurrentEpochIndex());

    // Actions cannot take place if upkeep has fallen behind and there are already 2 oustanding epochs needing to be executed
    if (currentEpoch > epochInfo.latestExecutedEpochIndex + 2)
      revert MarketStale({currentEpoch: currentEpoch, latestExecutedEpoch: epochInfo.latestExecutedEpochIndex});

    // Before minting we ensure user recieves tokens from any already executed mints in previous epochs.
    // This ensures the userAction_depositPaymentToken[user][poolType][poolTier] struct will be up to date
    // and correctly handle to new mint.
    settlePoolUserMints(user, poolType, poolTier);

    UserAction memory userAction = userAction_depositPaymentToken[user][poolType][poolTier];

    /// NOTE: userAction.amount > 0 IFF userAction.correspondingEpoch <= currentEpoch - this check is redundant for safety.
    if (userAction.amount > 0 && userAction.correspondingEpoch < currentEpoch) {
      // This case occurs when a user minted in the previous epoch and upkeep has still not yet
      // occured and therefore this previous order has not been processed.
      // This is likely to happen if the user mints early on in a new epoch when enough time has not
      // passed (see MEWT) for the previous epoch to be executed.
      userAction.nextEpochAmount += amount;
    } else {
      userAction.amount += amount;
      userAction.correspondingEpoch = currentEpoch;
    }

    // NOTE: `currentEpoch & 1` and `currentEpoch % 2` are equivalent, but the former is more efficient using bitwise operations.
    // Since there can only ever be oustanding mint and redeem orders in two consecutive epochs (cannot have oustanding orders in 3 epochs etc)
    // We use an odd even batch scheme to easily batch orders.
    pools[poolType][poolTier].batchedAmount[currentEpoch & 1].paymentToken_deposit += amount;
    feesToDistribute[currentEpoch & 1] += fees;

    userAction_depositPaymentToken[user][poolType][poolTier] = userAction;

    emit Deposit(MarketHelpers.packPoolId(poolType, uint8(poolTier)), amount, fees, user, currentEpoch);
  }

  /// @notice Allows users to mint long pool token assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @param poolTier leveraged poolTier index
  /// @param amount Amount of payment tokens in that token's lowest denomination for which to mint pool token assets at next price.
  function mintLong(uint256 poolTier, uint112 amount) external gemCollecting(msg.sender) {
    _mint(amount, msg.sender, PoolType.LONG, poolTier);
  }

  /// @notice Allows users to mint short pool token assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @param poolTier leveraged poolTier index
  /// @param amount Amount of payment tokens in that token's lowest denomination for which to mint pool token assets at next price.
  function mintShort(uint256 poolTier, uint112 amount) external gemCollecting(msg.sender) {
    _mint(amount, msg.sender, PoolType.SHORT, poolTier);
  }

  /// @notice Allows users to mint float pool token assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @param amount Amount of payment tokens in that token's lowest denomination for which to mint pool token assets at next price.
  function mintFloatPool(uint112 amount) external {
    _checkRole(FLOAT_POOL_ROLE, msg.sender);
    _mint(amount, msg.sender, PoolType.FLOAT, 0); // There is always only one float pool at poolTier index 0
  }

  /// @notice Allows mint long pool token assets for a market on behalf of some user. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @param poolTier leveraged poolTier index
  /// @param amount Amount of payment tokens in that token's lowest denomination for which to mint pool token assets at next price.
  /// @param user Address of the user.
  function mintLongFor(
    uint256 poolTier,
    uint112 amount,
    address user
  ) external override gemCollecting(user) {
    _mint(amount, user, PoolType.LONG, poolTier);
  }

  /// @notice Allows mint short pool token assets for a market on behalf of some user. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @param poolTier leveraged poolTier index
  /// @param amount Amount of payment tokens in that token's lowest denomination for which to mint pool token assets at next price.
  /// @param user Address of the user.
  function mintShortFor(
    uint256 poolTier,
    uint112 amount,
    address user
  ) external gemCollecting(user) {
    _mint(amount, user, PoolType.SHORT, poolTier);
  }

  /*╔═══════════════════════════╗
    ║       REDEEM POSITION     ║
    ╚═══════════════════════════╝*/

  /// @notice Allows users to mint pool token assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @dev Called by external functions to mint either long or short. If a user mints multiple times before a price update, these are treated as a single mint.
  /// @dev We have to check market is not deprecated.
  /// @param amount Amount of payment tokens in that token's lowest denominationfor which to mint pool token assets at next price.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier leveraged poolTier index
  function _redeem(
    uint112 amount,
    address user,
    PoolType poolType,
    uint256 poolTier
  ) internal checkMarketNotDeprecated {
    // In this function, amount refers to the amount of poolToken.
    // In the _mint function amount refers to the amount of paymentToken
    // This function is very similar to _mint. See _mint for comprehensive commenting
    if (amount < 1e12) revert InvalidActionAmount(amount);

    uint32 currentEpoch = uint32(oracleManager.getCurrentEpochIndex());
    if (currentEpoch > epochInfo.latestExecutedEpochIndex + 2)
      revert MarketStale({currentEpoch: currentEpoch, latestExecutedEpoch: epochInfo.latestExecutedEpochIndex});

    settlePoolUserRedeems(user, poolType, poolTier);

    //slither-disable-next-line unchecked-transfer
    // If an invalid poolType and poolTier is passed, this will revert.
    IPoolToken(pools[poolType][poolTier].fixedConfig.token).transferFrom(user, address(this), amount);

    UserAction memory userAction = userAction_redeemPoolToken[user][poolType][poolTier];

    if (userAction.amount > 0 && userAction.correspondingEpoch < currentEpoch) {
      userAction.nextEpochAmount += amount;
    } else {
      userAction.amount += amount;
      userAction.correspondingEpoch = currentEpoch;
    }

    // NOTE: `currentEpoch & 1` and `currentEpoch % 2` are equivalent, but the former is more efficient using bitwise operations.
    pools[poolType][poolTier].batchedAmount[currentEpoch & 1].poolToken_redeem += amount;

    userAction_redeemPoolToken[user][poolType][poolTier] = userAction;

    emit Redeem(MarketHelpers.packPoolId(poolType, uint8(poolTier)), amount, user, currentEpoch);
  }

  /// @notice Allows users to mint long pool token assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @param poolTier leveraged poolTier index
  /// @param amount Amount of payment tokens in that token's lowest denominationfor which to mint pool token assets at next price.
  function redeemLong(uint256 poolTier, uint112 amount) external gemCollecting(msg.sender) {
    _redeem(amount, msg.sender, PoolType.LONG, poolTier);
  }

  /// @notice Allows users to redeem short pool token assets for a market. To prevent front-running these redeems are executed on the next price update from the oracle.
  /// @param poolTier leveraged poolTier index
  /// @param amount Amount of payment tokens in that token's lowest denominationfor which to redeem pool token assets at next price.
  function redeemShort(uint256 poolTier, uint112 amount) external gemCollecting(msg.sender) {
    _redeem(amount, msg.sender, PoolType.SHORT, poolTier);
  }

  /// @notice Allows users to redeem float pool token assets for a market. To prevent front-running these redeems are executed on the next price update from the oracle.
  /// @param amount Amount of payment tokens in that token's lowest denominationfor which to redeem pool token assets at next price.
  function redeemFloatPool(uint112 amount) external {
    _redeem(amount, msg.sender, PoolType.FLOAT, 0);
  }

  /*╔═════════════════════╗
    ║  USER SETTLEMENTS   ║
    ╚═════════════════════╝*/

  /// @notice After markets have been batched updated on a new oracle price, transfers any owed tokens to a user from their mints during that epoch to that user.
  /// @param user Address of the user.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier leveraged poolTier index
  function settlePoolUserMints(
    address user,
    PoolType poolType,
    uint256 poolTier
  ) public {
    /*
      NOTE: please reflect any changes made to this function to the `getUsersConfirmedButNotSettledPoolTokenBalance` function too.

     Users can have mints in two consecutive epochs (with both not yet being executed). In this case we say both there primary,
     and seconday order slot are full. Once upkeep has been performed on those epochs, this function can be called at a later stage,
     asynchronusly (generally when a user mints again or uses their tokens), in order to calculate and send the tokens owed to the user
     based on their mints in the primiary and secondary slot (the secondary slot may not always exist).

     Corresponding epoch refers to the epoch associated with the primary slot action.
    */

    UserAction memory userAction = userAction_depositPaymentToken[user][poolType][poolTier];

    // Case if the primary order can be executed.
    if (userAction.correspondingEpoch != 0 && userAction.correspondingEpoch <= epochInfo.latestExecutedEpochIndex) {
      uint256 poolToken_price = poolToken_priceSnapshot[userAction.correspondingEpoch][poolType][poolTier];
      uint256 amountPoolTokenToMint = uint256(userAction.amount).div(poolToken_price);

      // If secondary order exists
      if (userAction.nextEpochAmount > 0) {
        uint32 secondaryOrderEpoch = userAction.correspondingEpoch + 1;

        // If its possible to also execute the secondary order slot
        if (secondaryOrderEpoch <= epochInfo.latestExecutedEpochIndex) {
          // then also execute
          poolToken_price = poolToken_priceSnapshot[secondaryOrderEpoch][poolType][poolTier];
          amountPoolTokenToMint += uint256(userAction.nextEpochAmount).div(poolToken_price);

          userAction.amount = 0;
          userAction.correspondingEpoch = 0;
        } else {
          // If secondary order cannot be executed, bump it to the primary slot.
          userAction.amount = userAction.nextEpochAmount;
          userAction.correspondingEpoch = secondaryOrderEpoch;
        }
        // has to zero as either executed or bumped to primary slot
        userAction.nextEpochAmount = 0;
      } else {
        // If user has no pending mints then simply wipe
        userAction.amount = 0;
        userAction.correspondingEpoch = 0;
      }

      //slither-disable-next-line unchecked-transfer
      IPoolToken(pools[poolType][poolTier].fixedConfig.token).transfer(user, amountPoolTokenToMint);

      userAction_depositPaymentToken[user][poolType][poolTier] = userAction;

      emit ExecuteEpochSettlementMintUser(
        MarketHelpers.packPoolId(poolType, uint8(poolTier)),
        user,
        epochInfo.latestExecutedEpochIndex,
        amountPoolTokenToMint
      );
    }
  }

  /// @notice After markets have been batched updated on a new oracle price, transfers any owed tokens to a user from their redeems during that epoch to that user.
  /// @param user Address of the user.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier leveraged poolTier index
  function settlePoolUserRedeems(
    address user,
    PoolType poolType,
    uint256 poolTier
  ) public {
    // Functions almost identically to settlePoolUserMints. See settlePoolUserMints for comprehensive comments.
    UserAction memory userAction = userAction_redeemPoolToken[user][poolType][poolTier];

    // Case if the primary order can be executed.
    if (userAction.amount > 0 && userAction.correspondingEpoch <= epochInfo.latestExecutedEpochIndex) {
      uint256 poolToken_price = poolToken_priceSnapshot[userAction.correspondingEpoch][poolType][poolTier];

      uint256 amountPaymentTokenToSend = uint256(userAction.amount).mul(poolToken_price);

      if (userAction.nextEpochAmount > 0) {
        uint32 secondaryOrderEpoch = userAction.correspondingEpoch + 1;

        if (secondaryOrderEpoch <= epochInfo.latestExecutedEpochIndex) {
          poolToken_price = poolToken_priceSnapshot[secondaryOrderEpoch][poolType][poolTier];
          amountPaymentTokenToSend += uint256(userAction.nextEpochAmount).mul(poolToken_price);

          userAction.amount = 0;
          userAction.correspondingEpoch = 0;
        } else {
          userAction.amount = userAction.nextEpochAmount;
          userAction.correspondingEpoch = secondaryOrderEpoch;
        }
        // has to zero as either executed or bumped to primary slot
        userAction.nextEpochAmount = 0;
      } else {
        // If user has no pending redeems then simply wipe
        userAction.amount = 0;
        userAction.correspondingEpoch = 0;
      }

      userAction_redeemPoolToken[user][poolType][poolTier] = userAction;

      ILiquidityManager(liquidityManager).transferPaymentTokensToUser(user, amountPaymentTokenToSend);

      emit ExecuteEpochSettlementRedeemUser(
        MarketHelpers.packPoolId(poolType, uint8(poolTier)),
        user,
        epochInfo.latestExecutedEpochIndex,
        amountPaymentTokenToSend
      );
    }
  }

  /*╔═══════════════════╗
    ║   BATCH ACTIONS   ║
    ╚═══════════════════╝*/

  /// @notice Either mints or burns pool token supply.
  /// @param poolToken Address of the pool token.
  /// @param changeInPoolTokensTotalSupply Positive indicates amount to be minted and negative indicates amount to be burned.
  function _handleChangeInPoolTokensTotalSupply(address poolToken, int256 changeInPoolTokensTotalSupply) internal {
    if (changeInPoolTokensTotalSupply > 0) {
      IPoolToken(poolToken).mint(address(this), uint256(changeInPoolTokensTotalSupply));
    } else if (changeInPoolTokensTotalSupply < 0) {
      IPoolToken(poolToken).burn(uint256(-changeInPoolTokensTotalSupply));
    }
  }

  /// @notice For a given pool, updates the value depending on the batched deposits and redeems that took place during the epoch
  /// @param associatedEpochIndex Index of epoch where the batched actions were performed.
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  /// @param poolTier leveraged poolTier index.
  /// @param price Price of the pool token.
  function _processAllBatchedEpochActions(
    uint256 associatedEpochIndex,
    PoolType poolType,
    uint256 poolTier,
    uint256 price,
    address poolToken
  ) internal returns (int256 changeInMarketValue_inPaymentToken) {
    // QUESTION: is it worth the gas saving this storage pointer - we only use 'pool' twice in this function.
    Pool storage pool = pools[poolType][poolTier];

    BatchedActions memory batch = pool.batchedAmount[associatedEpochIndex & 1];

    // Only if mints or redeems exist is it necessary to adjust supply and collateral.
    if (batch.paymentToken_deposit > 0 || batch.poolToken_redeem > 0) {
      changeInMarketValue_inPaymentToken = int256(batch.paymentToken_deposit) - int256(uint256(batch.poolToken_redeem).mul(price));

      int256 changeInSupply_poolToken = int256(uint256(batch.paymentToken_deposit).div(price)) - int256(batch.poolToken_redeem);

      pool.batchedAmount[associatedEpochIndex & 1] = BatchedActions(0, 0);

      _handleChangeInPoolTokensTotalSupply(poolToken, changeInSupply_poolToken);
    }
  }

  /*╔═══════════════════════════╗
    ║ DEPRECATED MARKET ACTIONS ║
    ╚═══════════════════════════╝*/

  /*
  In the case that upkeep contiously fails (could be because of chainlink failing, the chain going offline etc.),
  which will most likely happen if no chainlink price is recieved within an epoch, therefore no valid price is available
  to execute and process all oustanding orders and value transfer - The markets gracefully go into a state of deprecation. 
  When this happens, all normal mints and redeems are suspended. It is only possible to burn all poolTokens and redeem collateral. 
  The tokens will no longer change value according any price feed, or pay funding etc, the token price will simply stay constant.
  This seems the safest way to handle a blackswan event. That being said EPOCH_LENGTH will be set to ensure its highly unlikely
  price events don't ocur during an epoch.
  */

  /// @notice Place the market in a state where no more price updates or mints are allowed
  function _deprecateMarket() internal checkMarketNotDeprecated {
    ValueChangeAndFunding memory emptyValueChangeAndFunding;

    uint256[2] memory newEffectiveLiquidity = effectiveLiquidityForPoolType;

    // Here we rebalance the market twice with zero price change (so the pool tokens don't change price) but all outstanding
    for (uint32 i = 1; i <= 2; i++)
      (newEffectiveLiquidity, ) = _rebalancePoolsAndExecuteBatchedActions(
        epochInfo.latestExecutedEpochIndex + i,
        newEffectiveLiquidity,
        0,
        emptyValueChangeAndFunding
      );

    effectiveLiquidityForPoolType = newEffectiveLiquidity;
    epochInfo.latestExecutedEpochIndex += 2;
    marketDeprecated = true;
    mintingPaused = true;
    emit MarketDeprecation();
  }

  /// @notice This function will auto-deprecate the market if there are no updates for more than 10 days.
  /// @dev 10 days should be enough time for the team to make an informed decision on how to handle this error.
  function deprecateMarketNoOracleUpdates() external {
    require(((oracleManager.getCurrentEpochIndex() - epochInfo.latestExecutedEpochIndex) * oracleManager.EPOCH_LENGTH()) > 10 days);

    _deprecateMarket();
  }

  /// @notice Place the market in a state where no more price updates or mints are allowed
  function deprecateMarket() external emergencyMitigationOnly {
    _deprecateMarket();
  }

  /// @notice Allows users to exit the market after it has been deprecated
  /// @param user Users address to remove from the market
  /// @param poolType an enum representing the type of poolTier for eg. LONG or SHORT.
  function _exitDeprecatedMarket(address user, PoolType poolType) internal {
    // NOTE we don't want the seeder to redeem because it could lead to division by 0 when the last person exits
    require(user != address(0) && user != MARKET_SEEDER_DEAD_ADDRESS, "User can't be 0 or seeder");

    uint256 maxPoolIndex = _numberOfPoolsOfType[uint256(poolType)];
    for (uint8 poolIndex = 0; poolIndex < maxPoolIndex; ++poolIndex) {
      // execute all outstanding mint&redeems that were made before deprecation
      settlePoolUserMints(user, poolType, poolIndex);
      settlePoolUserRedeems(user, poolType, poolIndex);

      // redeem all user's pool tokens
      IPoolToken poolToken = IPoolToken(pools[poolType][poolIndex].fixedConfig.token);
      uint256 balance = poolToken.balanceOf(user);
      if (balance > 0) {
        //slither-disable-next-line unchecked-transfer
        poolToken.transferFrom(user, address(this), balance);
        poolToken.burn(balance);

        uint256 amount = balance.mul(poolToken_priceSnapshot[epochInfo.latestExecutedEpochIndex][poolType][poolIndex]);
        ILiquidityManager(liquidityManager).transferPaymentTokensToUser(user, amount);
      }
    }
  }

  /// @notice Allows users to exit the market after it has been deprecated
  /// @param user Users address to remove from the market
  function exitDeprecatedMarket(address user) external {
    // NOTE we check market deprecation after updating system state 'cause it may be that this
    //  particular update is the one that deprecates the market
    require(marketDeprecated, "Market is not deprecated");

    _exitDeprecatedMarket(user, PoolType.SHORT);
    _exitDeprecatedMarket(user, PoolType.LONG);
    _exitDeprecatedMarket(user, PoolType.FLOAT);
  }

  IMarketExtended public immutable nonCoreFunctionsDelegatee;

  constructor(
    IMarketExtended nonCoreFunctionsDelegateeContract,
    address paymentToken,
    IRegistry registry
  ) initializer MarketStorage(paymentToken, registry) {
    require(address(nonCoreFunctionsDelegateeContract) != address(0));
    nonCoreFunctionsDelegatee = nonCoreFunctionsDelegateeContract;

    // Add this so that this contract can be detected as a proxy by things such as etherscan.
    StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = address(nonCoreFunctionsDelegatee);

    require(registry == nonCoreFunctionsDelegatee.get_registry());
  }

  /// @dev Required to delegate non-core-function calls to the MarketExtended contract using the OpenZeppelin proxy.
  function _implementation() internal view override returns (address) {
    return address(nonCoreFunctionsDelegatee);
  }
}
