// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import "../../abstract/AccessControlledAndUpgradeable.sol";

library UpgradeTools {
  /// @dev if you can upgrade the contract and re-upgrade it back to the original implementation
  function checkUpgradesAreWorking(
    address contractToTestUpgradeOf,
    address newImplementation,
    Vm vm
  ) internal {
    bytes32 _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address originalImplementationImplementation = address(uint160(uint256(vm.load(contractToTestUpgradeOf, _IMPLEMENTATION_SLOT))));
    // NOTE: if this line fails it is possible that the upgradeTesterImplementation function isn't defined/initialized yet.
    AccessControlledAndUpgradeable(contractToTestUpgradeOf).upgradeTo(newImplementation);

    AccessControlledAndUpgradeable(contractToTestUpgradeOf).upgradeTo(originalImplementationImplementation);
  }

  function checkUpgradesAreWorkingWithUpgrader(
    address contractToTestUpgradeOf,
    address newImplementation,
    Vm vm,
    address upgrader
  ) internal {
    vm.stopPrank();
    vm.startPrank(upgrader);
    checkUpgradesAreWorking(contractToTestUpgradeOf, newImplementation, vm);
    vm.stopPrank();
  }
}
