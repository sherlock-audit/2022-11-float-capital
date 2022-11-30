// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import "../PoolToken/PoolToken.sol";
import "../PoolToken/PoolTokenProxy.sol";

import "../registry/template/Registry.sol";
import "../interfaces/IMarket.sol";
import "../market/template/inconsequentialViewFunctions/MarketWithAdditionalViewFunctions.sol";
import "../market/template/inconsequentialViewFunctions/MarketWithAdditionalViewFunctions.sol";

import "../oracles/OracleManager.sol";
import "../YieldManagers/MarketLiquidityManagerSimple.sol";

import "../testing/generated/MarketTieredLeverageMockable.t.sol";
import "../testing/MarketTieredLeverageInternalStateSetters.sol";

import "../interfaces/chainlink/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MarketFactory is Test {
  Registry immutable registry;

  enum MarketContractType {
    MarketTieredLeverage,
    MarketTieredLeverageInternalStateSetters,
    MarketMockable
  }

  mapping(uint32 => MarketContractType) internal _marketTypes;

  uint32 numMarkets;

  constructor(Registry _registry) {
    registry = _registry;
  }

  function deployPoolToken(
    address _marketAddress,
    IMarketCommon.PoolType _poolType,
    uint8 _poolTier
  ) public returns (IPoolToken) {
    address implementation = address(new PoolToken(_marketAddress, _poolType, _poolTier));

    return
      IPoolToken(
        address(
          new PoolTokenProxy(
            implementation,
            "" // Empty since we initialise the contract at a later stage in the initializer function for MarketTieredLeverageInternalStateSetters
          )
        )
      );
  }

  // define these here to take pressure off the stack
  MarketLiquidityManagerSimple internal currentYieldManager;
  address internal oracleManagerAddress;
  IMarket internal _market;
  uint256 internal totalLiquidityRequired;

  struct PoolLeverage {
    uint96 leverage;
    IMarketCommon.PoolType poolType;
    uint8 poolTier;
  }

  function getTokenNameSuffix(IMarketCommon.PoolType poolType) internal pure returns (string memory) {
    return poolType == IMarketCommon.PoolType.LONG ? "Long" : (poolType == IMarketCommon.PoolType.SHORT ? "Short" : "Float");
  }

  function getTokenSymbolSuffix(IMarketCommon.PoolType poolType) internal pure returns (string memory) {
    return poolType == IMarketCommon.PoolType.LONG ? "l" : (poolType == IMarketCommon.PoolType.SHORT ? "s" : "f");
  }

  // TODO create version that takes oracle address as param
  function deployMarket(
    uint256 initialLiquidityToSeedEachPool,
    PoolLeverage[] memory poolLeverages,
    uint256 fixedEpochLength,
    uint256 minimumExecutionWaitingTime,
    address chainlinkOracleAddress,
    IERC20 _paymentToken,
    MarketContractType marketTypeToDeploy,
    string memory name,
    string memory symbol
  ) internal returns (uint32 marketIndex) {
    marketIndex = ++numMarkets;
    if (marketTypeToDeploy == MarketContractType.MarketTieredLeverage) {
      MarketExtended _marketExtended = new MarketExtended(address(_paymentToken), registry);
      address marketImplementation = address(new Market(_marketExtended, address(_paymentToken), registry));
      _market = IMarket(address(new ERC1967Proxy(marketImplementation, "")));
    } else if (marketTypeToDeploy == MarketContractType.MarketTieredLeverageInternalStateSetters) {
      address marketImplementation = address(
        new MarketTieredLeverageInternalStateSetters(new MarketExtended(address(_paymentToken), registry), address(_paymentToken), registry)
      );
      _market = IMarket(address(MarketTieredLeverageInternalStateSetters(address(new ERC1967Proxy(marketImplementation, "")))));
    } else if (marketTypeToDeploy == MarketContractType.MarketMockable) {
      address marketImplementation = address(
        new MarketTieredLeverageMockable(new MarketExtended(address(_paymentToken), registry), address(_paymentToken), registry)
      );
      _market = IMarket(address(MarketTieredLeverageMockable(address(new ERC1967Proxy(marketImplementation, "")))));
    } else {
      revert("Unhandeled market deployment type");
    }

    console2.log("deploy - A");
    _marketTypes[marketIndex] = marketTypeToDeploy;

    console2.log("deploy - B");
    currentYieldManager = MarketLiquidityManagerSimple(
      address(
        new ERC1967Proxy(
          address(new MarketLiquidityManagerSimple(address(_market), address(_paymentToken))),
          abi.encodeWithSignature("initialize(address)", address(msg.sender))
        )
      )
    );
    console2.log("deploy - C");
    {
      OracleManager newOracleManager = new OracleManager(chainlinkOracleAddress, fixedEpochLength, minimumExecutionWaitingTime);
      oracleManagerAddress = address(newOracleManager);
    }
    console2.log("deploy - D");

    IMarketExtended.SinglePoolInitInfo[] memory initPools = new IMarketExtended.SinglePoolInitInfo[](poolLeverages.length);

    totalLiquidityRequired = 0;

    for (uint256 i = 0; i < poolLeverages.length; i++) {
      //address poolTokenAddress = address(deployPoolToken(address(_market)));
      initPools[i] = IMarketExtendedCore.SinglePoolInitInfo(
        string.concat(Strings.toString(poolLeverages[i].leverage / 1e18), "x ", name, getTokenNameSuffix(poolLeverages[i].poolType)),
        string.concat(Strings.toString(poolLeverages[i].leverage / 1e18), "x", symbol, getTokenSymbolSuffix(poolLeverages[i].poolType)),
        poolLeverages[i].poolType,
        poolLeverages[i].poolTier,
        address(deployPoolToken(address(_market), poolLeverages[i].poolType, poolLeverages[i].poolTier)),
        poolLeverages[i].leverage
      );
      totalLiquidityRequired += initialLiquidityToSeedEachPool;
    }

    _paymentToken.approve(address(_market), totalLiquidityRequired);

    registry.registerPoolMarketContract(
      name,
      symbol,
      IMarketTieredLeverage(address(_market)),
      initialLiquidityToSeedEachPool,
      oracleManagerAddress,
      address(currentYieldManager),
      initPools
    );
  }

  function deployMarketWithBroadcast(
    address deployer,
    uint256 initialPoolLiquidity,
    PoolLeverage[] memory poolLeverages,
    uint256 fixedEpochLength,
    uint256 minimumExecutionWaitingTime,
    address chainlinkOracleAddress,
    IERC20 _paymentToken,
    MarketContractType marketTypeToDeploy,
    string memory name,
    string memory symbol,
    Vm vm
  ) public returns (uint32 marketIndex) {
    vm.startBroadcast(deployer);

    console2.log("deploy - before 1");
    marketIndex = deployMarket(
      initialPoolLiquidity,
      poolLeverages,
      fixedEpochLength,
      minimumExecutionWaitingTime,
      chainlinkOracleAddress,
      _paymentToken,
      marketTypeToDeploy,
      name,
      symbol
    );
    vm.stopBroadcast();
  }

  function deployMarketWithPrank(
    address deployer,
    uint256 initialPoolLiquidity,
    PoolLeverage[] memory poolLeverages,
    uint256 fixedEpochLength,
    uint256 minimumExecutionWaitingTime,
    address chainlinkOracleAddress,
    IERC20 _paymentToken,
    MarketContractType marketTypeToDeploy
  ) public returns (uint32 marketIndex) {
    vm.startPrank(deployer);
    marketIndex = deployMarket(
      initialPoolLiquidity,
      poolLeverages,
      fixedEpochLength,
      minimumExecutionWaitingTime,
      chainlinkOracleAddress,
      _paymentToken,
      marketTypeToDeploy,
      "Magic Internet Asset",
      "PoolToken"
    );
    vm.stopPrank();
  }

  function setFundingRate(
    address admin,
    uint32 marketIndex,
    uint128 newFundingRate
  ) public {
    vm.startPrank(admin);
    IMarketExtendedCore.FundingRateUpdate memory a = IMarketExtendedCore.FundingRateUpdate(0, newFundingRate, 0, 1e18);
    marketExtended(marketIndex).changeMarketFundingRateMultiplier(a);
    vm.stopPrank();
  }

  // ================================================================
  // Getters

  function marketAddress(uint32 marketIndex) public view returns (address) {
    return registry.separateMarketContracts(marketIndex);
  }

  function marketExtended(uint32 marketIndex) public view returns (IMarketExtended) {
    return IMarketExtended(registry.separateMarketContracts(marketIndex));
  }

  function marketInternalStateSetters(uint32 marketIndex) public view returns (MarketTieredLeverageInternalStateSetters) {
    if (_marketTypes[marketIndex] != MarketContractType.MarketTieredLeverageInternalStateSetters) {
      revert("Cannot cast down to MarketTieredLeverageInternalStateSetters");
    }
    return MarketTieredLeverageInternalStateSetters(registry.separateMarketContracts(marketIndex));
  }

  function market(uint32 marketIndex) public view returns (IMarket) {
    return IMarket(registry.separateMarketContracts(marketIndex));
  }

  function oracleManager(uint32 marketIndex) public view returns (OracleManager) {
    return OracleManager(address(IMarketTieredLeverage(registry.separateMarketContracts(marketIndex)).get_oracleManager()));
  }

  function chainlinkOracle(uint32 marketIndex) public view returns (AggregatorV3Interface) {
    return oracleManager(marketIndex).chainlinkOracle();
  }

  function paymentToken(uint32 marketIndex) public view returns (IERC20) {
    return IERC20(IMarketTieredLeverage(registry.separateMarketContracts(marketIndex)).get_paymentToken());
  }

  function liquidityManager(uint32 marketIndex) public view returns (MarketLiquidityManagerSimple) {
    return MarketLiquidityManagerSimple(IMarketTieredLeverage(registry.separateMarketContracts(marketIndex)).get_liquidityManager());
  }
}
