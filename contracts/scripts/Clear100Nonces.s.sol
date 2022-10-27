// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract MyScript is Script {
  function run() public {
    vm.startBroadcast();

    for (uint256 i; i < 100; i++) {
      (bool result, ) = payable(msg.sender).call{value: 0}("");

      console.log(i + 1, "transaction", result);
    }

    vm.stopBroadcast();
  }
}
