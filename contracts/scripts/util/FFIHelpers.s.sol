// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Vm.sol";

library FFIHelpers {
  function setNextTimestampAnvil(Vm vm, uint32 timestamp) public {
    // example call:
    // $ cast rpc --rpc-url 'http://localhost:8545' evm_setNextBlockTimestamp '2000002342'
    string[] memory inputs = new string[](6);
    inputs[0] = "cast";
    inputs[1] = "rpc";
    inputs[2] = "--rpc-url";
    inputs[3] = "http://localhost:8545";
    inputs[4] = "evm_setNextBlockTimestamp";
    inputs[5] = vm.toString(timestamp);

    vm.ffi(inputs);
  }

  function executeCmdString(Vm vm, string memory cmd) external {
    string[] memory input = new string[](1);
    input[0] = cmd;

    vm.ffi(input);
  }
}
