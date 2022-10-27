// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PoolTokenProxy is ERC1967Proxy {
  // from Initializeable
  uint256[1] private __gap1;

  // from AccessControlUpgradeable
  uint256[50] private __gap2;

  // from ContextUpgradeable
  uint256[50] private __gap3;

  // from ERC165Upgradeable
  uint256[50] private __gap4;

  // from ERC1967UpgradeUpgradeable
  uint256[50] private __gap5;

  // from UUPSUpgradeable
  uint256[50] private __gap6;

  // from ERC20Upgradeable
  mapping(address => uint256) public rawBalances;

  mapping(address => mapping(address => uint256)) private _allowances;

  uint256 public totalSupply;

  constructor(address _logic, bytes memory _data) payable ERC1967Proxy(_logic, _data) {}
}
