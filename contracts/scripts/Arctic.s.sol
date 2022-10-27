// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../PoolToken/PoolToken.sol";
import "../oracles/OracleManager.sol";
import "../YieldManagers/MarketLiquidityManagerSimple.sol";
import "../interfaces/IMarket.sol";
import "../testing/dev/UpgradeTester.sol";
import "../mocks/ChainlinkAggregatorFaster.sol";
import "../PoolToken/PoolToken.sol";
import "../mocks/ChainlinkAggregatorRandomScribble.sol";
import "../testing/FloatContractsCoordinator.s.sol";
import "../shifting/Shifting.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ArcticConfig is FloatContractsCoordinator {
  uint256 constant EPOCH_LENGTH = 4200;
  uint256 constant MEWT = 10;
  uint256 constant ETH_FAST_EPOCH_LENGTH = 600; //10min in seconds
  uint256 constant ETH_FAST_MEWT = 0;

  bool deployLocal;

  struct MarketConfig {
    string name;
    string symbol;
    address oraclePriceFeedAddress;
    uint256 epochLength;
    uint256 mewt;
    mapping(uint256 => MarketFactory.PoolLeverage) poolLeverages;
    uint256 numberOfPools;
  }

  mapping(uint256 => MarketConfig) marketConfig;

  function setupConfig(address admin) internal {
    if (currentChain == Chain.Mumbai) {
      vm.startBroadcast(admin);
      //ETH Market Using fast oracle adapter
      // speed up factor 15x
      // 240s (4 minutes) update length
      // epoch length 10 min (600s)
      // mewt 0s
      ChainlinkAggregatorFaster ethChainlinkOracle = new ChainlinkAggregatorFaster(
        AggregatorV3Interface(ETH_ORACLE_MUMBAI_ADDRESS),
        24, /* With a perfect oracle heartbeat of 60 minutes this would be 15, now we have 8 min leway time*/
        4 minutes
      );
      vm.stopBroadcast();
      {
        MarketConfig storage ethMarketConfig = marketConfig[1];
        ethMarketConfig.name = "ETH";
        ethMarketConfig.symbol = "ETH";
        ethMarketConfig.oraclePriceFeedAddress = address(ethChainlinkOracle);
        ethMarketConfig.epochLength = ETH_FAST_EPOCH_LENGTH;
        ethMarketConfig.mewt = ETH_FAST_MEWT;
        ethMarketConfig.numberOfPools = 7;
        ethMarketConfig.poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
        ethMarketConfig.poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
        ethMarketConfig.poolLeverages[2] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.LONG, 1);
        ethMarketConfig.poolLeverages[3] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 2);
        ethMarketConfig.poolLeverages[4] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
        ethMarketConfig.poolLeverages[5] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.SHORT, 1);
        ethMarketConfig.poolLeverages[6] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 2);
      }
      {
        MarketConfig storage linkMarketConfig = marketConfig[2];
        linkMarketConfig.name = "LINK";
        linkMarketConfig.symbol = "LINK";
        linkMarketConfig.oraclePriceFeedAddress = LINK_ORACLE_MUMBAI_ADDRESS;
        linkMarketConfig.epochLength = EPOCH_LENGTH;
        linkMarketConfig.mewt = MEWT;
        linkMarketConfig.numberOfPools = 7;
        linkMarketConfig.poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
        linkMarketConfig.poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
        linkMarketConfig.poolLeverages[2] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.LONG, 1);
        linkMarketConfig.poolLeverages[3] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 2);
        linkMarketConfig.poolLeverages[4] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
        linkMarketConfig.poolLeverages[5] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.SHORT, 1);
        linkMarketConfig.poolLeverages[6] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 2);
      }
    } else if (currentChain == Chain.Goerli) {
      {
        MarketConfig storage ethMarketConfig = marketConfig[1];
        ethMarketConfig.name = "ETH";
        ethMarketConfig.symbol = "ETH";
        ethMarketConfig.oraclePriceFeedAddress = ETH_ORACLE_GOERLI_ADDRESS;
        ethMarketConfig.epochLength = EPOCH_LENGTH;
        ethMarketConfig.mewt = MEWT;
        ethMarketConfig.numberOfPools = 3;
        ethMarketConfig.poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
        ethMarketConfig.poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
        ethMarketConfig.poolLeverages[2] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
      }
    } else if (currentChain == Chain.Fuji) {
      vm.startBroadcast(admin);
      //AVAX Market Using fast oracle adapter
      // speed up factor 15x
      // 240s (4 minutes) update length
      // epoch length 10 min (600s)
      // mewt 0s
      ChainlinkAggregatorFaster avaxFastChainlinkOracle = new ChainlinkAggregatorFaster(
        AggregatorV3Interface(AVAX_ORACLE_FUJI_ADDRESS),
        20, /* With a perfect oracle heartbeat of 10 minutes this would be 10, now we have 10 min leway time*/
        1 minutes
      );
      vm.stopBroadcast();

      {
        MarketConfig storage avaxMarketConfig = marketConfig[1];
        avaxMarketConfig.name = "AVAX-Fast";
        avaxMarketConfig.symbol = "fAVAX";
        avaxMarketConfig.oraclePriceFeedAddress = address(avaxFastChainlinkOracle);
        avaxMarketConfig.epochLength = 2 minutes;
        avaxMarketConfig.mewt = 2 seconds;
        avaxMarketConfig.numberOfPools = 7;
        avaxMarketConfig.poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
        avaxMarketConfig.poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
        avaxMarketConfig.poolLeverages[2] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.LONG, 1);
        avaxMarketConfig.poolLeverages[3] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 2);
        avaxMarketConfig.poolLeverages[4] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
        avaxMarketConfig.poolLeverages[5] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.SHORT, 1);
        avaxMarketConfig.poolLeverages[6] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 2);
      }
      {
        MarketConfig storage avaxMarketConfig = marketConfig[2];
        avaxMarketConfig.name = "AVAX-Slow";
        avaxMarketConfig.symbol = "sAVAX";
        avaxMarketConfig.oraclePriceFeedAddress = AVAX_ORACLE_FUJI_ADDRESS;
        avaxMarketConfig.epochLength = 15 minutes; // 15 minutes
        avaxMarketConfig.mewt = 10 seconds;
        avaxMarketConfig.numberOfPools = 7;
        avaxMarketConfig.poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
        avaxMarketConfig.poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
        avaxMarketConfig.poolLeverages[2] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.LONG, 1);
        avaxMarketConfig.poolLeverages[3] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 2);
        avaxMarketConfig.poolLeverages[4] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
        avaxMarketConfig.poolLeverages[5] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.SHORT, 1);
        avaxMarketConfig.poolLeverages[6] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 2);
      }
    } else if (currentChain == Chain.ForgeTest) {
      vm.startBroadcast();
      AggregatorV3Interface ethChainlinkOracle = new AggregatorV3Mock(
        DEFAULT_ORACLE_FIRST_PRICE,
        DEFAULT_ORACLE_FIRST_ROUND_ID,
        DEFAULT_ORACLE_DECIMALS
      );

      // Just to prevent this from running twice
      if (address(getKeeperAddress()).codehash == "" && deployLocal) {
        KeeperArctic keeperImplementation = new KeeperArctic();
        KeeperArctic newKeeper = KeeperArctic(
          address(
            new ERC1967Proxy(
              address(keeperImplementation),
              abi.encodeCall(
                KeeperArctic(keeperImplementation).initialize,
                (
                  msg.sender,
                  address(
                    420 /* random address until it gets registered in the script*/
                  )
                )
              )
            )
          )
        );
        console2.log("Using keeper at", address(newKeeper));

        require(
          address(newKeeper) == getKeeperAddress(),
          "keeper address set incorrectly - it should be deterministic - check contract deployment order etc."
        );

        address paymentTokenImplementation = address(new PaymentTokenTestnet());
        PaymentTokenTestnet newPaymentToken = PaymentTokenTestnet(
          address(
            new ERC1967Proxy(
              paymentTokenImplementation,
              abi.encodeCall(
                PaymentTokenTestnet(paymentTokenImplementation).initializeWithAdmin,
                (admin, string.concat("Test Payment Token ", "Forge"), string.concat("TPT", "Forge"))
              )
            )
          )
        );
        console2.log("Using payment token at", address(newPaymentToken));

        require(
          address(newPaymentToken) == getPaymentTokenAddress(),
          "payment token address set incorrectly - it should be deterministic - check contract deployment order etc."
        );

        address newShifterProxyImplementationAddress = address(new ShiftingProxy());
        address shifterProxy = address(
          new ERC1967Proxy(
            newShifterProxyImplementationAddress,
            abi.encodeCall(ShiftingProxy(newShifterProxyImplementationAddress).initialize, Shifting(address(0)))
          )
        );

        console2.log("shifterProxy", shifterProxy);
        require(
          shifterProxy == getShifterProxyAddress(),
          "shifter proxy address set incorrectly - it should be deterministic - check contract deployment order etc."
        );
      }
      vm.stopBroadcast();

      {
        MarketConfig storage ethMarketConfig = marketConfig[1];
        ethMarketConfig.name = "ETH";
        ethMarketConfig.symbol = "ETH";
        ethMarketConfig.oraclePriceFeedAddress = address(ethChainlinkOracle);
        ethMarketConfig.epochLength = ETH_FAST_EPOCH_LENGTH;
        ethMarketConfig.mewt = ETH_FAST_MEWT;
        ethMarketConfig.numberOfPools = 7;
        ethMarketConfig.poolLeverages[0] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.FLOAT, 0);
        ethMarketConfig.poolLeverages[1] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.LONG, 0);
        ethMarketConfig.poolLeverages[2] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.LONG, 1);
        ethMarketConfig.poolLeverages[3] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.LONG, 2);
        ethMarketConfig.poolLeverages[4] = MarketFactory.PoolLeverage(1e18, IMarketCommon.PoolType.SHORT, 0);
        ethMarketConfig.poolLeverages[5] = MarketFactory.PoolLeverage(2e18, IMarketCommon.PoolType.SHORT, 1);
        ethMarketConfig.poolLeverages[6] = MarketFactory.PoolLeverage(3e18, IMarketCommon.PoolType.SHORT, 2);
      }
    } else {
      revert("ETH oracle setup not supported for current chain");
    }
  }
}

