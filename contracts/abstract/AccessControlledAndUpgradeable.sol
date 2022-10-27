// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IAccessControlledAndUpgradeable.sol";

/**
   Merger various OpenZeppelin contracts to make 1 abstract contract that can be
   implemented easily by any Float contract. Also sets up some standard roles
   common to many of the Float contracts.
*/
abstract contract AccessControlledAndUpgradeable is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IAccessControlledAndUpgradeable {
  /// @notice Role for the single entity that is allowed to upgrade the contract.
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  /// @notice Role for the single entity that has admin control over the contract.
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  /// @notice Initializes the contract when called by parent initializers.
  /// @param initialAdmin The initial admin who will hold all roles.
  function _AccessControlledAndUpgradeable_init(address initialAdmin) internal onlyInitializing {
    __AccessControl_init();
    __UUPSUpgradeable_init();
    _AccessControlledAndUpgradeable_init_unchained(initialAdmin);
  }

  /// @notice Initializes the contract for contracts that already call both __AccessControl_init
  ///         and _UUPSUpgradeable_init when initializing.
  /// @param initialAdmin The initial admin who will hold all roles.
  function _AccessControlledAndUpgradeable_init_unchained(address initialAdmin) internal {
    require(initialAdmin != address(0));
    _setupRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    _setupRole(ADMIN_ROLE, initialAdmin);
    _setupRole(UPGRADER_ROLE, initialAdmin);
  }

  /// @notice Authorizes an upgrade to a new address.
  /// @dev Can only be called by addresses wih UPGRADER_ROLE
  /// @param newImplementation The address that is going to be allowed to perform the upgrade
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}

/**
   Extension of the above contract but with a modifier.
 */
contract AccessControlledAndUpgradeableModifiers is AccessControlledAndUpgradeable {
  modifier adminOnly() virtual {
    _checkRole(ADMIN_ROLE, msg.sender);
    _;
  }
}
