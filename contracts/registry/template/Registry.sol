// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../../abstract/AccessControlledAndUpgradeable.sol";
import "../../interfaces/IRegistry.sol";
import "../../interfaces/IGEMS.sol";
import "../../interfaces/IMarket.sol";
import "../../interfaces/IMarketExtended.sol";

/**
 **** visit https://float.capital *****
 */

/// @title Core logic of Float Protocal markets
/// @author float.capital
/// @notice visit https://float.capital for more info
/// @dev All functions in this file are currently `virtual`. This is NOT to encourage inheritance.
/// It is merely for convenince when unit testing.
/// @custom:auditors This contract balances long and short sides.
contract Registry is IRegistry, AccessControlledAndUpgradeable {
  /*╔═════════════════════════════╗
    ║          VARIABLES          ║
    ╚═════════════════════════════╝*/

  /* ══════ Global state ══════ */
  uint32 public override latestMarket;

  address public gems;

  uint256[45] private __globalStateGap;

  /* ══════ Market specific ══════ */
  mapping(uint32 => bool) public marketExists;

  struct PoolTokenPriceInPaymentToken {
    // this has a maximum size of `2^128=3.4028237e+38` units of payment token which is amply sufficient for our markets
    uint128 price_long;
    uint128 price_short;
  }
  mapping(uint32 => mapping(uint256 => PoolTokenPriceInPaymentToken)) public poolToken_priceSnapshot;

  /* ══════ User specific ══════ */
  mapping(uint32 => mapping(address => uint256)) public userNextPrice_currentUpdateIndex;

  mapping(uint32 => mapping(bool => mapping(address => uint256))) public userNextPrice_paymentToken_depositAmount;
  mapping(uint32 => mapping(bool => mapping(address => uint256))) public userNextPrice_poolToken_redeemAmount;
  mapping(uint32 => mapping(bool => mapping(address => uint256))) public userNextPrice_poolToken_toShiftAwayFrom_marketSide;

  mapping(uint32 => address) public separateMarketContracts;

  /*╔═════════════════════════════╗
    ║          MODIFIERS          ║
    ╚═════════════════════════════╝*/

  modifier adminOnly() {
    _checkRole(ADMIN_ROLE, msg.sender);
    _;
  }

  /*╔═════════════════════════════╗
    ║       CONTRACT SET-UP       ║
    ╚═════════════════════════════╝*/

  /// @notice Initializes the contract.
  /// @dev Calls OpenZeppelin's initializer modifier.
  /// @param _admin Address of the admin role.
  /// @param _gems Address of the gems contract.
  function initialize(address _admin, address _gems) external virtual initializer {
    require(_admin != address(0) && _gems != address(0));
    // The below function ensures that this contract can't be re-initialized!
    _AccessControlledAndUpgradeable_init(_admin);
    gems = _gems;
    IGEMS(gems).initialize();

    emit RegistryArctic(_admin);
  }

  /*╔════════════════════════════╗
    ║     MARKET REGISTRATION    ║
    ╚════════════════════════════╝*/

  function registerPoolMarketContract(
    string memory name,
    string memory symbol,
    IMarketTieredLeverage marketContract,
    uint256 initialLiquidityToSeedEachPool,
    address oracleManager,
    address liquidityManager,
    IMarketExtended.SinglePoolInitInfo[] memory launchPools
  ) external adminOnly {
    uint32 marketIndex = ++latestMarket;

    emit SeparateMarketCreated(name, symbol, address(marketContract), marketIndex);
    require(
      IMarketExtended(address(marketContract)).initializePools(
        IMarketExtendedCore.InitializePoolsParams(
          launchPools,
          initialLiquidityToSeedEachPool,
          msg.sender,
          marketIndex,
          oracleManager,
          liquidityManager
        )
      ),
      "registering pool market failed"
    );
    separateMarketContracts[marketIndex] = address(marketContract);
    marketExists[marketIndex] = true;

    AccessControlledAndUpgradeable(gems).grantRole(IGEMS(gems).GEM_ROLE(), address(marketContract));
  }
}