contract ArcticDeployCore is ArcticConfig {
  bytes32 constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  address paymentToken;
  address immutable upgradeTesterImplementation;

  /*
   * NOTE msg.sender is different in the constructor than any other function (with forge).
   *   Not sure why this is but it makes things a bit of a pain.
   *   msg.sender in the constructor seems to always be
   *     - 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 for `forge script`.
   *     - 0x00a329c0648769A73afAc7F9381E08FB43dBEA72 for `fore test`
   *   Due to this eccentricity we can't use msg.sender as the admin.
   *
   * NOTE calling `vm.startBroadcast()` followed by creating a `new` contract
   *   in the constructor will cause `forge script` to break without logs, example:
   *     Error:
   *     Failed to deploy script:
   *     Execution reverted: EvmError: Revert (gas: 9079256848779079435)
   *   One must use `vm.startBroadcast(someAddress)` instead
   */
  constructor() {
    upgradeTesterImplementation = address(new UpgradeTester());
  }

  function deployBaseContracts(address admin) public {
    vm.startBroadcast(admin);

    gems = constructGems();
    console2.log("gems deployed", address(gems));
    registry = constructRegistry(address(gems), admin);
    console2.log("registry deployed", address(registry));

    paymentToken = address(constructOrUpdatePaymentTokenTestnet("ArcticTestPaymentToken", rand.randomNumber32(), admin));

    PaymentTokenTestnet(paymentToken).mintFor(1e22, admin);
    // mint some tokens that can be used for testing.
    PaymentTokenTestnet(paymentToken).mint(20e18);
    keeper = constructOrUpdateKeeper(address(registry), admin);
    // NOTE: we need a different shifter for each payment token that we use!
    shifterProxy = constructOrUpdateShifter(paymentToken, registry, admin);

    vm.stopBroadcast();
  }

  function randomUserActivity(
    uint256 numberOfIterations,
    address[] memory users,
    uint32 market
  ) internal {
    uint256 numberOfUsers = users.length;

    Market marketInstance = Market(registry.separateMarketContracts(market));

    uint256 numOfLongPools = marketInstance.numberOfPoolsOfType(IMarketCommon.PoolType.LONG);
    uint256 numOfShortPools = marketInstance.numberOfPoolsOfType(IMarketCommon.PoolType.SHORT);

    // Give the user initial payment token
    for (uint256 userIndex = 0; userIndex < numberOfUsers; userIndex++) {
      address user = users[userIndex];
      changePrank(user);
      PaymentTokenTestnet(paymentToken).mint(5e21);
      PaymentTokenTestnet(paymentToken).approve(address(registry.separateMarketContracts(market)), ~uint256(0));
    }

    console2.log("\n\nstarting cycle\n==============");

    console2.log("numberOfIterations: ", numberOfIterations);
    for (uint256 iteration = 0; iteration < numberOfIterations; iteration++) {
      console2.log("Running iteration: ", iteration);
      // go through each user
      //   decide if they will mint/redeem/shift/stake
      //     decide amount for action + execute action
      for (uint256 userIndex = 0; userIndex < numberOfUsers; userIndex++) {
        address user = users[userIndex];
        changePrank(user);

        bool shouldMint = rand.randomBool();
        bool shouldRedeem = rand.randomBool();

        if (shouldMint) {
          bool isLong = rand.randomBool();

          uint256 paymentTokenBalance = IERC20(paymentToken).balanceOf(user);
          if (paymentTokenBalance > 1e18) {
            mint(
              market,
              isLong,
              rand.randomNumber(isLong ? numOfLongPools : numOfShortPools),
              rand.randomInRange112(1e18 + 1, uint112(paymentTokenBalance))
            );
          }
        }
        if (shouldRedeem) {
          bool isLong = rand.randomBool();

          uint256 poolToInteractWith = rand.randomNumber((isLong ? numOfLongPools : numOfShortPools));

          uint256 poolTokenBalance;
          {
            address poolTokenTokenAddresss = marketInstance.get_pool_token(
              isLong ? IMarketCommon.PoolType.LONG : IMarketCommon.PoolType.SHORT,
              poolToInteractWith
            );
            poolTokenBalance = IERC20(poolTokenTokenAddresss).balanceOf(user);
          }

          if (poolTokenBalance > 0) {
            redeem(market, isLong, poolToInteractWith, rand.randomInRange112(1, uint112(poolTokenBalance)));
          }
        }
      }
      vm.stopPrank();

      console2.log("\nCycle complete\n==============\n");

      console2.log("\nUpdateTimeAndUpdateSystemState not complete\n==============\n");
      updateTimeAndUpdateSystemState(market);
      console2.log("\nUpdateTimeAndUpdateSystemState complete\n==============\n");
    }
  }

  // NOTE: these are defined here to relieve pressure on the stack
  uint256 initialPoolLiquidity = 1e15;

  function getPoolLeveragesFromStorage(MarketConfig storage marketConfigToDeploy)
    internal
    view
    returns (MarketFactory.PoolLeverage[] memory poolLeverages)
  {
    poolLeverages = new MarketFactory.PoolLeverage[](marketConfigToDeploy.numberOfPools);
    for (uint256 i = 0; i < marketConfigToDeploy.numberOfPools; i++) {
      require(marketConfigToDeploy.poolLeverages[i].leverage != 0, "The leverage cann't be zero, is your `numberOfPools` variable correct?");
      poolLeverages[i] = marketConfigToDeploy.poolLeverages[i];
    }
    require(
      marketConfigToDeploy.poolLeverages[marketConfigToDeploy.numberOfPools].leverage == 0,
      "numberOfPools variable is incorrect, it should be larger."
    );
  }

  function deployMarket(
    MarketConfig storage marketConfigToDeploy,
    address _upgradeTesterImplementation,
    address admin
  ) internal returns (uint32 marketIndex) {
    if (address(shifterProxy) == address(0)) {
      shifterProxy = ShiftingProxy(getShifterProxyAddress());
    }

    {
      marketIndex = marketFactory.deployMarketWithBroadcast(
        admin,
        initialPoolLiquidity,
        getPoolLeveragesFromStorage(marketConfigToDeploy),
        marketConfigToDeploy.epochLength,
        marketConfigToDeploy.mewt,
        marketConfigToDeploy.oraclePriceFeedAddress,
        IERC20(address(paymentToken)),
        MarketFactory.MarketContractType.MarketTieredLeverage,
        marketConfigToDeploy.name,
        marketConfigToDeploy.symbol,
        vm
      );
    }

    {
      vm.startBroadcast(admin);

      Shifting shifter = shifterProxy.currentShifter();
      address marketAddress = marketFactory.marketAddress(marketIndex);

      shifter.addValidMarket(marketAddress);
      vm.stopBroadcast();
    }

    console2.log("core deployment done!");

    vm.startPrank(admin);

    // Test that market and all pool tokens are upgradeable!
    checkUpgradesAreWorking(marketFactory.marketAddress(marketIndex), _upgradeTesterImplementation);

    // TODO: re-add and test this, seems to be tweaky.
    // // Test that the Arctic PoolTokens are interoperable with the original "ALPHA" tokens.
    // address newImplementation = address(new PoolTokenUpgradeableOriginal());
    // console2.log("This is the new implementation", newImplementation);
    // for (uint256 i = 0; i < initPools.length; i++) {
    //   console2.log("checking upgrades");
    //   checkUpgradesAreWorking(initPools[i].token, newImplementation);
    // }

    vm.stopPrank();
  }

  /// @dev if you can upgrade the contract and re-upgrade it back to the original implementation
  function checkUpgradesAreWorking(address contractToTestUpgradeOf, address newImplementation) internal {
    address originalImplementationImplementation = address(uint160(uint256(vm.load(contractToTestUpgradeOf, _IMPLEMENTATION_SLOT))));
    console2.log("Checking upgrades are working for: ", originalImplementationImplementation);
    // NOTE: if this line fails it is possible that the upgradeTesterImplementation function isn't defined/initialized yet.
    AccessControlledAndUpgradeable(contractToTestUpgradeOf).upgradeTo(newImplementation);

    AccessControlledAndUpgradeable(contractToTestUpgradeOf).upgradeTo(originalImplementationImplementation);
  }

  function checkUpgradesAreWorkingPrev(address contractToTestUpgradeOf) internal {
    address originalImplementation = address(uint160(uint256(vm.load(contractToTestUpgradeOf, _IMPLEMENTATION_SLOT))));
    console2.log("Checking upgrades are working for: ", originalImplementation);
    // NOTE: if this line fails it is possible that the upgradeTesterImplementation function isn't defined/initialized yet.
    AccessControlledAndUpgradeable(contractToTestUpgradeOf).upgradeTo(upgradeTesterImplementation);

    AccessControlledAndUpgradeable(contractToTestUpgradeOf).upgradeTo(originalImplementation);
  }

  function updateTimeAndUpdateSystemState(uint32 marketIndex) internal {
    // warp time to just after the next epoch

    IOracleManager oracleManager = marketFactory.oracleManager(marketIndex);
    uint32 epochTimestamp = uint32(oracleManager.getEpochStartTimestamp());

    uint256 timeToWarpTo = uint256(epochTimestamp) + oracleManager.EPOCH_LENGTH() + oracleManager.MINIMUM_EXECUTION_WAIT_THRESHOLD() + 1;
    vm.warp(timeToWarpTo);

    int256 percentChangeWithinFiveUpOrDown = (int256(rand.randomInRange(1, 1e17)) - 5e16);

    AggregatorV3Interface chainlinkOracle = marketFactory.chainlinkOracle(marketIndex);
    mockChainlinkOraclePercentPriceMovement(chainlinkOracle, percentChangeWithinFiveUpOrDown);

    updateSystemStateSingleMarket(marketIndex);
  }

  function checkUpgradesWork(
    address _upgradeTesterImplementation,
    address admin,
    uint32 marketIndex
  ) public {
    vm.startPrank(admin);

    // test that the keeper is upgradeable
    checkUpgradesAreWorking(address(keeper), _upgradeTesterImplementation);
    // test that the registry is upgradeable
    checkUpgradesAreWorking(address(registry), _upgradeTesterImplementation);
    // test that the paymentToken is upgradeable
    checkUpgradesAreWorking(address(paymentToken), _upgradeTesterImplementation);
    vm.stopPrank();

    AggregatorV3Interface chainlinkOracle = marketFactory.chainlinkOracle(marketIndex);
    mockChainlinkOraclePercentPriceMovement(chainlinkOracle, ONE_PERCENT);

    updateSystemStateAllMarkets(); // Just to make sure everything is working before we start rest of the simulation.
    {
      IOracleManager oracleManager = marketFactory.oracleManager(marketIndex);

      uint256 timeToWarpTo = block.timestamp + oracleManager.EPOCH_LENGTH() + oracleManager.MINIMUM_EXECUTION_WAIT_THRESHOLD();
      vm.warp(timeToWarpTo);

      mockChainlinkOraclePercentPriceMovement(chainlinkOracle, ONE_PERCENT * 6);

      (bool canExec, bytes memory execPayload) = keeper.shouldUpdateMarket();
      require(canExec, "Keeper should be able to execute");
      // NOTE: can't compare bytes directly, so hashing them to make comparison possible.
      uint80[] memory oracleUpdateIndexes = new uint80[](1);
      (oracleUpdateIndexes[0], , , , ) = oracleManager.chainlinkOracle().latestRoundData();
      require(
        keccak256(execPayload) ==
          keccak256(
            abi.encodeCall(KeeperArctic.updateSystemStateForMarket, (IMarketTieredLeverage(registry.separateMarketContracts(1)), oracleUpdateIndexes))
          ),
        "keeper payload is different to what is expected"
      );
      updateTimeAndUpdateSystemState(marketIndex);
    }
  }

  function testMarketsWorkCorrectly(uint256 numberOfMarkets, uint256 numberOfUpdates) internal {
    require(numberOfMarkets == 1, "numberOfMarkets must be 1 because code is buggy :(");
    if (!deployLocal) {
      address[] memory users = new address[](5);
      users[0] = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
      users[1] = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
      users[2] = 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC;
      users[3] = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
      users[4] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
      for (uint256 i = 0; i < numberOfUpdates; i++) {
        for (uint32 j = 1; j <= numberOfMarkets; ++j) {
          randomUserActivity(1, users, j);
        }
      }
    }
  }

  function deployCoreContracts() public {
    setupContractCoordinator();

    address admin = deployLocal ? msg.sender : getAdminAddress();

    require(admin == msg.sender, "incorrect admin address");
    console2.log("Starting Arctic deploy script with admin: ", admin);

    setupConfig(admin);

    deployBaseContracts(admin);

    console2.log("Finished Arctic deploy script");
  }
}

