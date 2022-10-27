// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "ds-test/test.sol";

import "../../keepers/KeeperArctic.sol";
import "../../registry/template/Registry.sol";
import "../../oracles/OracleManager.sol";

/// @dev this script is to update the oracles for a market.
contract MyScript is Script, DSTest {
  KeeperArctic keeper;
  Registry registry = Registry(0xfb98538a6B20D71928818bD0a665EC4f82114361);

  uint256 constant defaultEpochLength = 4200;
  uint256 constant defaultMEWT = 10;
  address constant linkOracleMumbaiAddress = 0x12162c3E810393dEC01362aBf156D7ecf6159528;
  address constant ethOracleMumbaiAddress = 0x0715A7794a1dc8e42615F059dD6e406A6594651A;

  function run() external {
    vm.startBroadcast();

    _upgradeOracleManager(1);
    _upgradeOracleManager(2);

    vm.stopBroadcast();
  }

  function _upgradeOracleManager(uint32 marketIndex) internal {
    address oracleMumbaiAddress;

    if (marketIndex == 1) {
      oracleMumbaiAddress = ethOracleMumbaiAddress;
    } else {
      oracleMumbaiAddress = linkOracleMumbaiAddress;
    }

    OracleManager oracleManagerFixedEpoch = new OracleManager(oracleMumbaiAddress, defaultEpochLength, defaultMEWT);

    IMarket market = IMarket(registry.separateMarketContracts(marketIndex));

    market.updateMarketOracle(IMarketExtendedCore.OracleUpdate({prevOracle: market.get_oracleManager(), newOracle: oracleManagerFixedEpoch}));

    require(IMarketTieredLeverage(address(market)).get_oracleManager() == oracleManagerFixedEpoch);
  }
}
