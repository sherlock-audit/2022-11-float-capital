// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import "../keepers/KeeperArctic.sol";
import "../shifting/Shifting.sol";
import "../registry/template/Registry.sol";
import "../testing/MarketTieredLeverageInternalStateSetters.sol";
import "../components/gamificationFun/GEMS.sol";

import "../testing/MarketFactory.t.sol";
import "../testing/RandomnessHelper.t.sol";
import "../testing/Constants.t.sol";

import "../mocks/AggregatorV3Mock.t.sol";

import "../keepers/OracleManagerUtils.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../interfaces/chainlink/AggregatorV3Interface.sol";

/*
 * Intended to be the top-level parent class for both deployment scripts and test contracts for forge.
 */
abstract contract FloatContractsCoordinator is Test, Constants, RandomnessHelper {
  bool isLoggingOn = true;
  // NOTE ideally these should be immutable and set in the constructors of child classes,
  //   but forge does some weird stuff when deploying test/script contracts which makes
  //   this pattern impossible.
  MarketFactory marketFactory;
  GEMS gems;
  address treasury;
  Registry registry;
  KeeperArctic keeper;
  ShiftingProxy shifterProxy;

  RandomnessHelper rand;
  Chain currentChain;
  mapping(uint32 => Chain) private chainIdToEnum;
  mapping(Chain => address) private chainToAdminAddress;
  mapping(Chain => address) private chainToKeeperAddress;
  mapping(Chain => address) private chainToShifterProxyAddress;
  mapping(Chain => address) private chainToPaymentTokenAddress; // Note: different markets might want different payment tokens - this is for the default

  enum Chain {
    Unknown,
    ForgeTest,
    Mumbai,
    Goerli,
    Ganache,
    Fuji,
    Avalanche,
    Polygon
  }

  function setupContractCoordinator() public {
    rand = new RandomnessHelper();

    chainIdToEnum[80001] = Chain.Mumbai;
    chainIdToEnum[1337] = Chain.Ganache;
    chainIdToEnum[137] = Chain.Polygon;
    chainIdToEnum[5] = Chain.Goerli;
    chainIdToEnum[43113] = Chain.Fuji;
    chainIdToEnum[43114] = Chain.Avalanche;
    chainIdToEnum[31337] = Chain.ForgeTest;

    chainToAdminAddress[Chain.Mumbai] = ADMIN_MUMBAI;
    chainToAdminAddress[Chain.Ganache] = ADMIN_GANACHE;
    chainToAdminAddress[Chain.Goerli] = ADMIN_GOERLI;
    chainToAdminAddress[Chain.Fuji] = ADMIN_FUJI;
    chainToAdminAddress[Chain.Polygon] = address(0); // not set yet
    chainToAdminAddress[Chain.Avalanche] = address(0); // not set yet
    chainToAdminAddress[Chain.ForgeTest] = ADMIN;

    chainToPaymentTokenAddress[Chain.Mumbai] = DEFAULT_PAYMENT_TOKEN_MUMBAI_ADDRESS;
    chainToPaymentTokenAddress[Chain.Fuji] = DEFAULT_PAYMENT_TOKEN_FUJI_ADDRESS;
    chainToPaymentTokenAddress[Chain.ForgeTest] = DEFAULT_PAYMENT_TOKEN_ANVIL_ADDRESS;
    chainToPaymentTokenAddress[Chain.Ganache] = address(0); // not set yet
    chainToPaymentTokenAddress[Chain.Goerli] = address(0); // not set yet
    chainToPaymentTokenAddress[Chain.Polygon] = address(0); // not set yet
    chainToPaymentTokenAddress[Chain.Avalanche] = address(0); // not set yet

    chainToKeeperAddress[Chain.Mumbai] = KEEPER_MUMBAI_ADDRESS;
    chainToKeeperAddress[Chain.Fuji] = KEEPER_FUJI_ADDRESS;
    chainToKeeperAddress[Chain.ForgeTest] = KEEPER_ANVIL_ADDRESS;
    chainToKeeperAddress[Chain.Goerli] = address(0); // not set yet
    chainToKeeperAddress[Chain.Ganache] = address(0); // not set yet
    chainToKeeperAddress[Chain.Polygon] = address(0); // not set yet
    chainToKeeperAddress[Chain.Avalanche] = address(0); // not set yet

    chainToShifterProxyAddress[Chain.ForgeTest] = SHIFTER_PROXY_ADDRESS_ANVIL;
    chainToShifterProxyAddress[Chain.Mumbai] = SHIFTER_PROXY_ADDRESS_MUMBAI;
    chainToShifterProxyAddress[Chain.Fuji] = SHIFTER_PROXY_ADDRESS_FUJI;

    currentChain = chainIdToEnum[uint32(block.chainid)];
  }

  function getChain() public view returns (Chain chain) {
    uint32 chainId = uint32(block.chainid);
    chain = chainIdToEnum[chainId];
    if (chain == Chain.Unknown) {
      revert(string.concat("WARNING unknown chainId:", Strings.toString(chainId)));
    }
  }

  function getKeeperAddress() public view returns (address keeperAddress) {
    keeperAddress = chainToKeeperAddress[currentChain];
    if (keeperAddress == address(0)) {
      revert(string.concat("No keeper address set for chainId:", Strings.toString(uint32(block.chainid))));
    }
  }

  function getShifterProxyAddress() public view returns (address shifterAddress) {
    shifterAddress = chainToShifterProxyAddress[currentChain];
    if (shifterAddress == address(0)) {
      revert(string.concat("No shifter address set for chainId:", Strings.toString(uint32(block.chainid))));
    }
  }

  function getPaymentTokenAddress() public view returns (address paymentToken) {
    paymentToken = chainToPaymentTokenAddress[currentChain];
    if (paymentToken == address(0)) {
      revert("Payment token not set up for current chain:");
    }
  }

  function getAdminAddress() public view returns (address admin) {
    admin = chainToAdminAddress[currentChain];
    if (admin == address(0)) {
      revert("Admin address not set for current chain");
    }
  }

  function constructGems() public returns (GEMS) {
    if (address(gems) != address(0)) {
      console2.log("WARNING GEMS contract has already been constructed");
    }

    // NOTE: it is essential that the GEMS contract is behind a proxy since it stores state and we may want to update the logic in it at some stage.
    GEMS gemsImplementation = new GEMS();
    ERC1967Proxy gemsProxy = new ERC1967Proxy(address(gemsImplementation), "");

    return GEMS(address(gemsProxy));
  }

  // NOTE we have to accept this `admin` param because msg.sender does not always work as expected with forge
  function constructRegistry(address _gems, address admin) public returns (Registry ls) {
    if (address(registry) != address(0)) {
      console2.log("WARNING Registry contract has already been constructed");
    }

    address registryImplementation = address(new Registry());
    ERC1967Proxy registryProxy = new ERC1967Proxy(
      address(registryImplementation),
      abi.encodeCall(Registry(registryImplementation).initialize, (admin, _gems))
    );
    ls = Registry(address(registryProxy));

    require(gems.hasRole(gems.DEFAULT_ADMIN_ROLE(), address(ls)), "Registry should have GEM role");
    require(gems.hasRole(gems.GEM_ROLE(), address(ls)), "Registry should have GEM role");
  }

  // NOTE we have to accept this `admin` param because msg.sender does not always work as expected
  // TODO: debug and clean/fix this, it seems like we are always deploying a new keeper, even though one should already exist on mumbai.
  function constructOrUpdateKeeper(address _registry, address admin) public returns (KeeperArctic _keeper) {
    require(address(keeper) == address(0), "Keeper contract has already been constructed");

    address newKeeperImplementationAddress = address(new KeeperArctic());

    address keeperProxyAddresss = chainToKeeperAddress[currentChain];
    if (
      keeperProxyAddresss != address(0) &&
      keeperProxyAddresss.codehash != "" && /* if it isn't deployed to this address then deploy the proxy */
      KeeperArctic(keeperProxyAddresss).hasRole(KeeperArctic(keeperProxyAddresss).UPGRADER_ROLE(), admin)
    ) {
      _keeper = KeeperArctic(keeperProxyAddresss);
      _keeper.upgradeTo(newKeeperImplementationAddress);

      _keeper.setRegistry(_registry);
    } else {
      _keeper = KeeperArctic(
        address(
          new ERC1967Proxy(
            newKeeperImplementationAddress,
            abi.encodeCall(KeeperArctic(newKeeperImplementationAddress).initialize, (admin, _registry))
          )
        )
      );
    }

    keeper = _keeper;

    require(_registry == address(_keeper.registry()), "long short address not set in keeper");
  }

  function constructOrUpdateShifter(
    address paymentToken,
    Registry _registry,
    address admin
  ) public returns (ShiftingProxy _shifter) {
    require(address(shifterProxy) == address(0), "Shifter contract has already been constructed");

    address shifterImplementation = address(new Shifting());
    Shifting newShifterImplementation = Shifting(
      address(new ERC1967Proxy(shifterImplementation, abi.encodeCall(Shifting(shifterImplementation).initialize, (admin, paymentToken))))
    );

    address newShifterProxyImplementationAddress = address(new ShiftingProxy());

    address shifterProxyAddresss = chainToShifterProxyAddress[currentChain];
    if (
      shifterProxyAddresss != address(0) &&
      shifterProxyAddresss.codehash != "" &&
      ShiftingProxy(shifterProxyAddresss).hasRole(ShiftingProxy(shifterProxyAddresss).UPGRADER_ROLE(), admin)
    ) {
      _shifter = ShiftingProxy(shifterProxyAddresss);
      _shifter.upgradeTo(newShifterProxyImplementationAddress);
      _shifter.changeShifter(newShifterImplementation);
    } else {
      _shifter = ShiftingProxy(
        address(
          new ERC1967Proxy(
            newShifterProxyImplementationAddress,
            abi.encodeCall(ShiftingProxy(newShifterProxyImplementationAddress).initialize, (newShifterImplementation))
          )
        )
      );
    }

    // // NOTE: we can add this back if we run this code on an existing deployment that already has markets.
    // uint32 numberOfMarkets = _registry.latestMarket();

    // for (uint32 marketIndex = 1; marketIndex <= numberOfMarkets; marketIndex++) {
    //   MarketExtended market = MarketExtended(address(_registry.separateMarketContracts(marketIndex)));

    //   require(paymentToken == market.get_paymentToken(), "paymentToken is different to the one that was passed in!");

    //   // add the market to the correct shifter (for the market's payment token)
    //   newShifterImplementation.addValidMarket(address(market));
    // }

    shifterProxy = _shifter;

    require(newShifterImplementation == _shifter.currentShifter(), "shifter address not set correctly");
  }

  function constructOrUpgradePaymentTokenTestnet(
    bytes memory name,
    uint32 identifier,
    address admin
  ) public returns (PaymentTokenTestnet paymentToken) {
    address paymentTokenImplementation = address(new PaymentTokenTestnet());
    paymentToken = PaymentTokenTestnet(
      address(
        new ERC1967Proxy(
          paymentTokenImplementation,
          abi.encodeCall(
            PaymentTokenTestnet(paymentTokenImplementation).initializeWithAdmin,
            (admin, string.concat("Test Payment Token ", string(name)), string.concat("TPT", Strings.toString(identifier)))
          )
        )
      )
    );
  }

  function constructOrUpdatePaymentTokenTestnet(
    bytes memory name,
    uint32 identifier,
    address admin
  ) public returns (PaymentTokenTestnet paymentToken) {
    address paymentTokenImplementation = address(new PaymentTokenTestnet());

    address paymentTokenProxyAddresss = chainToPaymentTokenAddress[currentChain];
    if (
      paymentTokenProxyAddresss != address(0) &&
      paymentTokenProxyAddresss.codehash != "" && /* if it isn't deployed to this address then deploy the proxy */
      PaymentTokenTestnet(paymentTokenProxyAddresss).hasRole(PaymentTokenTestnet(paymentTokenProxyAddresss).UPGRADER_ROLE(), admin)
    ) {
      paymentToken = PaymentTokenTestnet(paymentTokenProxyAddresss);
      paymentToken.upgradeTo(paymentTokenImplementation);
    } else {
      paymentToken = PaymentTokenTestnet(
        address(
          new ERC1967Proxy(
            paymentTokenImplementation,
            abi.encodeCall(
              PaymentTokenTestnet(paymentTokenImplementation).initializeWithAdmin,
              (admin, string.concat("Test Payment Token ", string(name)), string.concat("TPT", Strings.toString(identifier)))
            )
          )
        )
      );
    }
  }

  function mockChainlinkOracleNextPrice(AggregatorV3Interface chainlinkOracle, int256 newPrice) public {
    (uint80 currentRoundId, , , , ) = chainlinkOracle.latestRoundData();

    // NOTE these don't have to stay like this, it's just that there was no need yet to make them customizable
    uint256 startedAt = block.timestamp;
    uint256 updatedAt = block.timestamp;
    uint80 newRoundId = currentRoundId + 1;

    vm.mockCall(
      address(chainlinkOracle),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(newRoundId, newPrice, startedAt, updatedAt, DEFAULT_ANSWERED_IN_ROUND)
    );
    vm.mockCall(
      address(chainlinkOracle),
      abi.encodeWithSelector(AggregatorV3Interface.getRoundData.selector, newRoundId),
      abi.encode(newRoundId, newPrice, startedAt, updatedAt, DEFAULT_ANSWERED_IN_ROUND)
    );
  }

  function mockChainlinkOraclePercentPriceMovement(
    AggregatorV3Interface chainlinkOracle,
    int256 percent // e.g. 1e18 is 100%
  ) public {
    (, int256 currentPrice, , , ) = chainlinkOracle.latestRoundData();
    int256 newPrice = currentPrice + ((currentPrice * percent) / 1e18);
    mockChainlinkOracleNextPrice(chainlinkOracle, newPrice);
  }

  function settleAllUserActions(IMarket market, address user) public {
    for (uint8 poolType = uint8(IMarketCommon.PoolType.SHORT); poolType <= uint8(IMarketCommon.PoolType.FLOAT); poolType++) {
      for (uint8 poolTier = 0; poolTier < market.numberOfPoolsOfType(IMarketCommon.PoolType(poolType)); poolTier++) {
        market.settlePoolUserMints(user, IMarketCommon.PoolType(poolType), poolTier);
        market.settlePoolUserRedeems(user, IMarketCommon.PoolType(poolType), poolTier);
      }
    }
  }

  function mint(
    uint32 marketIndex,
    IMarketCommon.PoolType poolType,
    uint256 pool,
    uint112 amount
  ) internal {
    require(address(marketFactory) != address(0), "MarketFactory was not setup correctly");
    if (isLoggingOn) {
      console2.log("*********");
      console2.log("Random MINT: ", Strings.toString(uint256(poolType)));
      console2.log("amount", amount);
      console2.log("market index", marketIndex);
      console2.log("pool index", pool);
      console2.log("*********");
    }

    IMarket market = marketFactory.market(marketIndex);

    if (poolType == IMarketCommon.PoolType.LONG) {
      market.mintLong(pool, amount);
    } else if (poolType == IMarketCommon.PoolType.FLOAT) {
      market.mintFloatPool(amount);
    } else {
      market.mintShort(pool, amount);
    }
  }

  function mintSpecial(
    uint32 marketIndex,
    IMarketCommon.PoolType poolType,
    uint256 pool,
    uint112 amount
  ) internal {
    require(address(marketFactory) != address(0), "MarketFactory was not setup correctly");
    if (isLoggingOn) {
      console2.log("*********");
      console2.log("Random MINT: ", Strings.toString(uint256(poolType)));
      console2.log("amount", amount);
      console2.log("market index", marketIndex);
      console2.log("pool index", pool);
      console2.log("*********");
    }

    IMarket market = marketFactory.market(marketIndex);

    address token = marketFactory.marketExtended(marketIndex).getPoolTokenAddress(poolType, pool);

    if (poolType == IMarketCommon.PoolType.LONG) {
      market.mintLongFor(pool, amount, token);
    } else if (poolType == IMarketCommon.PoolType.SHORT) {
      market.mintShortFor(pool, amount, token);
    }
  }

  function mint(
    uint32 marketIndex,
    bool isLong,
    uint256 pool,
    uint112 amount
  ) internal {
    IMarketCommon.PoolType poolType = isLong ? IMarketCommon.PoolType.LONG : IMarketCommon.PoolType.SHORT;
    mint(marketIndex, poolType, pool, amount);
  }

  function redeem(
    uint32 marketIndex,
    IMarketCommon.PoolType poolType,
    uint256 pool,
    uint112 amount
  ) internal {
    require(address(marketFactory) != address(0), "MarketFactory was not setup correctly");
    if (isLoggingOn) {
      console2.log("*********");
      console2.log("Random : REDEEM", Strings.toString(uint256(poolType)));
      console2.log("amount", amount);
      console2.log("market index", marketIndex);
      console2.log("pool index", pool);
      console2.log("*********");
    }

    updateSystemStateSingleMarket(marketIndex);

    IMarket market = marketFactory.market(marketIndex);

    if (poolType == IMarketCommon.PoolType.LONG) {
      market.redeemLong(pool, amount);
    } else if (poolType == IMarketCommon.PoolType.FLOAT) {
      market.redeemFloatPool(amount);
    } else {
      market.redeemShort(pool, amount);
    }
  }

  function redeem(
    uint32 marketIndex,
    bool isLong,
    uint256 pool,
    uint112 amount
  ) internal {
    IMarketCommon.PoolType poolType = isLong ? IMarketCommon.PoolType.LONG : IMarketCommon.PoolType.SHORT;
    redeem(marketIndex, poolType, pool, amount);
  }

  // TODO: refine and optimize this function!
  function updateSystemBruteForceForTesting(IMarket market) public {
    IMarket.EpochInfo memory epochInfo = market.get_epochInfo();

    IOracleManager oracleManager = IOracleManager(market.get_oracleManager());

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
        console2.log(
          "This should never print, if it prints there might be a bug - take a look!",
          epochInfo.latestExecutedEpochIndex,
          "<",
          _missedEpochOracleRoundIds[epochsToSkip]
        );
      }

      if (_missedEpochOracleRoundIds.length - epochsToSkip > 0) {
        uint80[] memory missedEpochsOracleRoundIds = new uint80[](_missedEpochOracleRoundIds.length - epochsToSkip);
        for (uint256 i = epochsToSkip; i < _missedEpochOracleRoundIds.length; i++) {
          missedEpochsOracleRoundIds[i - epochsToSkip] = _missedEpochOracleRoundIds[i];
          if (isLoggingOn)
            console2.log("missedEpochsOracleRoundIds (index, original index)", i - epochsToSkip, i, uint256(_missedEpochOracleRoundIds[i]));
        }

        market.updateSystemStateUsingValidatedOracleRoundIds(missedEpochsOracleRoundIds);
      }
    } else {
      if (isLoggingOn) console2.log("No missed epochs");
    }
  }

  function updateSystemStateSingleMarket(uint32 marketIndex) public {
    IMarket market = IMarket(registry.separateMarketContracts(marketIndex));
    updateSystemBruteForceForTesting(market);
  }

  function updateSystemStateAllMarkets() public {
    for (uint32 i = 1; i <= registry.latestMarket(); i++) {
      updateSystemStateSingleMarket(i);
    }
  }
}
