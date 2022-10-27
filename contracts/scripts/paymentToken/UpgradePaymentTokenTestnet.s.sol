// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "ds-test/test.sol";

import "../../keepers/KeeperArctic.sol";
import "../../oracles/OracleManager.sol";
import "../../YieldManagers/MarketLiquidityManagerSimple.sol";
import "../../mocks/ERC20Mock.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyScript is Script, DSTest {
  KeeperArctic keeper;

  address constant oldPaymentTokenTestnet = 0xF5F52D5D4c2E0a2Fbb7D9c3530899C1830D398d5;

  function run() external {
    vm.startBroadcast();

    _upgradePaymentTokenTestnet(oldPaymentTokenTestnet);

    vm.stopBroadcast();
  }

  function _upgradePaymentTokenTestnet(address _oldPaymentTokenTestnet) internal {
    PaymentTokenTestnet paymentToken = PaymentTokenTestnet(_oldPaymentTokenTestnet);

    address newPaymentTokenImplementation = address(new PaymentTokenTestnet());

    paymentToken.upgradeTo(newPaymentTokenImplementation);
  }
}
