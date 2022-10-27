/* // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "ds-test/test.sol";

import "../../keepers/KeeperArctic.sol";
import "../../components/gamificationFun/GEMS.sol";
import "../../registry/template/Registry.sol";
import "../../PoolToken/PoolToken.sol";
import "../../oracles/OracleManager.sol";
import "../../YieldManagers/MarketLiquidityManagerSimple.sol";
import "../../interfaces/IMarket.sol";
import "../../testing/FloatContractsCoordinator.s.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyScript is FloatContractsCoordinator {
  function run() external {
    setupContractCoordinator();
    keeper = KeeperArctic(getKeeperAddress());
    registry = Registry(address(keeper.registry()));

    vm.startBroadcast();

    _upgradeMarket(1);
    _upgradeMarket(2);

    vm.stopBroadcast();
  }

  function _upgradeMarket(uint32 marketIndex) internal {
    Market market = Market(registry.separateMarketContracts(marketIndex));
    address paymentToken = market.get_paymentToken();

    address marketImplementation = address(new Market(new MarketExtended(address(paymentToken), registry), address(paymentToken), registry));
    market.upgradeTo(marketImplementation);
  }
}
 */