contract ArcticDeployBase is ArcticDeployCore {
  function run() public {
    deployCoreContracts();
  }
}

contract ArcticDeployMarkets is ArcticDeployCore {
  function localDeployment() public {
    deployLocal = true;
    deployCoreContracts();
    deployMarkets();

    registry = Registry(address(keeper.registry()));

    AggregatorV3Mock v3MockOracle = AggregatorV3Mock(address(IMarket(registry.separateMarketContracts(1)).get_oracleManager().chainlinkOracle()));

    vm.startBroadcast();
    v3MockOracle.pushPricePercentMovement(1e16);
    vm.stopBroadcast();
  }

  function deployMarkets() public {
    address admin = deployLocal ? msg.sender : getAdminAddress();

    require(admin == msg.sender, "incorrect admin address");
    console2.log("Starting Arctic deploy script with admin: ", admin);

    setupConfig(admin);

    keeper = KeeperArctic(getKeeperAddress());
    registry = Registry(address(keeper.registry()));

    marketFactory = new MarketFactory(registry);

    paymentToken = getPaymentTokenAddress();

    if (PaymentTokenTestnet(paymentToken).balanceOf(msg.sender) < 20e18) {
      // This will of course fail on mainnet when a real payment token is used!
      vm.startBroadcast(msg.sender);
      PaymentTokenTestnet(paymentToken).mint(1000e18);
      vm.stopBroadcast();
    }

    uint32 latestMarketIndex = deployMarket(marketConfig[1], upgradeTesterImplementation, admin);

    // checkUpgradesWork();

    // TODO make another chainlinkOracle variable for the link market
    if (currentChain == Chain.Fuji || currentChain == Chain.Mumbai) {
      latestMarketIndex = deployMarket(marketConfig[2], upgradeTesterImplementation, admin);
    }

    // TODO: https://github.com/Float-Capital/monorepo/issues/3557
    checkUpgradesWork(
      upgradeTesterImplementation,
      msg.sender,
      1 /* latestMarketIndex */
    );

    testMarketsWorkCorrectly(1, 20);

    console2.log("Finished Arctic deploy script");
  }

  function run() public virtual {
    setupContractCoordinator();

    deployMarkets();
  }
}

