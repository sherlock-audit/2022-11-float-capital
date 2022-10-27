// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ERC20Mock is ERC20PresetMinterPauserUpgradeable {
  constructor(string memory name, string memory symbol) {
    initialize(name, symbol);
  }

  event TransferCalled(address sender, address recipient, uint256 amount);

  bool shouldMockTransfer = false;

  function setShouldMockTransfer(bool _value) public {
    shouldMockTransfer = _value;
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    emit TransferCalled(_msgSender(), recipient, amount);
    if (shouldMockTransfer) {
      return true;
    } else {
      return super.transfer(recipient, amount);
    }
  }
}

contract ERC20MockWithPublicMint is ERC20Mock {
  constructor(string memory name, string memory symbol) ERC20Mock(name, symbol) {}

  // Minting is public for easy testing on the mock.
  function mint(uint256 amount) public {
    super._mint(msg.sender, amount);
  }

  // Minting is public for easy testing on the mock.
  function mintFor(uint256 amount, address user) public {
    super._mint(user, amount);
  }
}

// NOTE: this is the only contract that DOESN'T use `AccessControlledAndUpgradeable` since it clashes with the Enumerable access control contract inside ERC20PresetMinterPauserUpgradeable.
contract PaymentTokenTestnet is ERC20PresetMinterPauserUpgradeable, UUPSUpgradeable {
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

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
  function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

  function initializeWithAdmin(
    address admin,
    string memory name,
    string memory symbol
  ) public initializer {
    __ERC20PresetMinterPauser_init(name, symbol);
    __AccessControl_init();
    __UUPSUpgradeable_init();
    _AccessControlledAndUpgradeable_init_unchained(admin);
  }

  function initialize(string memory name, string memory symbol) public override initializer {
    __ERC20PresetMinterPauser_init(name, symbol);
    __AccessControl_init();
    __UUPSUpgradeable_init();
    _AccessControlledAndUpgradeable_init_unchained(msg.sender);
  }

  // Minting is public for easy testing on the mock.
  function mint(uint256 amount) public {
    require(amount <= 10000e18, "Amount too high");
    super._mint(msg.sender, amount);
  }

  // Minting is public for easy testing on the mock.
  function mintFor(uint256 amount, address user) external {
    require(amount <= 10000e18, "Amount too high");
    super._mint(user, amount);
  }
}
