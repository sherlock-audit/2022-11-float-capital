// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "./GEMS.sol";

import "../../testing/FloatTest.t.sol";

contract GemsTest is FloatTest {
  function testGemsGrantsRoleToRegistry() public view {
    require(gems.hasRole(gems.DEFAULT_ADMIN_ROLE(), address(registry)), "Registry should have GEM role");
    require(gems.hasRole(gems.GEM_ROLE(), address(registry)), "Registry should have GEM role");
  }
}