contract ArcticDeployAll is ArcticDeployMarkets {
  function run() public override {
    deployCoreContracts();

    deployMarkets();
  }
}

/// @dev Below functions are only used for local deployment and testing.
contract ArcticDeploymentTest is ArcticDeployAll {
  function testDeployment() public {
    setupContractCoordinator();
    address admin = getAdminAddress();
    // vm.startPrank(admin);

    setupConfig(admin);

    deployBaseContracts(admin);

    marketFactory = new MarketFactory(registry);
    // mockChainlinkOraclePercentPriceMovement(ethChainlinkOracle, ONE_PERCENT);

    uint32 marketIndex = deployMarket(marketConfig[1], upgradeTesterImplementation, admin);

    checkUpgradesWork(upgradeTesterImplementation, admin, marketIndex);
  }
}

contract ArcticLocalTest is ArcticDeployAll {
  AggregatorV3Mock v3MockOracle;

  constructor() {
    isLoggingOn = true;
    deployLocal = true;
    setupContractCoordinator();

    keeper = KeeperArctic(getKeeperAddress());
    registry = Registry(address(keeper.registry()));
    v3MockOracle = AggregatorV3Mock(address(IMarket(registry.separateMarketContracts(1)).get_oracleManager().chainlinkOracle()));

    paymentToken = getPaymentTokenAddress();
  }

  function mint(
    address user,
    uint256 pool,
    uint32 marketIndex,
    uint112 amount,
    bool isLong
  ) internal {
    if (isLoggingOn) {
      console2.log("*********");
      console2.log(isLong ? "Random MINT: LONG" : "Random MINT: SHORT", user, "marketInde", marketIndex);
      console2.log("amount", amount, "pool", pool);
      console2.log("*********");
    }
    Market marketInstance = Market(registry.separateMarketContracts(marketIndex));

    if (isLong) {
      marketInstance.mintLong(pool, amount);
    } else {
      marketInstance.mintShort(pool, amount);
    }
  }

  function redeem(
    address user,
    uint256 pool,
    uint32 marketIndex,
    uint112 amount,
    bool isLong
  ) internal {
    if (isLoggingOn) {
      console2.log("*********");
      console2.log(isLong ? "Random REDEEM: LONG" : "Random REDEEM: SHORT", user, "marketInde", marketIndex);
      console2.log("amount", amount, "pool", pool);
      console2.log("*********");
    }
    Market marketInstance = Market(registry.separateMarketContracts(marketIndex));

    updateSystemStateSingleMarket(marketIndex);

    if (isLong) {
      marketInstance.redeemLong(pool, amount);
    } else {
      marketInstance.redeemShort(pool, amount);
    }
  }

  function userMint(
    uint32 marketIndex,
    uint256 pool,
    bool isLong
  ) internal {
    vm.startBroadcast();
    v3MockOracle.pushPricePercentMovement(1e16);
    PaymentTokenTestnet(paymentToken).mint(1000e18);
    PaymentTokenTestnet(paymentToken).approve(address(registry.separateMarketContracts(marketIndex)), ~uint256(0));
    uint256 paymentTokenBalance = PaymentTokenTestnet(paymentToken).balanceOf(msg.sender);
    if (paymentTokenBalance > 1e18) {
      mint(msg.sender, pool, marketIndex, uint112(1e18), isLong);
    }
    vm.stopBroadcast();
  }

  function userRedeem(
    uint32 marketIndex,
    uint256 pool,
    bool isLong
  ) internal {
    setupContractCoordinator();

    vm.startBroadcast();
    v3MockOracle.pushPricePercentMovement(1e16);
    Market marketInstance = Market(registry.separateMarketContracts(marketIndex));

    uint256 poolTokenBalance;
    {
      address poolTokenTokenAddresss = marketInstance.get_pool_token(isLong ? IMarketCommon.PoolType.LONG : IMarketCommon.PoolType.SHORT, pool);

      poolTokenBalance = IERC20(poolTokenTokenAddresss).balanceOf(msg.sender);
    }

    console2.log("users poolTokenBalance is", poolTokenBalance);

    if (poolTokenBalance > 0) {
      redeem(msg.sender, pool, marketIndex, uint112(poolTokenBalance), isLong);
    }
    vm.stopBroadcast();
  }

  function runTestMints() public {
    userMint(1, 0, true);
    userMint(1, 0, false);
    userMint(1, 1, true);
    userMint(1, 1, false);
  }

  function runTestUpdateSystemState() public {
    vm.startBroadcast();
    console2.log("current block time", block.timestamp);
    v3MockOracle.pushPricePercentMovement(1e16); //1%
    updateSystemStateSingleMarket(1);
    vm.stopBroadcast();
  }

  function runTestRedeems() public {
    userRedeem(1, 0, true);
    userRedeem(1, 0, false);
    userRedeem(1, 1, true);
    userRedeem(1, 1, false);
  }
}
