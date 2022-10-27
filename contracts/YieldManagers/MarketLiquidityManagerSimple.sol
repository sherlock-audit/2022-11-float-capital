// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../interfaces/ILiquidityManager.sol";

/**
@title MarketLiquidityManagerSimple
 */
contract MarketLiquidityManagerSimple is ILiquidityManager, AccessControlledAndUpgradeable {
  using SafeERC20 for IERC20;

  /*╔═════════════════════════════╗
    ║          VARIABLES          ║
    ╚═════════════════════════════╝*/

  /// @notice address of market contract
  address public immutable market;

  /// @notice The payment token the liquidity manager supports
  /// @dev DAI token most likely
  IERC20 public immutable paymentToken;

  uint256[45] private __variableGap;

  /*╔═════════════════════════════╗
    ║          MODIFIERS          ║
    ╚═════════════════════════════╝*/

  /// @dev only allow market contract to execute modified functions
  modifier marketOnly() {
    require(msg.sender == market, "Not Market");
    _;
  }

  /*╔═════════════════════════════╗
    ║       CONTRACT SET-UP       ║
    ╚═════════════════════════════╝*/

  constructor(address _market, address _paymentToken) initializer {
    require(_market != address(0) && _paymentToken != address(0));
    market = _market;
    paymentToken = IERC20(_paymentToken);
  }

  function initialize(address admin) external initializer {
    require(admin != address(0));
    _AccessControlledAndUpgradeable_init(admin);
  }

  /*╔════════════════════════╗
    ║     IMPLEMENTATION     ║
    ╚════════════════════════╝*/

  /// @notice Allows the market pay out a user
  /// @param user User to recieve the payout
  /// @param amount Amount of payment token to pay to user
  function transferPaymentTokensToUser(address user, uint256 amount) external marketOnly {
    paymentToken.safeTransfer(user, amount);
  }
}
