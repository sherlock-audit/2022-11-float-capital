// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../market/template/inconsequentialViewFunctions/MarketWithAdditionalViewFunctions.sol";
import "../mocks/ERC20Mock.sol";

import "../keepers/OracleManagerUtils.sol";

import "forge-std/console2.sol";

/*
NOTE: This contract is for testing purposes only!
*/

contract MarketTieredLeverageInternalStateSetters is Market {
  constructor(
    IMarketExtended nonCoreFunctionsDelegatee,
    address paymentToken,
    IRegistry registry
  ) Market(nonCoreFunctionsDelegatee, paymentToken, registry) {}

  // NOTE: this function isn't being used currently.
  //       BUT - I think it will be very useful for some types of fuzzing.
  //       Outline: we could specify acceptable starting states - and then fuzz the state transitions.
  //                all state transitions we can think of should move the code to another valid state.
  function setEpochState(uint80 latestExecutedOracleRoundId, int256[2][8] memory tokenPrices) external {
    // defaultMarket
    uint32 currentEpochIndex = uint32(oracleManager.getCurrentEpochIndex());

    int256 changeInContractValue = 0;

    for (uint8 poolType = uint8(IMarketCommon.PoolType.SHORT); poolType <= uint8(IMarketCommon.PoolType.LONG); poolType++) {
      for (uint256 i = 0; i < _numberOfPoolsOfType[poolType]; ++i) {
        IMarketCommon.Pool storage pool = pools[IMarketCommon.PoolType(poolType)][i];
        int256 desiredPrice = tokenPrices[poolType][i];
        assert(desiredPrice > 10000); // Make sure this value isn't too low
        uint256 totalSupply = IPoolToken(pool.fixedConfig.token).totalSupply();
        uint256 desiredTierValue = (totalSupply * uint256(desiredPrice)) / 1e18;
        pool.value = desiredTierValue;

        changeInContractValue += int256(desiredTierValue) - int256(pool.value);
      }
    }

    if (changeInContractValue > 0) {
      // We need to increase the amount of paymentToken in the contract
      PaymentTokenTestnet(paymentToken).mint(uint256(changeInContractValue));
      PaymentTokenTestnet(paymentToken).transfer(liquidityManager, uint256(changeInContractValue));
    } else if (changeInContractValue < 0) {
      // We need to decrease the amount of paymentToken in the contract
      ILiquidityManager(liquidityManager).transferPaymentTokensToUser(
        address(9876543216654), /* Some random address */
        uint256(-changeInContractValue)
      );
    }

    epochInfo.latestExecutedEpochIndex = currentEpochIndex - 1;
    epochInfo.latestExecutedOracleRoundId = latestExecutedOracleRoundId;
  }

  function giveUserTokens(
    IMarketCommon.PoolType poolType,
    uint256 poolIndex,
    address user,
    uint256 amountOfPoolToken
  ) external {
    IMarketCommon.Pool storage pool = pools[poolType][poolIndex];
    uint256 totalSupply = IPoolToken(pool.fixedConfig.token).totalSupply();
    uint256 poolTokenPrice = (totalSupply * 1e18) / pool.value;
    uint256 usersCurrentAmountPoolToken = IERC20(pool.fixedConfig.token).balanceOf(user);

    // Can't reduce the amount of pool tokens that the user has
    assert(usersCurrentAmountPoolToken < amountOfPoolToken);

    uint256 amountOfPoolTokenToMintForUser = amountOfPoolToken - usersCurrentAmountPoolToken;
    IPoolToken(pool.fixedConfig.token).mint(user, amountOfPoolTokenToMintForUser);

    uint256 amountOfPaymentTokenToMintForPool = (amountOfPoolTokenToMintForUser * poolTokenPrice) / 1e18;

    PaymentTokenTestnet(paymentToken).mint(uint256(amountOfPaymentTokenToMintForPool));

    PaymentTokenTestnet(paymentToken).transfer(liquidityManager, uint256(amountOfPaymentTokenToMintForPool));

    require(amountOfPoolToken == IERC20(pool.fixedConfig.token).balanceOf(user), "Amount of PoolToken user has is incorrect");

    uint256 tokenPriceBefore = (pool.value * 1e18) / totalSupply;

    pool.value += amountOfPaymentTokenToMintForPool;

    uint256 tokenPriceAfter = (pool.value * 1e18) / IPoolToken(pool.fixedConfig.token).totalSupply();

    require(tokenPriceBefore == tokenPriceAfter, "token price shouldn't change");
  }

  function givePoolsCorrectAmountOfLiquidity(
    uint256[3][8] memory tokenTypeLiquidity // uint256[8] memory shortTokenLiquidity
  ) external {
    address extraLiquidityHolder = MARKET_SEEDER_DEAD_ADDRESS;
    for (uint8 poolType = 0; poolType <= uint8(IMarketCommon.PoolType.FLOAT); ++poolType) {
      IMarketCommon.PoolType currentPoolType = IMarketCommon.PoolType(poolType);
      uint256 numberOfMarkets = _numberOfPoolsOfType[poolType];
      for (uint256 poolTier = 0; poolTier < numberOfMarkets; ++poolTier) {
        // NOTE: using storage here for convenience (not gas efficiency ;)
        IMarketCommon.Pool storage pool = pools[currentPoolType][poolTier];
        uint256 totalSupply = IPoolToken(pool.fixedConfig.token).totalSupply();

        uint256 tokenPrice = (pool.value * 1e18) / totalSupply;

        if (totalSupply == tokenTypeLiquidity[poolType][poolTier]) {
          // NOthing to do
        } else if (totalSupply < tokenTypeLiquidity[poolType][poolTier]) {
          uint256 amountOfPoolTokenToMintForUser = tokenTypeLiquidity[poolType][poolTier] - totalSupply;
          IPoolToken(pool.fixedConfig.token).mint(extraLiquidityHolder, amountOfPoolTokenToMintForUser);

          uint256 amountOfPaymentTokenToMintForPool = (amountOfPoolTokenToMintForUser * tokenPrice) / 1e18;
          PaymentTokenTestnet(paymentToken).mint((amountOfPaymentTokenToMintForPool));
          PaymentTokenTestnet(paymentToken).transfer(liquidityManager, amountOfPaymentTokenToMintForPool);
          pool.value += amountOfPaymentTokenToMintForPool;
        } else {
          uint256 additionalLiquidityHolderBalance = IERC20(pool.fixedConfig.token).balanceOf(extraLiquidityHolder);
          uint256 amountOfPoolTokenToBurn = totalSupply - tokenTypeLiquidity[poolType][poolTier];
          require(additionalLiquidityHolderBalance >= amountOfPoolTokenToBurn, "The extra liquidity holder should have enough pool tokens to burn");

          IPoolToken(pool.fixedConfig.token).transferFrom(extraLiquidityHolder, address(this), amountOfPoolTokenToBurn);
          IPoolToken(pool.fixedConfig.token).burn(amountOfPoolTokenToBurn);

          uint256 amountOfPaymentTokenToWithdhraw = (amountOfPoolTokenToBurn * tokenPrice) / 1e18;
          // We need to decrease the amount of paymentToken in the contract
          ILiquidityManager(liquidityManager).transferPaymentTokensToUser(extraLiquidityHolder, uint256(amountOfPaymentTokenToWithdhraw));
          pool.value -= amountOfPaymentTokenToWithdhraw;
        }

        uint256 tokenPriceAfter = (pool.value * 1e18) / tokenTypeLiquidity[poolType][poolTier];
        uint256 totalSupplyAfter = IPoolToken(pool.fixedConfig.token).totalSupply();
        require(tokenPrice == tokenPriceAfter, "token price shouldn't change");
        require(tokenTypeLiquidity[poolType][poolTier] == totalSupplyAfter, "total supply should equal to the desired liquidity");
      }
    }
  }

  function packPoolIdExposed(IMarketCommon.PoolType poolType, uint8 poolIndex) external pure returns (uint8) {
    return MarketHelpers.packPoolId(poolType, poolIndex);
  }

  function gasReportForSystemStateUpdate() public returns (uint256 gasUsed) {
    IOracleManager oracleManager = IOracleManager(oracleManager);

    uint80[] memory _missedEpochOracleRoundIds = OracleManagerUtils.getOracleInfoForSystemStateUpdate(
      oracleManager,
      epochInfo.latestExecutedEpochIndex,
      epochInfo.latestExecutedOracleRoundId
    );
    // HACK
    // TODO: with some better optimization of the `getOracleInfoForSystemStateUpdate` function we shouldn't need to skip any epochs...
    //       just lots of hacking to get this working now!
    if (_missedEpochOracleRoundIds.length > 0) {
      uint256 epochsToSkip = 0;
      for (
        ;
        epochsToSkip < _missedEpochOracleRoundIds.length && epochInfo.latestExecutedEpochIndex >= _missedEpochOracleRoundIds[epochsToSkip];
        epochsToSkip++
      ) {
        console2.log("This should never print, there is probably an error if it does, check it out!");
      }

      if (_missedEpochOracleRoundIds.length - epochsToSkip > 0) {
        uint80[] memory missedEpochsOracleRoundIds = new uint80[](_missedEpochOracleRoundIds.length - epochsToSkip);
        for (uint256 i = epochsToSkip; i < _missedEpochOracleRoundIds.length; i++) {
          missedEpochsOracleRoundIds[i - epochsToSkip] = _missedEpochOracleRoundIds[i];
        }

        uint256 startGas = gasleft();
        this.updateSystemStateUsingValidatedOracleRoundIds(missedEpochsOracleRoundIds);
        uint256 endGas = gasleft();
        gasUsed = startGas - endGas;
      }
    }
  }
}
