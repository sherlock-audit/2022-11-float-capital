// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

interface IGEMS {
  function initialize() external;

  function gm(address) external;

  function GEM_ROLE() external returns (bytes32);

  function balanceOf(address) external returns (uint256);
}
