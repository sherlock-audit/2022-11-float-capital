/* // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../keepers/KeeperArctic.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../testing/FloatContractsCoordinator.s.sol";

contract MyScript is FloatContractsCoordinator {
  function run() external {
    setupContractCoordinator();
    keeper = KeeperArctic(getKeeperAddress());

    vm.startBroadcast();

    KeeperArctic keeperImplementation = new KeeperArctic();

    if (keeper.hasRole(keeper.UPGRADER_ROLE(), msg.sender)) {
      keeper.upgradeTo(address(keeperImplementation));
    } else {
      keeper = KeeperArctic(
        address(
          new ERC1967Proxy(
            address(keeperImplementation),
            abi.encodeCall(KeeperArctic(keeperImplementation).initialize, (msg.sender, address(keeper.registry())))
          )
        )
      );
    }

    // address registryAddress = 0xACB2fD8a3c96bEd287d39eaFb1d6C2d75AE8E467;
    // if (address(keeper.registry()) != registryAddress) {
    //   keeper.setRegistry(registryAddress);
    // } else {
    //   console2.log("long short set correctly");
    // }

    vm.stopBroadcast();
  }
}
 */
